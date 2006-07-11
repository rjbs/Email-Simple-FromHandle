#!/usr/bin/perl -w
use strict;
use Test::More tests => 6;
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
