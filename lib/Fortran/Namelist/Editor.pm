package Fortran::Namelist::Editor;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Scalar::Util qw(reftype blessed);
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Group;
@Fortran::Namelist::Editor::ISA=qw{Fortran::Namelist::Editor::ContainerSpan};

sub init {
	my $self=shift;
	my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'HASH'));
	my $data=$opts{data};
	if (defined $opts{filename} and (! defined $data)) {
		# slurp in file
		if (open(my $fh,$opts{filename})) {
			local $/=undef;
			$data=<$fh>;
		} else {
			carp "Error opening file '$opts{filename}'";
			return(undef);
		}
	}
	$data='' unless (defined $data);
	$self->SUPER::init(undef,0,length($data));
	$self->{_get_reroot} = 'groups';

	$self->{filename}    = $opts{filename};
	$self->{data}        = $data;

	# internal data structures
	$self->{_groups}     = [];
	$self->{groups}      = {};
	$self->{indent}      = '';

	if ($self->{data}) {
		$self->{data_cs}=$self->find_comments_and_strings();
		$self->find_groups();
		$self->find_indent();
	}
	return($self);
}
sub get_data {
	my ($self,$o_b,$o_e)=@_;
	confess "o_b is undefined" unless (defined $o_b);
	confess "o_e is undefined" unless (defined $o_e);
	return(undef) if ($o_e > $self->{o_e});
	return(undef) if ($o_b > $self->{o_e});
	my $length = $o_e-$o_b;
	return(substr($self->{data},$o_b,$length),
		substr($self->{data_cs},$o_b,$length)) if (wantarray);
	return(substr($self->{data},$o_b,$length));
}
sub set_data {
	my ($self,$o_b,$o_e,$value,$value_cs)=@_;
	confess "o_b is undefined" unless (defined $o_b);
	confess "o_e is undefined" unless (defined $o_e);
	return(undef) if ($o_e > $self->{o_e});
	return(undef) if ($o_b > $self->{o_e});
	my $length    = $o_e-$o_b;
	my $newlength = length($value);
	my $delta     = $newlength-$length;
	$value_cs     = $value unless (defined $value_cs);
	substr($self->{data},$o_b,$length)    = $value;
	substr($self->{data_cs},$o_b,$length) = $value_cs;
	return([0,0,$self->{_adjust_id}]) if ($delta == 0);
	my $adj=$self->_adjust_offsets([$o_b,$delta]);
	$self->{o_e}+=$delta if ($o_b == $self->{o_e});
	return($adj);
}
sub insert_new_line_before {
	my ($self,$offset,$indent) = @_;
	$indent = $self->{indent} unless (defined $indent);
	my $to_insert="\n$indent";
	$offset=$self->refine_offset_back($offset,qr{(\n[^\n]*)/});
	my $adjust_opt=$self->set_data($offset,$offset,$to_insert);
	$offset=$adjust_opt->[0]+$adjust_opt->[1];
	return($offset,$adjust_opt) if (wantarray);
	return($offset);
}
sub insert_new_line_after {
	my ($self,$offset,$indent) = @_;
	$indent = $self->{indent} unless (defined $indent);
	my $to_insert="\n$indent";
	$offset=$self->refine_offset_forward($offset,qr{([^\n]+)}s);
	my $adjust_opt=$self->set_data($offset,$offset,$to_insert);
	$offset=$adjust_opt->[0]+$adjust_opt->[1];
	return($offset,$adjust_opt) if (wantarray);
	return($offset);
}
sub find_comments_and_strings {
	my $self = shift;
	my (@strings,@comments);
	# working copy
	my $d = $self->get_data($self->{o_b},$self->{o_e});
	# find all fortran !-style comments and quoted strings
	while ($d =~ m{
			                   ## f90 comments start with !, end with EOL
			(![^\n]*)\n        ## put into group1
		|                      ## OR ! which are part of quoted strings
			(                  ##group2
				'(?:''|[^'])*' ## single quoted strings, '' is an escaped '
			|
				"(?:""|[^"])*" ## double quoted strings, "" is an escaped "
			)                  ##group2-end
		}xsg) {
		if (defined $2) {
			my %string=(
				o_b => $-[2],
				o_e => $+[2],
			);
			push @strings,\%string;
		} else {
			my %comment=(
				o_b => $-[1],
				o_e => $+[1],
			);
			push @comments,\%comment;
		}
	}
	# replace comments by same-length sequence of space
	foreach my $c (@comments) {
		my $len=$c->{o_e}-$c->{o_b};
		substr($d,$c->{o_b},$len) = ' ' x $len;
	}
	# replace strings by same-length sequence of underscores
	foreach my $s (@strings) {
		my $len=$s->{o_e}-$s->{o_b};
		substr($d,$s->{o_b},$len) = '_' x $len;
	}
	return($d);
}

