package Chemistry::Simulation::QuantumEspresso;
use strict;
use warnings;
sub qe_constructor {
    # type arg style: scf.pw.OUT
    #                     pw.CHECK
    #                nscf.pw.IN
    my $filetype = shift;
    my $options  = pop;
    my @try_pkgs; # list of packages, more specific first
    if ($options->{package}) {
        @try_pkgs=($options->{package});
    } else {
        my @try_base = reverse split /\./,$filetype;
		while (@try_base) {
			push @try_pkgs,'Chemistry::Simulation::QuantumEspresso::' . join('::',@try_base);
			pop  @try_base;
		}
	}
    # try to find best matching package and package file
	my $package;
	my $package_file;
	foreach (@try_pkgs) {
		my $package_try=$_;
		(my $pkg=$package_try) =~ s/::/\//g;
		$pkg.='.pm';
		my @pkg_dir=grep { -f "$_/$pkg" } @INC;
		if (@pkg_dir) {
			$package=$package_try;
			$package_file=$pkg;
			last;
		}
	}
	unless ($package_file) {
		return(undef, "No matching QuantumEspresso parser found for '$filetype', tried:\n  " . join("\n  ",@try_pkgs));
	}
    my $package_constructor;
    # load package and generate constructor reference
	eval {
		require $package_file;
		import $package;
		# technique for constructor reference from
		# http://stackoverflow.com/questions/4229562/how-to-take-code-reference-to-constructor
		$package_constructor = sub {unshift @_, $package; goto &{$_[0]->can('new')} };
		1;
	} or do {
		return(undef,"Error loading $package:" . $@);
	};
	return($package_constructor);
}
1;
