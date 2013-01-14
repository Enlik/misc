#!/usr/bin/env perl
use warnings;
use strict;
use 5.010;

# prints size taken by each package and category, in order
# also prints something like this for each present category:
#  136371.3	x11-libs            (packages: 84, average 1623.47 kB)

# pipe here equo query installed -v
# equo must be run with English locale, for example you can use:
# LANG=en_US.UTF-8 equo query installed -v | ./entropy-by-size.pl

# made by Enlik

# NOTE: it needs fixing with new equo versions

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

# this sub is based on comp_size from querypkg
sub size_kB {
	my ($a, $pkg) = @_;

	my $a_num = 0;
	my $a_rest = "";

	if($a =~ /^([\d.]+)(.*)/) {
		$a_num = $1;
		$a_rest = $2;
	}
	else {
		die "bad size for $pkg: $a\n"
	}

	given($a_rest) {
		when ("kB") { }
		when ("MB") { $a_num *= 1024 }
		when ("GB") { $a_num *= 1048576 } # what?
		die "bad size suffix for $pkg: $a_rest (size = $a)\n"
	}
	return $a_num;
}

my %sizes;
my %sizes_by_categ;
my %packages_by_categ;
my $pkg;
my $category;
while (my $line = <STDIN>) {
	if ($line =~ /@@ Package: ([^ ]+)/) {
		$pkg = $1;
		if ($pkg =~ m!^([^/]+)/[^/]+$!) {
			$category = $1;
		}
		else {
			chomp $line;
			die qq(Can't match category. Bad file name? pkg = "$pkg", ),
				qq(line = "$line");
		}
	}
	elsif ($line =~ /^\>\> +Size: +(.*)/) {
		unless ($pkg) {
			chomp $line;
			die qq(found "Size:" ($1) without package ),
				qq(name prior to it! (line = "$line")\n);
		}
		$sizes{$pkg} = { orig => $1, kB => size_kB($1) };
		$sizes_by_categ{$category} += size_kB($1);
		$packages_by_categ{$category}++;
		#say $1, " ", size_kB($1, $pkg);
		undef $pkg; # to catch errors in input
	}
}

for my $pkg (sort { $sizes{$a}->{kB} <=> $sizes{$b}->{kB} } keys %sizes) {
	say $sizes{$pkg}->{orig}, "\t", $pkg;
}

say "\nsizes by category (kB)\n";
for my $category (sort { $sizes_by_categ{$a} <=> $sizes_by_categ{$b} }
		keys %sizes_by_categ) {
	printf "%9.1f\t%-20s", $sizes_by_categ{$category}, $category;
	printf "(packages: %s, average %.2f kB)\n",
		$packages_by_categ{$category},
		$sizes_by_categ{$category} / $packages_by_categ{$category};
}
