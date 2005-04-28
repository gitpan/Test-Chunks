use Test::Chunks;

plan tests => 5;

my @chunks = chunks;

eval {
    filters('blah', 'blam');
};
like("$@", qr{^Too late to call filters\(\)});

eval {
    filters_map({foo => 'grate'});
};
like("$@", qr{^Too late to call filters_map\(\)});

eval {
    delimiters('***', '&&&');
};
like("$@", qr{^Too late to call delimiters\(\)});

eval {
    spec_file('foo.txt');
};
like("$@", qr{^Too late to call spec_file\(\)});

eval {
    spec_string("my spec\n");
};
like("$@", qr{^Too late to call spec_string\(\)});

__DATA__

=== Dummy
--- foo
--- bar
