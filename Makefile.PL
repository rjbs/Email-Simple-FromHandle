use strict;
use warnings;

use inc::Module::Install;

name          ('Email-Simple-FromHandle');
author        ('Ricardo SIGNES <rjbs@cpan.org>');
license       ('perl');
version_from  ('lib/Email/Simple/FromHandle.pm');

requires      ('Email::Simple' => 1.998);
requires      ('IO::String'    => 0.0);

WriteAll();
