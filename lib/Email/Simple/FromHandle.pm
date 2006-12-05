package Email::Simple::FromHandle;
use base qw(Email::Simple);

use strict;

use Carp ();
use IO::String;
use Fcntl qw(SEEK_SET);

use vars qw($VERSION);
$VERSION = '0.011_04';

my $crlf = qr/\x0a\x0d|\x0d\x0a|\x0a|\x0d/; # We are liberal in what we accept.

sub handle { $_[0]->{handle} }
sub body_pos { $_[0]->{body_pos} }

sub new {
    my ($class, $handle) = @_;

    return Email::Simple->new($handle) unless ref $handle;

    my ($head, $mycrlf) = _split_head_from_body($handle);

    my $self = bless {
        handle   => $handle,
        body_pos => tell($handle),
        mycrlf   => $mycrlf,
    }, $class;

    $self->__read_header($head);

    return $self;
}

sub _split_head_from_body {
    my $handle = shift;

    my $text = '';

    # XXX it is stupid to use <> if we're really going to have multiple forms
    # of crlf, but it is expedient to keep doing so for now. -- hdp, 2006-11-28
    # theoretically, this should be ok, because it will only fail if lines are
    # terminated with \x0d, which wouldn't be ok for network transport anyway.
    my $mycrlf;
    while (<$handle>) {
        last if $mycrlf and /\A$mycrlf\z/;
        $text .= $_;
        ($mycrlf) = /($crlf)\z/;
    }

    return ($text, $mycrlf || "\n");
}

sub reset_handle {
  my ($self) = @_;

  # Don't die the first time we try to read from a pipe/socket/etc.
  # TODO: When reading from something non-seekable (body_pos == -1), should we
  # give the option to store data into a temp file, or something similar?
  return unless $self->body_pos > 0 or $self->{_seek}++;
  delete $self->{_get_head_lines};

  seek $self->handle, $self->body_pos, SEEK_SET
    or Carp::croak "can't seek: $!";
}

sub body_set {
  my $self = shift;
  my $body = shift;

  my $handle = IO::String->new(\$body);
  $self->{handle} = $handle;
  $self->{body_pos} = 0;
}

sub body {
  my $self = shift;
  scalar do {
    local $/;
    $self->reset_handle;
    my $handle = $self->handle;
    <$handle>;
  };
}

sub getline {
  my ($self) = @_;
  unless ($self->{_get_head_lines}) {
    $self->{_get_head_lines} = [
      split(/(?<=\n)/, $self->__head->as_string),
      $self->crlf,
    ];
  }
  my $handle = $self->handle;
  return shift @{$self->{_get_head_lines}} || <$handle>;
}

sub _stream_to_print {
  my $fh = shift;
  print {$fh} @_ or die "can't print buffer: $!";
}

sub stream_to {
  my ($self, $fh, $arg) = @_;
  $arg ||= {};
  $arg->{reset_handle} = 1 unless exists $arg->{reset_handle};
  # 65536 is a randomly-chosen magical number that's large enough to be a win
  # over line-by-line reading but small enough not to impinge very much upon
  # ram usage -- hdp, 2006-11-27
  $arg->{chunk_size} ||= 65536;
  $arg->{write}      ||= \&_stream_to_print;
  $arg->{write}->($fh, $self->_headers_as_string . $self->{mycrlf});
  $self->reset_handle if $arg->{reset_handle};
  my $buf;
  while (read($self->handle, $buf, $arg->{chunk_size}) > 0) {
    $arg->{write}->($fh, $buf);
  }
}

1;

__END__

=head1 NAME

Email::Simple::FromHandle - an Email::Simple but from a handle

=head1 VERSION

  $Id: /my/cs/projects/fromhandle/trunk/lib/Email/Simple/FromHandle.pm 22478 2006-06-13T12:51:46.331840Z rjbs  $

version 0.011

=head1 SYNOPSIS

  use Email::Simple::FileHandle;

  open my $fh, "<", "email.msg";

  my $email = Email::Simple::FromHandle->new($fh);

  print $email->as_string;
  # or
  $email->stream_to(\*STDOUT);

=head1 DESCRIPTION

This is a subclass of Email::Simple which can accept filehandles as the source
of an email.  It will keep a reference to the filehandle and read from it when
it needs to access the body.  It does not load the entire body into memory and
keep it there.

=head1 METHODS

In addition to the standard L<Email::Simple> interface, the following methods
are provided:

=head2 handle

This returns the handle given to construct the message.  If the message was
constructed with a string instead, it returns an IO::String object.

=head2 body_pos

This method returns the position in the handle at which the body begins.  This
is used for seeking when re-reading the body.

=head2 reset_handle

This method seeks the handle to the body position and resets the header-line
iterator.

For unseekable handles (pipes, sockets), this will die.

=head2 getline

  $str = $email->getline;

This method returns either the next line from the headers or the next line from
the underlying filehandle.  It only returns a single line, regardless of
context.  Returns C<undef> on EOF.

=head2 stream_to

  $email->stream_to($fh, [ \%arg ]);

This method efficiently writes the message to the passed-in filehandle.  

The second argument may be a hashref of options:

=over 4

=item B<reset_handle:>

Whether or not to call C<< $self->reset_handle >> before reading the message
(default true). 

=item B<chunk_size:>

Number of bytes to read from C<< $self->handle >> at once (default 65536).

=item B<write:>

Coderef to use to print instead of C<print $fh $chunk>.  This coderef will
receive two arguments, the 'filehandle' (which need not be a real filehandle at
all) and the current chunk of data.

=back

=head1 COPYRIGHT

This code is copyright Ricardo SIGNES, 2006.  It is free software, released
with the same licenses as Perl itself.

=cut
