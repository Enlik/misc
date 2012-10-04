#!/usr/bin/env perl

use warnings;
use strict;
use 5.010;

# by Enlik
# It is provided "as is" without express or implied warranty.

# Help is on the bottom if you're looking for it!
# quick introduction: ./overlays-diff.pl --ign9 /usr/portage /home/overlay

my %pkg_versions1=();
my %pkg_versions2=();

my $ign_live;
my $read_file_mode;
my $group_results;

# returns 0, 1 or -1
sub vercomp_bit {
	my ($v1, $v2) = @_; # for example "4", "p4"
	# first arg must be defined, second may be empty
	# (because it's made like this: blah(@longer_arr, @shorter_arr) in vercomp)

	$v2 //= "";

	# compare bits on the same position like bla-0-$v1 and bla-0-$v2 (or _)
	my %prio = (
		alpha => -4, # pkg-0_alpha1
		beta => -3,  # pkg-0_beta1
		pre => -2,   # pkg-0_pre1
		rc => -1,    # pkg-0_rc1
		EMPTY => 0,  # pkg-0
		r => 1,      # pkg-0-r1 // special
		p => 2,      # pkg-0_p1
		DEFAULT => 3 # pkg-0.123 (because 0.123 > 0_p1)
	);
	my ($v1_prio, $v2_prio);
	my ($v1_verbit, $v2_verbit);

	my ($v, $v_prio, $v_verbit);
	# Y U NO SUB? :)
	for (1..2) {
		if ($_ == 1) {
			$v = \$v1;
			$v_prio = \$v1_prio;
			$v_verbit = \$v1_verbit;
		}
		else {
			$v = \$v2;
			$v_prio = \$v2_prio;
			$v_verbit = \$v2_verbit;
		}

		given ($$v) {
			when (/^$/) {
				$$v_prio = $prio{EMPTY};
				$$v_verbit = 0;
			}
			when (/^\d+$/) {
				$$v_prio = $prio{DEFAULT};
				$$v_verbit = $$v;
			}
			# a letter can only be after last digit, we skip the check
			when (/^(\d+)([a-z])$/) {
				my $num = $1;
				my $letter = $2;
				$$v_prio = $prio{DEFAULT};
				$$v_verbit = $num . '.' . ord($letter);
			}
			when (/^r(\d+)$/) {
				$$v_prio = $prio{r};
				$$v_verbit = $1;
			}
			when (/^p(\d*)$/) {
				$$v_prio = $prio{p};
				$$v_verbit = $1 || 0;
			}
			when (/^rc(\d*)$/) {
				$$v_prio = $prio{rc};
				$$v_verbit = $1 || 0;
			}
			when (/^pre(\d*)$/) {
				$$v_prio = $prio{pre};
				$$v_verbit = $1 || 0;
			}
			when (/^alpha(\d*)$/) {
				$$v_prio = $prio{alpha};
				$$v_verbit = $1 || 0;
			}
			when (/^beta(\d*)$/) {
				$$v_prio = $prio{beta};
				$$v_verbit = $1 || 0;
			}
			default {
				die "versioning error: /$v1/$v2/";
			}
		}
	}

	# say "1: $v1_prio → $v1_verbit → $v1";
	# say "2: $v2_prio → $v2_verbit → $v2";
	if ($v1_prio != $v2_prio) {
		return $v1_prio <=> $v2_prio;
	}
	else {
		if ($v1_verbit !~ /^[.\d]+$/ or $v2_verbit !~ /^[.\d]+$/) {
			die "argh: [$v1_verbit], [$v2_verbit]"
		}
		return $v1_verbit <=> $v2_verbit;
	}
}

sub vercomp {
	my ($v1, $v2) = @_;
	die "args!" unless @_ == 2;
	die "arg 1 undef!" unless defined $v1;
	die "arg 2 undef!" unless defined $v2;
	my @bits1 = split /[-._]/,$v1;
	my @bits2 = split /[-._]/,$v2;

	my $res;

	my $mult_res;
	my ($ref_a, $ref_b);
	if (@bits1 >= @bits2) {
		$mult_res = 1;
		$ref_a = \@bits1;
		$ref_b = \@bits2;
	}
	else {
		$mult_res = -1;
		$ref_a = \@bits2;
		$ref_b = \@bits1;
	}

	# start with the longer one
	for (my $i = 0; $i < (@$ref_a); $i++) {
		my $cmp;
		eval {
			$cmp = vercomp_bit ($ref_a->[$i], $ref_b->[$i]);
		};
		if ($@) {
			die "error at: $ref_a->[$i], $ref_b->[$i]: original error: $@";
		}
		if ($cmp != 0) {
			$res = $cmp;
			last;
		}
	}

	$res = 0 unless defined $res; # equal
	return $res * $mult_res;
}

