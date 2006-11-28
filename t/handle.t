#!/usr/bin/perl -w
use strict;
use Test::More tests => 10;
use Symbol;

sub read_file   { local $/; local *FH; open FH, shift or die $!; return <FH>; }
sub file_handle { my $fh = gensym; open $fh, "<", $_[0] or die $!; return $fh }

use_ok("Email::Simple::FromHandle");

# Very basic functionality test
my $mail_text   = read_file("t/test-mails/header-blank");
my $mail_handle = file_handle("t/test-mails/header-blank");
my $mail = Email::Simple::FromHandle->new($mail_handle);

isa_ok($mail, "Email::Simple");
isa_ok($mail, "Email::Simple::FromHandle");

like($mail->header('From'), qr/Business People/, "correct From:");

$mail->reset_handle;

my $handle = $mail->handle;

my @body = <$handle>;

is(@body, 59, "59 lines in body");

$mail->reset_handle;

is(
  <$handle>,
  "XyzzyXX,\n",
  "first line gotten as requested",
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
  my $ref = Email::Simple->new($mail_text);
  is $mail->body, $ref->body, "body from pipe";
  is $mail->header('Message-ID'), $ref->header('Message-ID'),
    "message-id from pipe";
  # just in case the same bug ever pops up in E::S
  isnt $mail->header('Message-ID'), '',
    "message-id from pipe isn't empty";
  eval { $mail->as_string };
  like $@, qr/illegal seek/i, "illegal seek on pipe";
}
