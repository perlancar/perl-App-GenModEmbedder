#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use App::GenModEmbedder;

my $res = App::GenModEmbedder::gen_mod_embedder(
    module => 'String::PerlQuote',
    # we rename to a non-existing name to be able to test loading the embedded
    # code, otherwise the embedding code will prefer the existing
    # String::PerlQuote on the filesystem
    as     => 'String::PerlQuote2',
);
#diag explain $res;

eval $res->[2]; die if $@;

require String::PerlQuote2;

is(String::PerlQuote2::double_quote('a'), '"a"');
is(String::PerlQuote2::double_quote('\\a'), '"\\\\a"');

done_testing;