sub _dbg_vercomp_bit ($$) {
	my ($b1, $b2) = @_;
	my $pre = "123_";
	# sexi
	say $pre,
		$b1,
		sub {
			my $r = vercomp_bit($b1, $b2);
			$r == 0 and return ' = ';
			$r == -1 and return ' < ';
			return ' > ';
		}->(),
		$pre,
		$b2;
}

if(0) {
# this covers most cases; "a-" is only to make it understand easier
my @versions = qw(a-0_pre a-1_pre1 a-1_pre2 a-2 a-2.1 a-2.1a a-2.1b_pre1
	a-2.2 a-2.3_alpha1 a-2.3_alpha2 a-2.3_alpha2_p3 a-2.3_beta1 a-2.3_rc1
	a-2.3 a-2.3-r1 a-2.3_p123 a-2.3_p123-r1);
$_ = substr $_, 2 for @versions;

for (my $i=0; $i<@versions; $i++) {
	for (my $j=0; $j<@versions; $j++) {
		my $cmp = vercomp ($versions[$i], $versions[$j]);
		my $cmp_ok = $i <=> $j;
		if ($cmp != $cmp_ok) {
			# > is 1; < is -1; = is 0
			say STDERR
				"$versions[$i], $versions[$j]:\n   expected $cmp_ok, got: $cmp";
		}
	}
}
say "That's all!";
exit 0;
}

sub process_line {
	my $line = shift; # /usr/local/portage/bla-fuj/meh/meh-3.ebuild
	my $pkgs = shift;
	my $two_sets = shift;
	my ($category, $name, $version, $package);
	if (
		$line =~ m/
		([\da-z-]+) # category
		\/ # a slash
		([^\/]+) # part of a path (no slash): name
		\/ # a slash
		\2 # name again
		- # a hyphen
		(\d.*) # version
		\.ebuild$
		/x
	) {
		$category = $1;
		$name = $2;
		$version = $3;
		$package = $category . '/' . $name;

		if ($pkgs->{$package}) {
			# don't override with live ebuild (fixme: even if 9999999 vs. 9999)
			if ($ign_live && $version =~ /^9999+$/) {
				# skip
			}
			# override live ebuild unconditionally
			elsif($ign_live && $pkgs->{$package} =~ /^9999+$/) {
				if (!$two_sets) {
					printf("[overriding live]%32s %15s %15s\n",
						$package, $version, $pkgs->{$package});
				}
				$pkgs->{$package} = $version;
			}
			# if they're not live ebuilds or $ign_live = false, do fair comparison
			else {
				my $cmp = vercomp ($version, $pkgs->{$package});
				if ($cmp > 0) {
					if (!$two_sets) {
						printf("[is greater]%36s %15s %15s\n",
							$package, $version, $pkgs->{$package});
					}
					$pkgs->{$package} = $version;
				}
			}
		}
		else {
			$pkgs->{$package} = $version;
		}
	}
	else {
		die qq{parse error: $line\n} unless $line eq '/usr/portage/skel.ebuild';
		#~ die qq{kupa: $_, package=@{[$package//"(null)"]}, },
			#~ qq{name=@{[$name//"(null)"]}, },
			#~ qq{version=@{[$version//"(null)"]} },
			#~ qq{set at @{[-$err_line]}\n}
	}
}

sub process_directory {
	my ($dir, $pkgs, $two_sets) = @_;
	die unless @_ == 3 and ref $pkgs eq 'HASH';

	unless (-d $dir) {
		die "Error: `$dir' doesn't exist or is not a directory.\n";
	}

	my $iter = File::Next::files( {
			error_handler => sub { say STDERR "error: " . shift(); },
			follow_symlinks => 1,
			# follow symbolic link if it doesn't point to a directory
			# note: File::Next::files() skips broken symbolic links too
			descend_filter => sub { !( -l $_ && -d $_ ) },
			file_filter => sub { /\.ebuild$/ }
		},
		$dir
	);
	while ( defined ( my $file = $iter->() ) ) {
		process_line ($file, $pkgs, $two_sets);
	}
}

#########################################

if ('--help' ~~ @ARGV or '-h' ~~ @ARGV) {
	exec ("perldoc", $0)
		or die "You can open $0 and look at help on the bottom\n";
}

$read_file_mode = ('--list' ~~ @ARGV);
$ign_live       = ('--ign9' ~~ @ARGV);
$group_results  = ('--group' ~~ @ARGV);
@ARGV = grep { not $_ ~~ ["--list", "--ign9", "--group"] } @ARGV;

if (@ARGV > 2) {
	die "Wrong number of arguments! Should be 0 (stdin, one set), 1 (one set) ",
		"or 2 (two sets). Kurczątko.\n";
}

# assume --list if data is read from standard input
$read_file_mode = 1 if @ARGV == 0;

my $two_sets = @ARGV == 2;

if ($read_file_mode) {
	# read from files
	my $file_num = 1;

	for my $filename (@ARGV) {
		die "Too many files?!" if $file_num > 2; # shouldn't happen

		my $pkgs = $file_num == 1 ? \%pkg_versions1 : \%pkg_versions2;
		my $fh;
		unless (open $fh, "<", $filename) {
			say STDERR "Cannot open $filename: $!";
			exit 1
		}
		say "*** reading $filename ***";
		while (<$fh>) {
			chomp;
			process_line ($_, $pkgs, $two_sets);
		}
		$file_num++;
	}
}
else {
	# process directories
	eval {
		require File::Next;
	};
	if ($@) {
		die "$@\nRequired module File::Next is not found.\n",
			"Use --list or (if you're on Gentoo) install dev-perl/File-Next.\n";
	}

	my ($dir1, $dir2) = @ARGV; # dir2 can be undef

	unless (-d $dir1) {
		die "Error: `$dir1' doesn't exist or is not a directory.\n";
	}

	say "*** directory $dir1 ***";
	process_directory ($dir1, \%pkg_versions1, $two_sets);
	if ($two_sets) {
		say "*** directory $dir2 ***";
		process_directory ($dir2, \%pkg_versions2, $two_sets);
	}
}

if (!$two_sets){
	for my $e (sort keys %pkg_versions1) {
		printf("%50s %s\n", $e, $pkg_versions1{$e});
	}
}
else {
	my @results_all=(); # array of: [ {'=' | '<' | '>'}, atom, ver1, ver2 ]
	my @results_equal = ();
	my @results_greater = ();
	my @results_less = ();
	my $cmp;
	my $tmp;
	for my $e (sort keys %pkg_versions2) {
		if (exists $pkg_versions1{$e}) {
			my $array;
			$cmp = vercomp ($pkg_versions1{$e}, $pkg_versions2{$e});
			given ($cmp) {
				when (0) {
					$tmp = '=';
					$array = \@results_equal;
				}
				when (1) {
					$tmp = '>';
					$array = \@results_greater;
				}
				when (-1) {
					$tmp = '<';
					$array = \@results_less;
				}
				die;
			}
			$array = \@results_all unless $group_results;
			push @{ $array },
				[ $tmp, $e, $pkg_versions1{$e}, $pkg_versions2{$e} ];
		}
	}

	my $pnt = sub {
		for my $res (@_) {
			say "$res->[0] $res->[1]: $res->[2] [$res->[3]]"
		}
	};

	if ($group_results) {
		$pnt->( @results_greater );
		$pnt->( @results_less );
		$pnt->( @results_equal );
	}
	else {
		$pnt->( @results_all );
	}
}

=head1 SYNOPSIS

	overlays-diff.pl [--ign9] [--group] DIRECTORY [DIRECTORY]
	overlays-diff.pl [--ign9] [--group] --list LIST [LIST]
	overlays-diff.pl --help
	overlays-diff.pl -h

=head1 DESCRIPTION

This mega bla w00t script can be used to print differences between versions
of packages in two Gentoo overlays.

Differences are shown when you provide two DIRECTORIES or two LIST files.
If you provide only one (or none and pipe data to program instead), a list
of packages with their newest version available is printed (sometimes with
debugging-like output, which you can ignore).

Note that only data contained in ebuild name is used. The files are not
sourced nor parsed, what implies that slots and masks aren't supported.

=head2 Supported input.

LIST file and data received on standard input are expected to contain data
like find output from the example below.

These lines are valid:

 /usr/local/portage/dev-util/geany/geany-1.22.ebuild
 dev-util/geany/geany-1.22.ebuild

and this one is not.

 dev-util/geany-1.22

=head1 OPTIONS

=over 4

=item B<--ign9>

Ignore live ebuilds (9999...) unless there's a only live ebuild for a package.
Note: with this option versions like 9999 and 9999999 are treated as equal.

=item B<--list>

Read a file with list instead of traversing a directory. If this option is used,
all arguments must be files. See "EXAMPLES" below.

=item B<--group>

Group display results. Only takes effect when when two DIRECTORIES or two LISTS
are provided. With this option, packages that are newer in the first overlay
than the second one are printed first; then those that are older, and then
those that are equal.

=item B<-h>, B<--help>

Guess what!

=back

=head1 EXAMPLES

=head2 Compare versions.

=over 4

=item Without B<--list>.

 overlays-diff.pl /usr/portage /home/overlay

=item With B<--list>.

 find /usr/portage/ -name \*.ebuild > /tmp/1
 find /home/overlay -name \*.ebuild > /tmp/2
 overlays-diff.pl --list /tmp/1 /tmp/2

=back

=head2 Print newest versions.

Three examples follow.

 overlays-diff.pl /home/overlay
 overlays-diff.pl --list /tmp/list
 find /home/overlay -name \*.ebuild | overlays-diff.pl

=head1 CONTACT

See L<https://github.com/Enlik/misc/>.

=head1 COPYRIGHT

It is provided "as is" without express or implied warranty.

=cut
