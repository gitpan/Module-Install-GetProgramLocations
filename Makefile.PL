#/usr/bin/perl

use strict;
use inc::Module::Install;

name            ('Module-Install-GetProgramLocations');
author          ('David Coppit <david@coppit.org>');
abstract_from   ('lib/Module/Install/GetProgramLocations.pm');
version_from    ('lib/Module/Install/GetProgramLocations.pm');
license         ('gpl');

requires        (
                  'File::Spec',
                  'Cwd',
                  'Sort::Versions',
                  'Module::Install',
                );

include         ('ExtUtils/AutoInstall.pm');
auto_install    ( -default => 0 );

WriteAll();

print "\n", '-'x78, "\n\n";

exit;