sub find_groups {
	my $self=shift;
	my (undef,$data_cs) = $self->get_data($self->{o_b},$self->{o_e});
	while ($data_cs =~ m{(?:^|\n)[ \t]*(&\S+)[^/]*/}gs) {
		push @{$self->{_groups}},
			Fortran::Namelist::Editor::Group->new($self,$-[1],$+[0],$-[1],$+[1]);
	}
	foreach my $g (@{$self->{_groups}}) {
		my $name=$g->{name}->get;
		confess "group '$name' exists more than once" if (exists $self->{groups}->{$name});
		$self->{groups}->{$name}=$g;
	}
	return(1);
}

sub find_indent {
	my $self=shift;
	my %indent;
	foreach my $g (@{$self->{_groups}}) {
		$g->indent_histogram(\%indent);
	}
	if (%indent) {
		my @indentations=keys %indent;
		my @votes=values %indent;
		my @idx=sort { $votes[$b] <=> $votes[$a] } 0 .. $#votes;
		$self->{indent}=$indentations[$idx[0]];
	}
}

sub get {
	my ($self,$group,@options)=@_;
	return($self->SUPER::get) unless (defined $group);
	return(undef) unless (exists $self->{groups}->{$group});
	return($self->{groups}->{$group}->get(@options));
}

sub save {
	my ($self,$filename)=@_;
	my $fh;
	confess "cannot open file '$filename' for writing" unless (open($fh,'>',$filename));
	print $fh $self->{data};
	close($fh);
}

sub refine_offset_back {
	my ($self,$position,$re) = @_;
	pos($self->{data_cs}) = $position;
	if ($self->{data_cs} =~ /$re\G/g) {
		return($-[1]);
	}
	return($position);
}

sub refine_offset_forward {
	my ($self,$position,$re) = @_;
	pos($self->{data_cs}) = $position;
	if ($self->{data_cs} =~ /\G$re/g) {
		return($+[1]);
	}
	return($position);
}

sub add_group {
	my ($self,$group_name,$after,@options)=@_;
	return(2) if (exists $self->{groups}->{$group_name});
	my $after_index = $#{$self->{_groups}};
	if (defined $after) {
		if ($after =~ /^\d+$/) {
			$after_index=$after if ($after < $after_index);
		} elsif (exists $self->{groups}->{$after}) {
			$after_index = grep { $self->{_groups}->[$_]->{name}->get eq $after } 0 .. $#{$self->{_groups}};
			$after_index--;
		}
	}
	my $offset_b    = $self->{_groups}->[$after_index]->{o_e};
	$offset_b = $self->insert_new_line_after($offset_b,'');
	my $group = Fortran::Namelist::Editor::Group->insert($self,$offset_b,'',$group_name,@options);
	splice(@{$self->{_groups}},$after_index+1,0,$group);
	$self->{groups}->{$group_name}=$group;
}

sub _remove_group {
	my ($self,$group_name)=@_;
	return(2) unless (exists $self->{groups}->{$group_name});
	my $group_ref = $self->{groups}->{$group_name};
	@{$self->{_groups}} = grep { $_ != $group_ref } @{$self->{_groups}};
	delete($self->{groups}->{$group_name});
	$self->set_data($group_ref->{o_b},$group_ref->{o_e},'');
}

sub set {
	my ($self,$group,@setting)=@_;
	unless (exists $self->{groups}->{$group}) {
		$self->add_group($group);
	}
	return($self->{groups}->{$group}->set(@setting));
}

sub delete {
	my ($self,$group,@setting)=@_;
	my $is_empty = 0;
	my $adjust_id;
	if (exists $self->{groups}->{$group}) {
		if ($#setting >=0) {
			($is_empty,$adjust_id) = $self->{groups}->{$group}->delete(@setting);
		} else {
			$adjust_id = $self->_remove_group($group);
		}
	}
	$is_empty = 1 if ($#{$self->{_groups}} < 0);
	return($is_empty,$adjust_id) if (wantarray);
	return($is_empty);
}

sub dump_hash {
	my $self=shift;
	my $h = $self->get();
	my $dd=Data::Dumper->new([ $h ]);
	$dd->Sortkeys(sub { my $ref=shift; return([ sort keys %{$ref} ]) });
	$dd->Indent(1);
	return($dd->Dump());
}
1;
