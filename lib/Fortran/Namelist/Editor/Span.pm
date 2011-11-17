package Fortran::Namelist::Editor::Span;
use strict;
use warnings;
use Data::Dumper;

our $global_adjust_id = 0;

sub new {
	my $class = shift;
	my $self  = {};
	bless($self,$class);
	return($self->init(@_));
}
sub init {
	my ($self,$namelist,$o_b,$o_e) = @_;
	$self->{_namelist} = $namelist;
	$self->{o_b}       = $o_b;
	$self->{o_e}       = $o_e;
	$self->{_adjusted} = $global_adjust_id;
	return($self);
}
sub is_between {
	my ($self,$o_b,$o_e) = @_;
	return(0) unless (defined $self->{o_e} and defined $self->{o_b});
	return(($self->{o_b}>=$o_b) and ($self->{o_e} <=$o_e));
}
sub set {
	my ($self,@val) = @_;
	my ($delta,$adjust_id) = $self->{_namelist}->set_data($self,undef,@val);
	$self->{o_e}+=$delta if ($delta and ($self->{_adjusted} != $adjust_id));
	return(1);
}
sub _get_raw {
	my ($self) = @_;
	return($self->{_namelist}->get_data($self));
}
sub get {
	my $self=shift;
	return($self->_get_raw(@_));
}
sub insert {
	my ($class,$namelist,$offset,$separator,$value)=@_;
	my $sep_length=length($separator);
	$namelist->set_data($offset,$offset,$separator) if ($sep_length);
	my $self=$class->new($namelist,$offset+$sep_length,$offset+$sep_length);
	$self->set($value);
	return($self);
}
sub delete {
	my ($self)=@_;
	$self->{_namelist}->set_data($self,undef,'');
	return($self);
}
sub _adjust_offsets {
	my ($self,$start,$delta,$adjust_id) = @_;
	if (defined $adjust_id) {
		return(0) if ($self->{_adjusted} == $adjust_id);
	} else {
		$global_adjust_id++;
		$adjust_id=$global_adjust_id;
	}
	$self->{_adjusted}=$adjust_id;
	$self->{o_b}+=$delta if ((defined $self->{o_b}) and ($self->{o_b} >= $start));
	$self->{o_e}+=$delta if ((defined $self->{o_e}) and ($self->{o_e} >= $start));
	return($adjust_id);
}
sub length {
	my ($self)=@_;
	return(0) unless (defined $self->{o_e} and defined $self->{o_b});
	return($self->{o_e}-$self->{o_b});
}
sub dump {
	my $self=shift;
	my $dd=Data::Dumper->new([ $self ]);
	$dd->Sortkeys(sub { my $ref=shift; return([ sort grep { $_ ne '_namelist' } keys %{$ref} ]) });
	return($dd->Dump());
}

package Fortran::Namelist::Editor::ContainerSpan;
use strict;
use warnings;
@Fortran::Namelist::Editor::ContainerSpan::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$namelist,$o_b,$o_e) = @_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	@{$self->{_get_ignore_patterns}} = (
		qr/^o_.*[eb]$/,
		qr/^_namelist$/,
		qr/^_get_ignore_patterns$/,
	);
	return($self);
}
sub get {
	my $self=shift;
	my %h;
	foreach my $key (keys %{$self}) {
		next if (grep { $key =~ $_ } @{$self->{_get_ignore_patterns}});     # skip offset fields
		my $val;
		eval { $val = $self->{$key}->get }; # try to use childs get method
		$h{$key}=$val if (defined $val);
	}
	return(\%h);
}
sub _adjust_offsets {
	my ($self,$start,$delta,$adjust_id) = @_;
	$adjust_id=$self->SUPER::_adjust_offsets($start,$delta,$adjust_id);
	return(0) if ($adjust_id == 0);
	my @stack=values %{$self};
	while ($#stack >= 0) {
		my $elem=pop @stack;
		if (ref $elem eq 'ARRAY') {
			push @stack,@{$elem};
		} else {
			eval { $elem->_adjust_offsets($start,$delta,$adjust_id); }
		}
	}
	return($adjust_id);
}

package Fortran::Namelist::Editor::Token;
use strict;
use warnings;
@Fortran::Namelist::Editor::Token::ISA=qw{Fortran::Namelist::Editor::Span};
sub get {
	my $self=shift;
	return(lc($self->SUPER::get()));
}

package Fortran::Namelist::Editor::CaseSensitiveToken;
use strict;
use warnings;
@Fortran::Namelist::Editor::CaseSensitiveToken::ISA=qw{Fortran::Namelist::Editor::Span};

package Fortran::Namelist::Editor::Comment;
use strict;
use warnings;
@Fortran::Namelist::Editor::Comment::ISA=qw{Fortran::Namelist::Editor::Span};
1;
