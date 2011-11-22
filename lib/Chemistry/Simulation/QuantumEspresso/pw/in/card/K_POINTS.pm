package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS;
use strict;
use warnings;
use Scalar::Util qw{blessed};
use Chemistry::Simulation::QuantumEspresso::pw::in::card;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}     ='K_POINTS' unless (exists $self->{name});
	$self->{units}    = undef     unless (exists $self->{units});
	if ($#args >= 0) {
		return($self->parse(@args));
	}
	return(undef,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	# check for units
	unless (defined $self->{units}) {
		my $title = $lines_cs->[$i];
		while ($title =~ /__+/) {
			substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
		}
		if ($title =~ /^\s*(K_POINTS)(?:\s+\S*(tpiba|automatic|crystal|gamma|tpiba_b|crystal_b)\S*)?/i) {
			my $o_line = $o_lines->[$i];
			$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			if (defined $2) {
				$self->{units}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
			} else {
				substr($lines->[$i],$+[1],0) = ' tpiba';
				substr($lines_cs->[$i],$+[1],0) = ' tpiba';
				foreach (@{$o_lines}) {
					$_+=6 if ($_ > $o_line);
				}
				my $adj;
				($self->{units},$adj)=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','tpiba');
				$self->_adjust_offsets($adj);
			}
		}
		my $units=$self->{units}->get;
		if ($units eq 'gamma') {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma');
		} elsif ($units eq 'automatic') {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic');
		} else {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list');
		}
		warn "blessed: " . blessed($self);
		return($self->parse($lines,$lines_cs,$o_lines,$i));
	}
	return($i,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	return($i+1,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->{nk}=[];
	$self->{sk}=[];
	return($self->SUPER::init($namelist,@args));
}
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	($i,$self)=$self->SUPER::parse($lines,$lines_cs,$o_lines,$i);
	while (1) {
		$i++;
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			@{$self->{nk}}=(
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			);
			@{$self->{sk}}=(
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[5],$o_line+$+[5]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[6],$o_line+$+[6]),
			);
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{nk}} < 2) {
		warn "Card 'K_POINTS' incomplete";
	}
	return($i,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->{nks}=undef;
	$self->{k}  = [];
	return($self->SUPER::init($namelist,@args));
}
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	($i,$self)=$self->SUPER::parse($lines,$lines_cs,$o_lines,$i);
	my $nks;
	while (1) {
		$i++;
		last if ((defined $nks) and ($#{$self->{k}} >= $nks-1));
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] = /^\s*(\S+)\s*$/) {
			$self->{nks}=Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			$nks=$self->{nks}->get;
		}
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			push @{$self->{k}},[
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]),
			];
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ((! defined $nks) or ($#{$self->{k}} < $nks-1)) {
		warn "Card 'K_POINTS' incomplete";
	}
	return($i,$self);
}
1;
