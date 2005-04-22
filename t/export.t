use Test::Chunks;

plan 'no_plan';

ok(defined &plan);
ok(defined &is);
ok(defined &like);
ok(defined &is_deeply);
ok(defined &fail);

ok(defined &chunks);
ok(defined &delimiters);
ok(defined &spec_file);
ok(defined &spec_string);
ok(defined &filters);
ok(defined &run);
ok(defined &diff_is);

ok(defined &WWW);
ok(defined &XXX);
ok(defined &YYY);
ok(defined &ZZZ);

ok(not defined &foo);
