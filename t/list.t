use Test::Chunks;

plan tests => 2;

my $chunk1 = [chunks]->[0];
is_deeply $chunk1->grocery, ['apples', 'oranges', 'beef jerky'];

my $chunk2 = [chunks]->[1];
is_deeply $chunk2->todo, 
[
    'Fix YAML', 
    'Fix Inline', 
    'Fix Test::Chunks',
];


__END__
=== One
--- grocery list
apples
oranges
beef jerky




=== Two
--- todo list
Fix YAML
Fix Inline
Fix Test::Chunks
