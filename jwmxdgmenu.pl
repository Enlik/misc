#!/usr/bin/perl

use warnings;
use strict;

# jwmxdgmenu.pl
# Copyright (c) 2010-2012 Enlik
# distributed under terms of MIT License


# made on my early days with Perl :-)


# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ----

my @bins;
my @path = split(/:/, $ENV{PATH});
# What apps?
my @desktopfilepath = ("/usr/share/applications", "$ENV{HOME}/.local/share/applications");
# What groups? (Translation, icon.)
my @directoryfilepath = ("/usr/share/desktop-directories", "$ENV{HOME}/.local/share/desktop-directories");
	 
my %dfile; # .desktop file
my %dirfile; # .directory file
my @catorderpref = qw(Favourites Graphics Network Office Utility Audio AudioVideo Development Education Game Settings System);
my $locale = "pl";

sub str_in_table { # grep continues even if one found...
	my ($el, $t) = @_; # ...and here, by reference is faster.
	for (@$t) {
		return 1 if ($_ eq $el);
	}
	return 0;
}

sub populate_bins {
	EXT_LOOP: for my $i (0..$#path) {
		for (0..$i-1) {
			next EXT_LOOP if($path[$i] eq $path[$_]);
		}
		# print $path[$i];
		if(opendir(DIR, $path[$i])) {
			if (my @files = readdir(DIR)) {
				# no, we don't want full path
				#for (@files) {
				#	$_ = "$path[$i]/$_";
				#}
				@bins = (@bins, @files);
		# also . and .. goes there, and dirs, and non-executables, and dups, but it does not hurt
			}
			closedir(DIR);
		}
	}
}

