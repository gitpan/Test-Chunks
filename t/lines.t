use Test::Chunks;

plan tests => 4;

is_deeply 
[chunks]->[0]->text1, 
[
    "One\n",
    "Two\n",
    "Three \n",
];

is_deeply
[chunks]->[0]->text2, 
[
    "Three\n",
    "Two\n",
    "One",
];

is(ref([chunks]->[0]->text3), 'ARRAY');
is(scalar(@{[chunks]->[0]->text3}), 0);

__END__
=== One
--- text1 lines
One
Two
Three 
--- text2 chomp lines
Three
Two
One
--- text3 lines
