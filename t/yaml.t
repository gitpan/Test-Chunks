use Test::Chunks;

if (eval("require YAML; 1")) {
    filters_map {
        data1 => 'yaml',
        data2 => 'eval',
    };
    plan tests => 1 * chunks;
}
else {
    plan skip_all => "YAML.pm required for this test";
    exit 0;
}

run {
    my $chunk = shift;
    is_deeply($chunk->data1, $chunk->data2, $chunk->description);
};

__END__
=== YAML Hashes
--- data1
foo: xxx
bar: [ 1, 2, 3]
--- data2
+{
    foo => 'xxx',
    bar => [1,2,3],
}
=== YAML Arrays
--- data1
- foo
- bar
- {x: y}
--- data2
[
    'foo',
    'bar',
    { x => 'y' },
]
=== YAML Scalar
--- data1
--- |
    sub foo {
        print "bar\n";
    }
--- data2
<<'END';
sub foo {
    print "bar\n";
}
END
