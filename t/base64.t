use Test::Chunks;

plan tests => 1 * chunks;

run {
    my $chunk = shift;
    is($chunk->encoded, $chunk->decoded, $chunk->name);
};

__END__
=== Test One
--- encoded base64
SSBMb3ZlIEx1Y3kK

--- decoded
I Love Lucy







=== Test Two

--- encoded base64
c3ViIHJ1bigmKSB7CiAgICBteSAkc2VsZiA9ICRkZWZhdWx0X29iamVjdDsKICAgIG15ICRjYWxs
YmFjayA9IHNoaWZ0OwogICAgZm9yIG15ICRjaHVuayAoJHNlbGYtPmNodW5rcykgewogICAgICAg
ICZ7JGNhbGxiYWNrfSgkY2h1bmspOwogICAgfQp9Cg==

--- decoded

sub run(&) {
    my $self = $default_object;
    my $callback = shift;
    for my $chunk ($self->chunks) {
        &{$callback}($chunk);
    }
}


