package Fortran::Namelist::Editor::Span;
use strict;
use warnings;
sub new {
	my $class = shift;
	my $self  = {};
	bless($self,$class);
	return($self->init(@_));
}
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->{container} = $container;
	$self->{o_b}       = $o_b;
	$self->{o_e}       = $o_e;
	$self->{_adjusted} = 0;
	return($self);
}
sub is_between {
	my ($self,$o_b,$o_e) = @_;
	return(($self->{o_b}>=$o_b) and ($self->{o_e} <=$o_e));
}
sub set {
	my ($self,$new_value,$new_value_cs) = @_;
	$new_value_cs = $new_value unless (defined $new_value_cs);
	my $old_length = $self->{o_e}-$self->{o_b};
	my $new_length = length($new_value);
	substr($self->{container}->{data},$self->{o_b},$old_length)    = $new_value;
	substr($self->{container}->{data_cs},$self->{o_b},$old_length) = $new_value_cs;
	$self->{container}->adjust_offsets($self->{o_b},$new_length-$old_length,$self) if ($new_length != $old_length);
	$self->{o_e}+=$new_length-$old_length;
	return(1);
}
sub get {
	my ($self) = @_;
	return(substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b}));
}
sub insert {
	my ($class,$container,$offset,$value,$separator)=@_;
	$separator=' ' unless (defined $separator);
	my $sep_length=length($separator);
	if ($sep_length) {
		substr($container->{data},$offset,0)    = $separator;
		substr($container->{data_cs},$offset,0) = $separator;
		$container->adjust_offsets($offset,$sep_length);
	}
	my $self=$class->new($container,$offset+$sep_length,$offset+$sep_length);
	$self->set($value);
	return($self);
}
sub delete {
	my ($self)=@_;
	substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b}) = '';
	substr($self->{container}->{data_cs},$self->{o_b},$self->{o_e}-$self->{o_b}) = '';
#	$self->{container}->remove_refs_between($self->{o_b},$self->{o_e});
	$self->{container}->adjust_offsets($self->{o_b},$self->{o_b}-$self->{o_e});
	return($self);
}
sub _adjust_offsets {
	my ($self,$start,$delta,$adjust_id) = @_;
	$adjust_id=int(rand(424242424)) unless (defined $adjust_id);
	return(0) if ($self->{_adjusted} == $adjust_id);
	$self->{_adjusted}=$adjust_id;
	$self->{o_b}+=$delta if ($self->{o_b} >= $start);
	$self->{o_e}+=$delta if ($self->{o_e} >= $start);
	return(1);
}

package Fortran::Namelist::Editor::Container;
use strict;
use warnings;
@Fortran::Namelist::Editor::Container::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	@{$self->{_get_ignore_patterns}} = (
		qr/^o_.*[eb]$/,
		qr/^container$/,
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
	return(0) unless ($self->SUPER::_adjust_offsets($start,$delta,$adjust_id));
	$adjust_id = $self->{_adjusted};
	my @stack=values %{$self};
	while ($#stack >= 0) {
		my $elem=pop @stack;
		if (ref $elem eq 'ARRAY') {
			push @stack,@{$elem};
		} else {
			eval { $elem->_adjust_offsets($start,$delta,$adjust_id); }
		}
	}
}

package Fortran::Namelist::Editor::Token;
use strict;
use warnings;
@Fortran::Namelist::Editor::Token::ISA=qw{Fortran::Namelist::Editor::Span};
sub get {
	my $self=shift;
	return(lc(substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b})));
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
