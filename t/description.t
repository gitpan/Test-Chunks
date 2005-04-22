use Test::Chunks;

plan tests => 1 * chunks;

my @chunks = chunks;

is($chunks[0]->description, 'One Time');
is($chunks[1]->description, 'Two Toes');
is($chunks[2]->description, 'Three Tips');

__END__
=== One Time
=== Two Toes
--- foo



=== Three Tips
