#!/usr/bin/perl
opendir PWD,".";
while (my $dir=readdir PWD) {
	if (-d $dir and -f "$dir/CuO2.scf.out") {
		$dir =~ m#([^/]+)$#;
		$LC  = $1;
		open RES,"$dir/CuO2.scf.out";
		@E = map { my @l=split; $l[4] } grep (/^!/,<RES>);
		print "$LC @E\n";
		close RES;
	}
}
closedir PWD;
