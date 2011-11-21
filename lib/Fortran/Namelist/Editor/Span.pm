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
	my ($self,$val) = @_;
	my ($adjust_opt) = $self->{_namelist}->set_data($self->{o_b},$self->{o_e},$val);
	my $delta = $adjust_opt->[1];
	$self->_adjust_offsets($adjust_opt);
	$self->{o_e} = $self->{o_b}+$delta if (($delta > 0) and ($self->{o_b} == $self->{o_e}));
	return($adjust_opt);
}
sub _get_raw {
	my ($self) = @_;
	return($self->{_namelist}->get_data($self->{o_b},$self->{o_e}));
}
sub get {
	my $self=shift;
	return($self->_get_raw(@_));
}
sub insert {
	my ($class,$namelist,$offset,$separator,@value)=@_;
	my $adj1=$namelist->set_data($offset,$offset,$separator);
	my $self=$class->new($namelist,$offset+$adj1->[1],$offset+$adj1->[1]);
	my $adj2=$self->set(@value);
	$adj2->[1]+=$adj1->[1];
	return($self,$adj2) if (wantarray);
	return($self);
}
sub delete {
	my ($self)=@_;
	my $adj=$self->{_namelist}->set_data($self->{o_b},$self->{o_e},'');
	return(1,$adj) if (wantarray);
	return(1);
}
sub _adjust_offsets {
	my ($self,$adjust_opt) = @_;
	return(undef) unless ($adjust_opt);
	my ($start,$delta,$adjust_id) = @{$adjust_opt};
	if (! defined $adjust_id) {
		$global_adjust_id++ if ($delta!=0);
		$adjust_opt->[2] = $adjust_id = $global_adjust_id;
	}
	return(undef) if ($self->{_adjusted} == $adjust_id);
	$self->{_adjusted}=$adjust_id;
	$self->{o_b}+=$delta if ((defined $self->{o_b}) and ($self->{o_b} > $start));
	$self->{o_e}+=$delta if ((defined $self->{o_e}) and ($self->{o_e} > $start));
	return($adjust_opt);
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

# function, not method
sub summarize_adj {
	my @adj;
	foreach my $a (@_) {
		next unless (defined $a);
		next unless ($a->[1] != 0);
		$adj[0] = $a->[0] if ((! defined $adj[0]) or ($adj[0]>$a->[0]));
		$adj[1] = (defined $adj[1] ? $adj[1]+$a->[1] : $a->[1]);
		$adj[2] = $a->[2] if ((! defined $adj[2]) or ($adj[2]<$a->[2]));
	}
	return(\@adj);
}
package Fortran::Namelist::Editor::ContainerSpan;
use strict;
use warnings;
use Scalar::Util qw(blessed);
@Fortran::Namelist::Editor::ContainerSpan::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$namelist,$o_b,$o_e) = @_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	@{$self->{_get_ignore_patterns}} = (
		qr/^o_.*[eb]$/,
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
sub _adjust_offsets {
	my ($self,$adjust_opt) = @_;
	$adjust_opt=$self->SUPER::_adjust_offsets($adjust_opt);
	return(undef) unless (defined $adjust_opt);
	my @stack=values %{$self};
	while ($#stack >= 0) {
		my $elem=pop @stack;
		if (blessed($elem)) {
			$elem->_adjust_offsets($adjust_opt) if ($elem->can('_adjust_offsets'));
		} elsif (ref $elem eq 'ARRAY') {
			push @stack,@{$elem};
		} elsif (ref $elem eq 'HASH') {
			push @stack,values %{$elem};
		}
	}
	return($adjust_opt);
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
