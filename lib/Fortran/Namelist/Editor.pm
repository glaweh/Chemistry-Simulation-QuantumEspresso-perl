package Fortran::Namelist::Editor;
use strict;
use warnings;
use carp;

sub new {
	my $class=shift;
	my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'hash');
	my $self={
		filename    => undef,
		data        => undef,
		_comments   => [],
		_strings    => [],
		_groups     => [],
		_groupless  => [],
		_vars       => [],
		%opts,
	};
	bless($self,$class);
	return(undef) unless $self->init();
	return($self);
}

sub init {
	my $self=shift;
	if (defined $self->{filename} and (! defined $self->{data})) {
		# slurp in file
		if open(my $fh,$self->{filename}) {
			local $/=undef;
			$self->{data}=<$fh>;
		} else {
			carp "Error opening file '$self->{filename}'";
			return(undef);
		}
	}
}

1;
