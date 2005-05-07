use Test::Chunks;

plan tests => 6;

for my $word (qw(new chunk_accessor description name _this)) {
    my $chunks = Test::Chunks->new->spec_string(<<"...");
=== Fail test
--- $word
This is a test
--- foo
This is a test
...
    eval {$chunks->chunks};
    like($@, qr{'$word' is a reserved name});
}

my $chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- bar
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
is("$@", '');
