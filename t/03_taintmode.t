#!/usr/bin/perl -T

use strict;
use warnings;

use Cwd;
use Fcntl ':mode';

# blindly untaint PATH (since there's no way we can know what is safe)
# hopefully anyone using Proc::Daemon in taint mode will set PATH more carefully
# update: let's try to remove things known (reported) to be unsafe
local $ENV{'PATH'} = join ':', grep { ( (stat($_))[2] & S_IWOTH ) != 2 } $ENV{'PATH'} =~ /([^:]+)/g;
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

# Try to make sure we are in the test directory
my $cwd = Cwd::cwd();
chdir 't' if $cwd !~ m{/t$};
$cwd = Cwd::cwd();
$cwd = ($cwd =~ /^(.*)$/)[0]; # untaint

# re-run 02_testmodule.t with taint mode on
require "$cwd/02_testmodule.t";