sub parse_df {
	my $file = shift;
	if (open(DFILE, "<", $file)) {
		#print STDERR "OPEN [$file]\n";
		my %spec;
		my @cats;
		my $execW; # the first word of Exec field (second CAN be %F for example)
		my $prgname;
		my $icon;
		
		while(my $line = <DFILE>) {
			if ($line =~ / *([^=]+)=(.*)/) {
				$spec{$1}=$2;
			}
		}
		# print "[$spec{Exec}]";
		return unless exists $spec{Exec};
		return unless exists $spec{Categories};
		return if(exists $spec{NoDisplay} && $spec{NoDisplay} eq "true");
		
		$prgname = $spec{Name};
		$prgname = $spec{"Name[$locale]"} if(exists $spec{"Name[$locale]"});
		$icon = $spec{Icon} if(exists $spec{Icon});
		
		$execW = (split /\s+/, $spec{Exec})[0];
		# Check if file exists in PATH or its own location.
		my $ok;
		if (substr ($execW,0,1) ne "/") { # relative path
			#if (grep {$_ eq $execW} @bins) {
			if (str_in_table $execW, \@bins) {
				$ok=1;
			}
			else {
				$ok=0;
			}
		}
		elsif(-f $execW) { # absolute path
			$ok=1;
		}
		else {
			$ok=0;
		}
				
		if ( $ok ) {
			my $fileW = (split /\//,$file)[-1];
			@cats = split ";", $spec{Categories};
			$dfile{$fileW}{Categories}=[ @cats ];
			$dfile{$fileW}{Exec}=$spec{Exec};
			$dfile{$fileW}{Name}=$prgname;
			$dfile{$fileW}{Icon}=$icon;
		}
		else {
			print STDERR "[INFO] n/a file: $execW (referenced as: $spec{Exec} in $file)\n";
		}
		close(DFILE);
	}
	else {
		print STDERR "[ERROR] opening $file\n";
	}
}

sub parse_dirf {
	my $file = shift;
	if (open(DFILE, "<", $file)) {
		#print STDERR "OPEN [$file]\n";
		my $name;
		my $name_lang;
		my $icon;
		my %spec;
		
		while(my $line = <DFILE>) {
			if ($line =~ / *([^=]+)=(.*)/) {
				$spec{$1}=$2;
			}
		}
		# print "[$spec{Exec}]";
		return unless exists $spec{Name};
		return unless exists $spec{Type};
		return unless($spec{Type} eq "Directory");
		
		$name = $spec{Name};
		$name_lang = $spec{"Name[$locale]"} if(exists $spec{"Name[$locale]"});
		$icon = $spec{Icon} if(exists $spec{Icon});
		
		$dirfile{$name}{Name}=$name_lang || $name;
		$dirfile{$name}{Icon}=$icon;
		close(DFILE);
	}
	else {
		print STDERR "[ERROR] opening $file\n";
	}
}

sub search_directoryfile {
	my $path = shift;
	search_file($path, ".directory", '.+\.directory$', \&parse_dirf);
}

sub search_desktopfile {
	my $path = shift;
	search_file($path, ".desktop", '.+\.desktop$', \&parse_df);
}

sub search_file {
	die ("wrong number or args")
		unless (@_ == 4);
	my ($path, $message, $filename_r, $parse_cb) = @_;
	my $file;
	my @dirs;
	unshift @dirs, $path;
	
	while(@dirs) {
		$path = shift @dirs;
		print STDERR "[DIR] looking for $message files in $path\n";
		if(opendir(DIR, $path)) {
			if(my @files = readdir(DIR)) {
				closedir(DIR); # close before calling search_df again
				for my $file_no_path (@files) {
					$file = $path."/".$file_no_path;
	
					if(-d $file && ! ($file_no_path eq ".") && ! ($file_no_path eq "..") ) {
						push @dirs, $file
					}
					elsif ((-f $file or -l $file) and $file =~ /$filename_r/) {
						$parse_cb->($file);
					}
					else {
						# print $file,"!!!\n";
					}
				}
			}
			else {
				print STDERR "Cannot list contents of directory $path.\n";
			}
		}
		else {
			print STDERR "Cannot open this directory.\n";
		}
	}
}

sub gen_JWM_menu {
	# <Menu icon="folder.png" label="Applications">
	# <Program icon="audacious.png" label="Audacious">audacious</Program>
	my %menus;

	for my $key (keys %dfile) {
		# print "$key -> $dfile{$key}{Exec}\n";
		my @labels = @{$dfile{$key}{Categories}};
		my $category="";
		# Look for best category (@catorderpref).
		for my $cat (@catorderpref) {
			if (grep {$_ eq $cat} @labels) {
				$category = $cat;
				last;
			}
		}
		#print $menulabel;
		$category = "Other" if $category eq "";
		
		my $exec = $dfile{$key}{Exec};
		$exec = $1 if ($exec =~ /(.+) %[a-zA-Z]$/); # rem trailing crap like %U
		my $exec_word = (split /\s+/, $exec)[0];
		$exec_word = (split /\//,$exec_word)[-1];
		my $prgname = $dfile{$key}{Name};
		$prgname = $exec_word if $prgname eq "";
		my $icon = $dfile{$key}{Icon};
		my $cat_icon = $dirfile{$category}{Icon};
		if($icon) {
			$icon = $icon . ".png" unless ($icon =~ /\.(png|xpm|jpg|svg)$/)
		}
		if($cat_icon) {
			$cat_icon = $cat_icon . ".png" unless ($cat_icon =~ /\.(png|xpm|jpg|svg)$/)
		}
		# Category name can be referenced by .desktop file, but not
		# be in any .directory file. (Can be in something.menu, but it's not supported.)
		my $category_lang = $dirfile{$category}{Name} || $category;
		
		#print STDERR "[ $category | $dirfile{$category} | $dirfile{$category}{Name}; ]\n";
		push @{$menus{$category_lang}{apps}}, [ $icon, "$prgname [$exec_word]", $exec ];
		$menus{$category_lang}{Icon} = $cat_icon;
	}
	
	print qq(<JWM>\n);
	for my $menulabel (sort keys %menus) {
		if(my $icon = $menus{$menulabel}{Icon}) {
			print qq(\t<Menu icon="$icon" label="$menulabel">\n);
		}
		else {
			print qq(\t<Menu label="$menulabel">\n);
		}
		for my $el (sort {lc($a->[1]) cmp lc($b->[1])} @{$menus{$menulabel}{apps}}) {
			if($el->[0]) {
				print qq(\t\t<Program icon="$el->[0]" label="$el->[1]">$el->[2]</Program>\n);
			}
			else {
				print qq(\t\t<Program label="$el->[1]">$el->[2]</Program>\n);
			}
		}
		print qq(\t</Menu>\n);
	}
	print qq(</JWM>\n);
}

populate_bins;
search_desktopfile $_ for (@desktopfilepath);
search_directoryfile $_ for (@directoryfilepath);

gen_JWM_menu
$|++;
print STDERR "\nDon't forget to <Include>your generated menu</Include>.\n";
print STDERR "Specify <IconPath>...</IconPath> in your .jwmrc if you want icons.\n";
print STDERR "jwm -p can be use useful to check for errors\n";

#use Benchmark;
#my $test = {
#	t1 => sub { str_in_table "visudo", \@bins },
#	t2 => sub { grep {$_ eq "visudo"} @bins }
#};

#timethese 7500, $test;

