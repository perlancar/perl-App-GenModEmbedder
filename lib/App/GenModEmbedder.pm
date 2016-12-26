package App::GenModEmbedder;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{gen_mod_embedder} = {
    v => 1.1,
    summary => 'Generate a piece of Perl code that embeds a module',
    description => <<'_',

Suppose your code depends on a (trivial, single file, stable) module and wants
to eliminate dependency on that module by embedding it into your code. To do
that, just put the output of this tool (the embedding code) somewhere in your
source code. The structure of the embedding code is as follows:

    unless (eval { require Foo::Bar; 1 }) {
        my $source = <<'END_OF_SOURCE';
        ...
        ...
    END_OF_SOURCE
        eval $source; die if $@;
        $INC{'Foo/Bar.pm'} = '(set by ' . __FILE__ . ')';
    }

Compared to fatpacking, this technique tries to load the original module first,
does not use require hook, and is suitable for use inside .pm file as well as
script.

Compared to datapacking, this technique tries to load the original module first,
does not use require hook nor DATA section, and is suitable for use inside .pm
file as well as script.

_
    args => {
        module => {
            schema => 'perl::modname',
            req => 1,
            pos => 0,
            completion => sub {
                require Complete::Module;
                my %args = @_;
                Complete::Module::complete_module(word=>$args{word});
            },
        },
        strip_pod => {
            schema => ['bool*', is=>1],
            default => 1,
        },
        indent_level => {
            schema => ['int*', min=>0],
            default => 0,
        },
    },
    links => [
        {url => 'Module::FatPack'},
        {url => 'Module::DataPack'},
        {url => 'App::FatPacker'},
        {url => 'App::depak'},
    ],
};
sub gen_mod_embedder {
    no strict 'refs';
    no warnings 'once';
    require ExtUtils::MakeMaker;
    require File::Slurper;
    require Module::Path::More;

    my %args = @_;
    my $mod = $args{module};
    (my $mod_pm = "$mod.pm") =~ s!::!/!g;

    my $path = Module::Path::More::module_path(module => $mod)
        or return [400, "Can't find module $mod on filesystem"];

    my $version = MM->parse_version($path);
    defined $version or return [400, "Can't extract VERSION for $mod from $path"];

    my $source = File::Slurper::read_text($path);

    if ($args{strip_pod}) {
        require Perl::Stripper;
        my $stripper = Perl::Stripper->new(
            # strip_pod => 1, # the default
            strip_comment => 0,
        );
        $source = $stripper->strip($source);
    }

    $source =~ s/\s+\z//s;
    $source .= "\n";
    $source =~ s/^/#/mg;

    my $i0 = "    " x $args{indent_level};

    my $preamble = "${i0}# BEGIN EMBEDDING MODULE: mod=$mod ver=$version generator=\"".__PACKAGE__." ".(${__PACKAGE__."::VERSION"})."\" generated-at=\"".(scalar localtime)."\"\n";
    $preamble .= "${i0}unless (eval { require $mod; 1 }) {\n";
    $preamble .= "${i0}    my \$source = '##line ' . (__LINE__+1) . ' \"' . __FILE__ . qq(\"\\n) . <<'EOS';\n";
    my $postamble = "EOS\n";
    $postamble .= "${i0}    \$source =~ s/^#//gm;\n";
    $postamble .= "${i0}    eval \$source; die if \$@;\n";
    $postamble .= "${i0}    \$INC{'$mod_pm'} = '(set by embedding code in '.__FILE__.')';\n";
    $postamble .= "${i0}}\n";
    $postamble .= "${i0}# END EMBEDDING MODULE\n";

    return [200, "OK", $preamble . $source . $postamble,
            {"cmdline.skip_format" => 1}];
}

1;
# ABSTRACT:
