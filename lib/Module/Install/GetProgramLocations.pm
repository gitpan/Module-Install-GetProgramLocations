package Module::Install::GetProgramLocations;

use strict;
use Config;
use Cwd;
use File::Spec;
use Sort::Versions;
use Exporter();

use vars qw( @ISA $VERSION @EXPORT );

use Module::Install::Base;
@ISA = qw( Module::Install::Base Exporter );

@EXPORT = qw( &Get_GNU_Grep_Version &Get_Bzip2_Version );

$VERSION = '0.10.0';

# ---------------------------------------------------------------------------

sub Get_Program_Locations
{
  my $self = shift;
  my %info = %{ shift @_ };

  # By default the programs have no paths
  my %programs = map { $_ => undef } keys %info;

  my ($programs_ref,$program_specified_on_command_line) =
    $self->_Get_ARGV_Program_Locations(\%programs,\%info);
  %programs = %$programs_ref;

  return %programs if $program_specified_on_command_line;

  %programs = $self->_Prompt_User_For_Program_Locations(\%programs,\%info);

  return %programs;
}

# ---------------------------------------------------------------------------

sub _Get_ARGV_Program_Locations
{
  my $self = shift;
  my %programs = %{ shift @_ };
  my %info = %{ shift @_ };

  my $program_specified_on_command_line = 0;
  my @remaining_args;

  # Look for user-provided paths in @ARGV
  foreach my $arg (@ARGV)
  {
    my ($var,$value) = $arg =~ /^(.*?)=(.*)$/;
    $value = undef if $value eq '';

    if (!defined $var)
    {
      push @remaining_args, $arg;
    }
    else
    {
      my $is_a_program_arg = 0;

      foreach my $program (keys %info)
      {
        if ($var eq $info{$program}{'argname'})
        {
          $programs{$program} = $value;
          $program_specified_on_command_line = 1;
          $is_a_program_arg = 1;
        }
      }

      push @remaining_args, $arg unless $is_a_program_arg;
    }
  }

  @ARGV = @remaining_args;

  return (\%programs,$program_specified_on_command_line);
}

# ---------------------------------------------------------------------------

sub _Prompt_User_For_Program_Locations
{
  my $self = shift;
  my %programs = %{ shift @_ };
  my %info = %{ shift @_ };

  my @path = split /$Config{path_sep}/, $ENV{PATH};

  ASK: foreach my $program_name (sort keys %programs)
  {
    my $name = $Config{$program_name} || $info{$program_name}{'default'};

    # Convert any default to a full path, initially
    my $full_path = $self->can_run($name);
    $full_path = 'none' if !defined $full_path || $name eq '';

    my $choice = $self->prompt(
      "Where can I find your \"$program_name\" executable?" => $full_path);

    $programs{$program_name} = undef, next if $choice eq 'none';

    $choice = $self->_Make_Absolute($choice);

    unless (defined $self->can_run($choice))
    {
      print "\"$choice\" does not appear to be a valid executable\n";
      redo ASK;
    }

    redo ASK
      unless $self->_Program_Version_Is_Valid($program_name,$choice,\%info);

    $programs{$program_name} = $choice;
  }

  return %programs;
}

# ---------------------------------------------------------------------------

sub _Program_Version_Is_Valid
{
  my $self = shift;
  my $program_name = shift;
  my $program = shift;
  my %info = %{ shift @_ };

  if (exists $info{$program_name}{'versions'})
  {
    my $program_version;

    VERSION: foreach my $version (keys %{$info{$program_name}{'versions'}})
    {
      $program_version = 
        &{$info{$program_name}{'versions'}{$version}{'fetch'}}($program);

      next VERSION unless defined $program_version;

      if ($self->Version_Matches_Range($program_version,
        $info{$program_name}{'versions'}{$version}{'numbers'}))
      {
        return 1;
      }
    }

    my $program_version_string = '<UNKNOWN>';
    $program_version_string= $program_version if defined $program_version;
    print "\"$program\" version $program_version_string is not valid for any of the following:\n";

    foreach my $version (keys %{$info{$program_name}{'versions'}})
    {
      print "  $version => " .
        $info{$program_name}{'versions'}{$version}{'numbers'} . "\n";
    }

    return 0;
  }

  return 1;
}

