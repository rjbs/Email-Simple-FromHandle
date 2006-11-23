#!/usr/bin/perl -w
use strict;
use Test::More tests => 9;
use Symbol;

sub read_file   { local $/; local *FH; open FH, shift or die $!; return <FH>; }
sub file_handle { my $fh = gensym; open $fh, "<", $_[0] or die $!; return $fh }

use_ok("Email::Simple::FromHandle");

# Very basic functionality test
my $mail_text   = read_file("t/test-mails/josey-nofold");
my $mail_handle = file_handle("t/test-mails/josey-nofold");
my $mail = Email::Simple::FromHandle->new($mail_handle);

isa_ok($mail, "Email::Simple");
isa_ok($mail, "Email::Simple::FromHandle");

like($mail->header('From'), qr/Andrew/, "Andrew's in the header");

$mail->reset_handle;

my $handle = $mail->handle;

my @body = <$handle>;

is(@body, 78, "78 lines in body");

$mail->reset_handle;

is(
  <$handle>,
  "Joanna, All\n",
  "first line gotten as requested",
);

is(
  $mail->getline,
  "Received: (qmail 1679 invoked by uid 503); 13 Nov 2002 10:10:49 -0000\n",
  "first header line gotten",
);

{
  pipe(my($rdr, $wtr));
  unless (fork) {
    close $rdr;
    seek $mail_handle, 0, 0;
    my $mail = Email::Simple::FromHandle->new($mail_handle);
    $mail->stream_to($wtr);
    exit 0;
  }
  close $wtr;
  $mail = Email::Simple::FromHandle->new($rdr);
  is $mail->as_string, $mail_text, "text from pipe";
  eval { $mail->as_string };
  like $@, qr/illegal seek/i, "illegal seek on pipe";
}
