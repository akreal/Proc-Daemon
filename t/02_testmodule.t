#!/usr/bin/perl

use strict;
use warnings;


use Test::More tests => 18;

use Cwd;

use Proc::Daemon;


# Since a daemon will not be able to print terminal output, we
# have a test daemon creating a file and another which runs the created
# Perl file.
# The parent process will test for the existence of the created files
# and for the running daemon.


# Try to make sure we are in the test directory
my $cwd = Cwd::cwd();
chdir 't' if $cwd !~ m{/t$};
$cwd = Cwd::cwd();
$cwd = ($cwd =~ /^(.*)$/)[0]; # untaint (needed for 03_taintmode)


# create object
my $daemon = Proc::Daemon->new(
    work_dir     => $cwd,
    child_STDOUT => 'output.file',
    child_STDERR => 'error.file',
    pid_file     => 'pid.file',
);

# create a daemon
umask 022;
my $Kid_PID = $daemon->init; # init instead of Init is a test for the old style too!

if ( ok( $Kid_PID, "child_1 was created with PID: " . ( defined $Kid_PID ? $Kid_PID : '<undef>' ) ) || defined $Kid_PID ) {
    # here goes the child
    unless ( $Kid_PID ) {
        # print something into 'output.file'
        print 'test1';

        # print a new Perl file
        open( FILE, ">$cwd/kid.pl" ) || die;
        print FILE "#!/usr/bin/perl

# create an empty file to test umask
open FILE, '>$cwd/umask.file';
close FILE;

# stay alive vor 10 sec.
foreach ( 1 .. 10 ) { sleep ( 1 ) }

exit;";
        close( FILE );
    }
    # this is only for the parent
    else {
        # wait max. 5 sec. for the child to exit
        my $r = 0;
        while ( $daemon->Status( $Kid_PID ) and $r <= 5 ) { $r++; sleep( 1 ); }

        if ( ok( ! $daemon->Status( $Kid_PID ), "child_1 process did exit within $r sec." ) ) {
            if ( ok( -e "$cwd/pid.file", "child_1 has created a 'pid.file'" ) ) {
                my ( $pid, undef ) = $daemon->get_pid( "$cwd/pid.file" );
                ok( $pid == $Kid_PID, "the 'pid.file' contains the right PID: $pid" );
                ok( (stat("$cwd/pid.file"))[2] == 33152, "the 'pid.file' has right permissions" );
                unlink "$cwd/pid.file";
            }

            if ( ok( -e "$cwd/output.file", "child_1 has created a 'output.file'" ) ) {
                open( FILE, "<", "$cwd/output.file" );
                ok( <FILE> eq 'test1', "the content of the 'output.file' was right." );
                close FILE;
                unlink "$cwd/output.file";
            }

            if ( ok( -e "$cwd/error.file", "child_1 has created a 'error.file'" ) ) {
                unlink "$cwd/error.file";
            }

            if ( ok( -e "$cwd/kid.pl", "child_1 has created the 'kid.pl' file" ) ) {
                my $Kid_PID2 = $daemon->Init( { 
                    exec_command => "perl $cwd/kid.pl",
                    # this is essentially a noop but gives us better test coverage
                    setgid => (split / /, $))[0],
                    setuid => $>,
                } );

                if ( ok( $Kid_PID2, "child_2 was created with PID: " . ( defined $Kid_PID2 ? $Kid_PID2 : '<undef>' ) ) ) {
                    if ( ok( -e "$cwd/pid_1.file", "child_2 created a 'pid_1.file'" ) ) {
                        my ( $pid, undef ) = $daemon->get_pid( "$cwd/pid_1.file" );
                        ok( $pid == $Kid_PID2, "the 'pid_1.file' contains the right PID: $pid" )
                    }

                    # wait max. 5 sec. for the (second) child to write all files
                    $r = 0;
                    while ( ! -e "$cwd/error_1.file" and $r <= 5 ) { $r++; sleep( 1 ); }

                    if ( ok( -e "$cwd/output_1.file", "child_2 created a 'output_1.file'" ) ) {
                        unlink "$cwd/output_1.file";
                    }

                    if ( ok( -e "$cwd/error_1.file", "child_2 created a 'error_1.file'" ) ) {
                        unlink "$cwd/error_1.file";
                    }

                    sleep( 3 );
                    diag( 'Parent slept for 3 sec.' );

                    my $pid = $daemon->get_pid_by_proc_table_attr( 'cmndline', "perl $cwd/kid.pl", 1 );
                    diag( "Proc::ProcessTable is installed and did find the right PID for 'perl $cwd/kid.pl': $pid" )
                        if defined $pid and $pid == $Kid_PID2;

                    $pid = $daemon->Status( "$cwd/pid_1.file" );
                    ok( $pid == $Kid_PID2, "'kid.pl' daemon is still running" );

                    my $stopped = $daemon->Kill_Daemon();
                    ok( $stopped == 1, "stop daemon 'kid.pl'" );

                    $r = 0;
                    while ( $pid = $daemon->Status( $Kid_PID2 ) and $r <= 10 ) {
                        $r++; sleep( 1 );
                    }
                    ok( $pid != $Kid_PID2, "'kid.pl' daemon was stopped within $r sec." );

                    unlink "$cwd/pid_1.file";

                    ok( (stat("$cwd/umask.file"))[2] == 33188, "the 'umask.file' has right permissions" );
                    unlink "$cwd/umask.file";
                }

                unlink "$cwd/kid.pl";
            }
        }
    }
}