# ---------------------------------------------------------------------------

sub Version_Matches_Range
{
  my $self = shift;
  my $version = shift;
  my $version_specification = shift;

  my $range_pattern = '([\[\(].*?\s*,\s*.*?[\]\)])';

  my @ranges = $version_specification =~ /$range_pattern/g;

  die "Version specification \"$version_specification\" is incorrect\n"
    unless @ranges;

  foreach my $range (@ranges)
  {
    my ($lower_bound,$lower_version,$upper_version,$upper_bound) =
      ( $range =~ /([\[\(])(.*?)\s*,\s*(.*?)([\]\)])/ );
    $lower_bound = '>' . ( $lower_bound eq '[' ? '=' : '');
    $upper_bound = '<' . ( $upper_bound eq ']' ? '=' : '');

    my ($lower_bound_satisified, $upper_bound_satisified);

    $lower_bound_satisified =
      ($lower_version eq '' || versioncmp($version,$lower_version) == 1 ||
      ($lower_bound eq '>=' && versioncmp($version,$lower_version) == 0));
    $upper_bound_satisified =
      ($upper_version eq '' || versioncmp($version,$upper_version) == -1 ||
      ($upper_bound eq '<=' && versioncmp($version,$upper_version) == 0));

    return 1 if $lower_bound_satisified && $upper_bound_satisified;
  }

  return 0;
}

# ---------------------------------------------------------------------------

sub _Make_Absolute
{
  my $self = shift;
  my $program = shift;

  if(File::Spec->file_name_is_absolute($program))
  {
    return $program;
  }
  else
  {
    my $path_to_choice = undef;

    foreach my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), cwd())
    {
      $path_to_choice = File::Spec->catfile($dir, $program);
      last if defined $self->can_run($path_to_choice);
    }

    print "WARNING: Avoid security risks by converting to absolute paths\n";
    print "\"$program\" is currently in your path at \"$path_to_choice\"\n";

    return $path_to_choice;
  }
}

# ---------------------------------------------------------------------------

sub Get_GNU_Grep_Version
{
  my $program = shift;

  my $version_message;

  # Newer versions
  {
    my $command = "$program --version 2>" . File::Spec->devnull();
    $version_message = `$command`;
  }

  # Older versions use -V
  unless($version_message =~ /\bGNU\b/)
  {
    my $command = "$program -V 2>&1 1>" . File::Spec->devnull();
    $version_message = `$command`;
  }

  return undef unless $version_message =~ /\bGNU\b/;

  my ($program_version) = $version_message =~ /^.*?([\d]+\.[\d.a-z]+)/s;

  return $program_version;
}

# ---------------------------------------------------------------------------

sub Get_Bzip2_Version
{
  my $program = shift;

  my $command = "$program --help 2>&1 1>" . File::Spec->devnull();
  my $version_message = `$command`;

  my ($program_version) = $version_message =~ /^.*?([\d]+\.[\d.a-z]+)/s;

  return $program_version;
}

1;

# ---------------------------------------------------------------------------

=head1 NAME

Module::Install::GetProgramLocations - A Module::Install extension that allows
the user to interactively specify the location of programs needed by the
module to be installed


=head1 SYNOPSIS

A simple example:

  use inc::Module::Install;
  ...
  my %info = (
    # No default, and can't specify it on the command line
    'diff'     => {},
    # A full path default and a command line variable
    'grep'     => { default => '/usr/bin/grep', argname => 'GREP' },
    # A no-path default and a command line variable
    'gzip'     => { default => 'gzip', argname => 'GZIP' },
  );
  my %locations = Get_Program_Locations(\%info);

