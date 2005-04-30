use Test::Chunks;

plan 'no_plan';

ok(defined &plan);
ok(defined &is);
ok(defined &isnt);
ok(defined &like);
ok(defined &unlike);
ok(defined &is_deeply);
ok(defined &cmp_ok);
ok(defined &skip);
ok(defined &todo_skip);
ok(defined &pass);
ok(defined &fail);
ok(defined &eq_array);
ok(defined &eq_hash);
ok(defined &eq_set);
ok(defined &can_ok);
ok(defined &isa_ok);
ok(defined &diag);

ok(defined &chunks);
ok(defined &delimiters);
ok(defined &spec_file);
ok(defined &spec_string);
ok(defined &filters);
ok(defined &filters_map);
ok(defined &run);
ok(defined &run_is);
ok(defined &run_like);
ok(not defined &diff_is);

ok(defined &WWW);
ok(defined &XXX);
ok(defined &YYY);
ok(defined &ZZZ);
