package Fortran::Namelist::Editor::Span;
use strict;
use warnings;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self  = {};
	bless($self,$class);
	return($self->init(@_));
}
sub init {
	my ($self,$namelist,$o_b,$o_e) = @_;
	$self->{_namelist} = $namelist;
	if (defined $namelist) {
		$self->{_o} = $namelist->_new_GOT_entry($o_b,$o_e);
	}
	return($self);
}
sub set {
	my ($self,$val) = @_;
	my $delta = $self->{_namelist}->set_data(@{$self->{_o}},$val);
	$self->{_o}->[1] = $self->{_o}->[0]+$delta if (($delta > 0) and ($self->{_o}->[0] == $self->{_o}->[1]));
	return(1);
}
sub get {
	my $self=shift;
	return(scalar($self->{_namelist}->get_data(@{$self->{_o}})));
}
sub insert {
	my ($class,$namelist,$offset,$separator,@value)=@_;
	my $delta=$namelist->set_data($offset,$offset,$separator);
	my $self=$class->new($namelist,$offset+$delta,$offset+$delta);
	$self->set(@value);
	return($self);
}
sub delete {
	my ($self)=@_;
	$self->{_namelist}->set_data(@{$self->{_o}},'');
	return(1);
}
sub DESTROY {
	my $self = shift;
	$self->{_namelist}->_remove_GOT_entry($self->{_o}) if (defined $self->{_namelist});
}
sub length {
	my ($self)=@_;
	return(0) unless (defined $self->{_o}->[0] and defined $self->{_o}->[1]);
	return($self->{_o}->[1]-$self->{_o}->[0]);
}
sub dump {
	my $self=shift;
	my $dd=Data::Dumper->new([ $self ]);
	$dd->Sortkeys(sub { my $ref=shift; return([ sort grep { $_ ne '_namelist' } keys %{$ref} ]) });
	$dd->Indent(1);
	my $dump = $dd->Dump();
	$dump =~ s/=>(\s+)([^'\n,]+)/=>$1'$2'/g;
	return($dump);
}

package Fortran::Namelist::Editor::ContainerSpan;
use strict;
use warnings;
@Fortran::Namelist::Editor::ContainerSpan::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$namelist,$o_b,$o_e) = @_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	@{$self->{_get_ignore_patterns}} = (
		qr/^_o$/,
		qr/^_namelist$/,
		qr/^_get_ignore_patterns$/,
		qr/^_get_reroot$/,
	);
	return($self);
}
sub get {
	my $self=shift;
	my $root=$self;
	$root=$self->{$self->{_get_reroot}} if ($self->{_get_reroot});
	my %h;
	foreach my $key (keys %{$root}) {
		next if (grep { $key =~ $_ } @{$self->{_get_ignore_patterns}});     # skip offset fields
		my $val;
		eval { $val = $root->{$key}->get }; # try to use childs get method
		$h{$key}=$val if (defined $val);
	}
	return(\%h);
}
package Fortran::Namelist::Editor::Token;
use strict;
use warnings;
@Fortran::Namelist::Editor::Token::ISA=qw{Fortran::Namelist::Editor::Span};
sub get {
	my $self=shift;
	my $data=lc($self->SUPER::get());
	$data =~ s/^\s+//;
	return($data);
}
sub set_padded {
	my ($self,$data) = @_;
	my $l_data=length($data);
	my $l_old =$self->length;
	if ($l_old > $l_data) {
		$data = ' ' x ($l_old-$l_data) . $data;
	}
	return($self->SUPER::set($data));
}


package Fortran::Namelist::Editor::CaseSensitiveToken;
use strict;
use warnings;
@Fortran::Namelist::Editor::CaseSensitiveToken::ISA=qw{Fortran::Namelist::Editor::Span};
sub get {
	my $self=shift;
	my $data=$self->SUPER::get();
	$data =~ s/^\s+//;
	return($data);
}
sub set_padded {
	my ($self,$data) = @_;
	my $l_data=length($data);
	my $l_old =$self->length;
	if ($l_old > $l_data) {
		$data = ' ' x ($l_old-$l_data) . $data;
	}
	return($self->SUPER::set($data));
}

package Fortran::Namelist::Editor::Comment;
use strict;
use warnings;
@Fortran::Namelist::Editor::Comment::ISA=qw{Fortran::Namelist::Editor::Span};
1;
