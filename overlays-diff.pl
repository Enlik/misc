#!/usr/bin/env perl

use warnings;
use strict;
use 5.010;

# by Enlik
# It is provided "as is" without express or implied warranty.

# purpose and usage - comment at the bottom

my %pkg_versions1=();
my %pkg_versions2=();

my $ign_live = exists $ENV{IGN9};

# returns 0, 1 or -1
sub vercomp_bit {
	my ($v1, $v2) = @_; # for example "4", "_p4"
	# first arg must be defined, second may be empty
	# (because it's made like this: blah(@longer_arr, @shorter_arr) below)

	return 1 unless defined $v2;

	# compare bits on the same position like bla-0-$v1 and bla-0-$v2 (or _)
	my %prio = (
		alpha => -4, # pkg-0_alpha1
		beta => -3,  # pkg-0_beta1
		pre => -2,   # pkg-0_pre1
		rc => -1,    # pkg-0_rc1
		# DEFAULT => 0,# pkg-0.123
		r => 1,      # pkg-0-r1 // special
		p => 2,      # pkg-0_p1
		DEFAULT => 3 # pkg-0.123
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

# needs more test
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

#my @bits = qw(12 2 2b 2c 1d r1 pre4 alpha3 alpha4);
#for (1..20) {
	#$ign_live = 0;
	#my $r;
	#$r = rand (scalar @bits);
	#my $b1 = $bits[$r];
	#$r = rand (scalar @bits);
	#my $b2 = $bits[$r];
	#_dbg_vercomp_bit $b1, $b2;
#}
#exit 0;

if (@ARGV != 0 and @ARGV != 2) {
	die "argsów winno zero tudzież dwa być\n"
}

my $two_sets = @ARGV == 0 ? 0 : 1;
my $fileno = 0;
my $file = "";
my $pkgs = \%pkg_versions1; # well it could be made differently, but it's quite okay
# note: setting $pkgs = 0 or anything like this is an ultimate protection against
# unwanted autovivification!
while(<>) {
	if ($two_sets && not $ARGV eq $file) {
		$fileno++;
		say "*** file $fileno: $ARGV ***";
		$file = $ARGV;
		if ($fileno == 1) {
			$pkgs = \%pkg_versions1;
		} else {
			$pkgs = \%pkg_versions2;
		}
	}
	# /usr/local/portage/bla-fuj/meh/meh-3.ebuild
	my ($category, $name, $version, $package);
	chomp;
	if (
		m/
		([\da-z-]+) # category
		\/ # a slash
		([^\/]+) # part of a path (no slash): name
		\/ # a slash
		\2 # name again
		-
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
						printf("[is greater]%37s %15s %15s\t[%s]\n",
							$package, $version, $pkgs->{$package}, $cmp);
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
		die qq{parse error: $_\n} unless $_ eq '/usr/portage/skel.ebuild';
		#~ die qq{kupa: $_, package=@{[$package//"(null)"]}, },
			#~ qq{name=@{[$name//"(null)"]}, },
			#~ qq{version=@{[$version//"(null)"]} },
			#~ qq{set at @{[-$err_line]}\n}
	}
}

# print greatest versions
if (!$two_sets){
	for my $e (sort keys %pkg_versions1) {
		printf("%50s %s\n", $e, $pkg_versions1{$e});
	}
}
# or do something useful - for what this script has been/is being made:
# print if $ARGV[0] has newer version than $ARGV[1] (usually to compare
# an overlay with Portage), wee

# example usage:
# find /usr/local/portage/ -name \*.ebuild > /tmp/1
# find overlay -name \*.ebuild > /tmp/2
# perl <this-script>.pl /tmp/1 /tmp/2

# set IGN9=1 env. variable to ignore live ebuilds (9999…) unless there's live
# ebuild only (note: versions like 9999 and 999999 are not compared if IGN9 set)
else {
	my $cmp;
	my $tmp;
	for my $e (sort keys %pkg_versions2) {
		if (exists $pkg_versions1{$e}) {
			$cmp = vercomp ($pkg_versions1{$e}, $pkg_versions2{$e});
			given ($cmp) {
				when (0) {
					$tmp = '=';
				}
				when (1) {
					$tmp = '>';
				}
				when (-1) {
					$tmp = '<';
				}
				die;
			}
			say "$tmp $e: $pkg_versions1{$e} [$pkg_versions2{$e}]"
		}
	}
}
