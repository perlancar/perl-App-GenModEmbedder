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

Suppose you depend on a (trivial, single file, stable) module and wants to
eliminate dependency on that module by embedding it into your source code. Just
put the output of this tool somewhere in your source code.

Compared to fatpacking, this technique does not use require hook and is suitable
for use in module source code too in addition to script.

Compared to datapacking, this technique does not use require hook nor DATA
section, suitable for use in module source code too in addition to script.

_
    args => {
        module => {
            schema => 'perl::modname',
            req => 1,
            pos => 0,
        },
        strip_pod => {
            schema => ['bool*', is=>1],
            default => 1,
        },
        # XXX indent_level
    },
    links => [
        {url => 'Module::FatPack'},
        {url => 'Module::DataPack'},
        {url => 'App::FatPacker'},
        {url => 'App::depak'},
    ],
};
sub gen_mod_embedder {
    require File::Slurper;
    require Module::Path::More;

    my %args = @_;
    my $mod = $args{module};
    (my $mod_pm = "$mod.pm") =~ s!::!/!g;

    my $path = Module::Path::More::module_path(module => $mod)
        or return [400, "Can't find module $mod on filesystem"];

    my $source = File::Slurper::read_text($path);

    if ($args{strip_pod}) {
        require Perl::Stripper;
        my $stripper = Perl::Stripper->new(
            strip_ws  => 0,
            strip_pod => 1,
            strip_comment => 0,
        );
        $source = $stripper->strip($source);
    }

    $source =~ s/^/#/g;

    # since literal \' and \\ inside single quote gets converted to literal '
    # and \, we need to escape the prefix \ to \\ in those cases.
    $source =~ s/\\(?='|\\)/\\\\$1/g;

    my $preamble = "unless (eval { require $mod; 1 }) {\n";
    $preamble .= "    eval '#line ' . __LINE__ . ' \"' . __FILE__ . qq(\"\\n) . <<'EOS';\n";
    my $postamble = "EOS\n";
    $postamble .= "    die if \$@;\n";
    $postamble .= "}\n";

    return [200, "OK", $preamble . $source . $postamble,
            {"cmdline.skip_format" => 1}];
}

1;
# ABSTRACT:
