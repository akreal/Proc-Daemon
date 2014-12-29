use ExtUtils::MakeMaker;

require 5.008;

WriteMakefile(
	NAME => 'Proc::Daemon',
	AUTHOR => 'Earl Hood earl@earlhood.com, Detlef Pilzecker deti@cpan.org',
	VERSION_FROM => 'lib/Proc/Daemon.pm',
	PREREQ_PM => {
		'POSIX' => 0,
	},
	LICENSE => 'perl',
);