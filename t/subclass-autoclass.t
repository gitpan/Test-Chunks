package Testorama;
use Test::Chunks -Base;

BEGIN {
    our @EXPORT = qw(run_orama);
}

sub run_orama {
    pass('Testorama EXPORT ok');;
}

package Testorama::Chunk;
use base 'Test::Chunks::Chunk';

sub foofoo {
    Test::More::pass('Testorama::Chunk ok');
}

package Testorama::Filter;
use base 'Test::Chunks::Filter';

sub rama_rama {
    Test::More::pass('Testorama::Filter ok');
}

package main;
# use Testorama;
BEGIN { Testorama->import }

plan tests => 3;

run_orama;

[chunks]->[0]->foofoo;

__DATA__
===
--- stuff chomp rama_rama
che!
