use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'File::PO::Parser',
    AUTHOR              => q{Orlovskiy Alexander <nordicdyno@gmail.com>},
    VERSION_FROM        => 'lib/File/PO/Parser.pm',
    ABSTRACT_FROM       => 'lib/File/PO/Parser.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'File-PO-Parser-*' },
);
