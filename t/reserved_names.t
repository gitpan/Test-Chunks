use Test::Chunks;

plan tests => 5;

my $chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- new
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
like($@, qr{'new' is a reserved name});

$chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- field
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
like($@, qr{'field' is a reserved name});

$chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- description
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
like($@, qr{'description' is a reserved name});

$chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- _this
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
like($@, qr{'_this' is a reserved name});

$chunks = Test::Chunks->new->spec_string(<<'...');
=== Fail test
--- bar
This is a test
--- foo
This is a test
...
eval {$chunks->chunks};
is("$@", '');