A complex example showing all the bells and whistles:

  use inc::Module::Install;
  # So Module::Install::GetProgramLocations can be found
  use lib 'inc';
  # To import Get_GNU_Grep_Version and Get_Solaris_Grep_Version
  use Module::Install::GetProgramLocations;
  ...
  my %info = (
    # Either the GNU or the Solaris version
    'grep'     => { default => 'grep', argname => 'GREP',
                    versions => {
                      # Any GNU version higher than 2.1
                      'GNU' =>     { fetch => \&Get_GNU_Grep_Version,
                                     numbers => '[2.1,)', },
                      # Any solaris version higher than 1.0, except 1.1
                      'Solaris' => { fetch => \&Get_Solaris_Grep_Version,
                                     numbers => '[1.0,1.1) (1.1,]', },
                    },
                  },
  );
  my %locations = Get_Program_Locations(\%info);


=head1 DESCRIPTION

If you are installing a module that calls external programs, it's best to make
sure that those programs are installed and working correctly. This
Module::Install extension helps with that process. It allows the user to
interactively specify either full path to a program, or an unqualified program
name. In the latter case, the module will search the user's path to find the
first matching program. 

This extension will then perform validation on the program.  It makes sure
that the program can be run, and will optionally check the version for
correctness if the user provides that information.

The extension returns a hash mapping the program names to their absolute
paths.  (It's best to use the absolute path in order to avoid security
problems.)

The user can avoid the interactive prompts by specifying one or more paths to
the programs on the command line call to "perl Makefile.PL". Note that no
validation of the programs is done in this case. 

=head1 METHODS

=over 4

=item %paths = Get_Program_Locations(\%info)

This function takes as input a hash with information for the programs to be
found. The keys are the program names (and can actually be anything). The
values are named:

=over 2

=item default

The default program. This can be non-absolute, in which case the user's PATH
is searched. For example, you might specify "bzip2" as a default for the
"bzip" program because bzip2 can unpack older bzip archives.

=item argname

The command line variable name. For example, if you want the user to be able
to set the path to bzip2, you might set this to "BZIP2" so that the user can
run "perl Makefile.PL BZIP2=/usr/bin/bzip2".

=item versions

A hash mapping a descriptive version name to a hash containing a mapping for
two keys:

=over 2

=item fetch

Specifies a subroutine that takes the program path as an argument, and returns
either undef (if the program is not correct) or a version number.

=item numbers

A string containing allowed version ranges. Ranges are specified using
interval notation. That is "[1,2)" indicates versions between 1 and 2,
including 1 but not 2. Any characters can separate ranges, although you'd best
not use any of "[]()" in order to avoid confusing the module.

This module uses the Sort::Versions module for comparing version numbers. See
that module for a summary of version string syntax, and an explanation of how
they compare.

=back

=back

The return value for Get_Program_Locations is a hash whose keys are the same
as those of %info, and whose values are either an absolute path for the
program location, or undef (for no program location).

=item $boolean = Version_Matches_Range($program_version, $range);

This function takes a program version string and a version ranges specification
and determines if the program version is in any of the ranges. For example
'1.2.3a' is in the second range of '[1.0,1.1) (1.2.3,)' because 1.2.3a is
higher than 1.2.3, but less than infinity.

=back

=head1 VERSIONING METHODS

This module provides some functions for extracting the version number from
common programs. They are exported by default into the caller's namespace.
Feel free to submit new version functions for programs that you use.

=over 4

=item $version = Get_GNU_Grep_Version($path_to_program)

Gets the version of GNU grep. Returns undef if the word "GNU" does not appear
in the version information

=item $version = Get_Bzip2_Version($path_to_program)

Gets the version of bzip2.

=back

=head1 AUTHOR

David Coppit <david@coppit.org>.


=head1 LICENSE

This software is distributed under the terms of the GPL. See the file
"LICENSE" for more information.

=cut

