package POE::Component::DirWatch::WithCaller;

use strict;
use warnings;
use Moose;
use POE;

extends 'POE::Component::DirWatch';

has ignore_seen => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 0,
);
has ensure_seen => (
	is => 'ro',
	isa => 'Int',
	required => 0,
	default => 0,
);
has seen_files => (
	is => 'rw',
	isa => 'HashRef',
	default => sub{{}},
);

override '_poll' => sub {
	my ($self, $kernel) = @_[OBJECT, KERNEL];
	$self->clear_next_poll;

	#just do this part once per poll
	%{ $self->seen_files } = map {$_ => $self->seen_files->{$_} } grep {-e $_ } keys %{ $self->seen_files };
	my $filter = $self->has_filter ? $self->filter : undef;
	my $has_dir_cb  = $self->has_dir_callback;
	my $has_file_cb = $self->has_file_callback;

	while (my $child = $self->directory->next) {
		if($child->is_dir) {
			next unless $has_dir_cb;
			next if ref $filter && !$filter->($self->alias, $child);
			$kernel->yield(dir_callback => $child);
		} else {
			next unless $has_file_cb;
			next if $child->basename =~ /^\.+$/;
			$self->seen_files->{"$child"} = 0 if not defined $self->seen_files->{"$child"};
			next unless $self->seen_files->{"$child"} == 0 or $self->seen_files->{"$child"} > 120 or not $self->ignore_seen;
			$self->seen_files->{"$child"}++ unless ($self->seen_files->{"$child"}*$self->interval) > 120 and $self->seen_files->{"$child"} = -1;
			$self->seen_files->{"$child"} = 1 if $self->ignore_seen and not $self->ensure_seen;
			next if ref $filter && !$filter->($self->alias, $child);
			$kernel->yield(file_callback => $child);
		}
	}

	$self->next_poll( $kernel->delay_set(poll => $self->interval) );
};

override '_file_callback' => sub {
	my ($self, $kernel, $file) = @_[OBJECT, KERNEL, ARG0];
	$self->file_callback->($self->alias, $file);
};

override '_dir_callback' => sub {
	my ($self, $kernel, $dir) = @_[OBJECT, KERNEL, ARG0];
	$self->dir_callback->($self->alias, $dir);
};


1;
__END__

=pod

=encoding UTF-8

=head1 NAME

POE::Component::DirWatch::WithCaller - Identical to POE::Component::DirWatch, but &filter and &(file,dir)_callback will be called with the name of the originating event. Will optionally also filter previously-seen files.

=head1 VERSION

1.0.0

=head1 FILTERING PREVIOUSLY-SEEN FILES

Depending on use case, it may be beneficial or necessary to filter out previously-seen files, either for performance reasons when monitoring highly populous directories for specific files, or for avoiding reprocessing files in the event that they are left in the directory after initial processing.
In this case, simply specifying C<ignore_seen =E<gt> 1> as a named argument when creating the DirWatch::WithCaller object will enable this behaviour.
While testing this feature, however, it was observed that some edge cases exist in which a file will be considered 'seen' when it has not been processed despite matching a defined monitor. To account for this, each file that has been considered 'seen' will be reprocessed once around 120 seconds after it was first 'seen'. This behaviour may not be desirable, and as such is disabled by default, and can be enabled by specifying C<ensure_seen =E<gt> 1> when creating the object.

=head1 SEE ALSO

L<POE::Component::DirWatch>, L<POE::Component::DirWatch::Object::NewFile>

=head1 AUTHOR

Guillermo Roditi, <groditi@cpan.org>

with minor changes by
Matthew Connelly, <matthew@maff.scot>

and inclusions from code written by
Robert Rothenberg, <rrwo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) Matthew Connelly, 2015

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
