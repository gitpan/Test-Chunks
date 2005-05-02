use Test::Chunks;

plan tests => 5;

my $chunk1 = [chunks]->[0];
my @values = $chunk1->grocery;
is(scalar(@values), 3, 'Check list context');
is_deeply \@values, ['apples', 'oranges', 'beef jerky'];

my $chunk2 = [chunks]->[1];
is_deeply $chunk2->todo, 
[
    'Fix YAML', 
    'Fix Inline', 
    'Fix Test::Chunks',
];

my $chunk3 = [chunks]->[2];
is($chunk3->perl, 'xxx');
is_deeply([$chunk3->perl], ['xxx', 'yyy', 'zzz']);

__END__

=== One
--- grocery lines chomp
apples
oranges
beef jerky

=== Two
--- todo lines chomp array
Fix YAML
Fix Inline
Fix Test::Chunks

=== Three
--- perl eval
return qw(
    xxx
    yyy
    zzz
)
