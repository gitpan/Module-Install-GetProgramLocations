use Test::More tests => 10;

use Module::Install::GetProgramLocations;

#1
my $gpls = new Module::Install::GetProgramLocations;
ok(defined $gpls, 'Module::Install::GetProgramLocations creation');

#2
is($gpls->Version_Matches_Range('1.0.2', '[1.0,)'), 1,
  'Greater than minimum');

#3
is($gpls->Version_Matches_Range('1.0.2', '(,1.4)'), 1,
  'Less than maximum');

#4
is($gpls->Version_Matches_Range('1.0.2', '(1.0.2,1.4)'), 0,
  'Not equal boundary');

#5
is($gpls->Version_Matches_Range('1.0.2', '[1.0.2,1.4)'), 1,
  'Equal boundary');

#6
is($gpls->Version_Matches_Range('1.0.2', '[1.0,)'), 1,
  'Greater than minimum subversion');

#7
is($gpls->Version_Matches_Range('1.0.2', '[0.5,0.8] (1.0,1.4)'), 1,
  'In second range');

#8
is($gpls->Version_Matches_Range('1.9.2', '[1,1.7], [1.8,1.9]'), 0,
  'Not in two ranges');

{
  my %info = (
    'TestProgram' => { versions => {
                         'Test' => { fetch => \&Get_Test_Program_Version,
                                     numbers => '[1.2.3,)', },
                       },
                     },
  );

  # 9
  is($gpls->Module::Install::GetProgramLocations::_Program_Version_Is_Valid(
    'TestProgram','perl t/dummy_program.pl',\%info),1,
    'Check valid program version');
}

{
  my %info = (
    'TestProgram' => { versions => {
                         'Test' => { fetch => \&Get_Test_Program_Version,
                                     numbers => '[1.2.4,)', },
                       },
                     },
  );

  # 10
  is($gpls->Module::Install::GetProgramLocations::_Program_Version_Is_Valid(
    'TestProgram','perl t/dummy_program.pl',\%info),0,
    'Check invalid program version');
}

#--------------------------------------------------------------------------------

sub Get_Test_Program_Version
{
  my $program = shift;
  
  my $version = `$program`;
  chomp $version;

  return $version;
}
