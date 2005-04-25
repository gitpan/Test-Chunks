package Test::Chunks;
use Spiffy 0.23 -Base;
use Spiffy -XXX;
use Test::More;

our @EXPORT = qw(
    plan is ok like is_deeply fail 
    chunks delimiters spec_file spec_string filters filters_map run
    diff_is
    WWW XXX YYY ZZZ
);

our $VERSION = '0.13';

sub import() {
    strict_warnings();
    goto &Spiffy::import;
}

my $chunk_delim_default = '===';
my $data_delim_default = '---';

const chunk_class => 'Test::Chunk';

field '_spec_file';
field '_spec_string';
field '_filters' => [qw(norm trim)];
field '_filters_map' => {};
field spec =>
      -init => '$self->spec_init';
field chunks_list =>
      -init => '$self->chunks_init';
field chunk_delim =>
      -init => '$self->chunk_delim_default';
field data_delim =>
      -init => '$self->data_delim_default';

sub chunk_delim_default { $chunk_delim_default }
sub data_delim_default { $data_delim_default }

my $default_object = __PACKAGE__->new;
sub default_object { $default_object }

sub chunks() {
    my $self = ref($_[0])
    ? shift
    : $default_object;
    my $chunks = $self->chunks_list;
    return @$chunks;
}

sub delimiters() {
    my $self = ref($_[0])
    ? shift
    : $default_object;
    my ($chunk_delimiter, $data_delimiter) = @_;
    $chunk_delimiter ||= $chunk_delim_default;
    $data_delimiter ||= $data_delim_default;
    $self->chunk_delim($chunk_delimiter);
    $self->data_delim($data_delimiter);
    return $self;
}

sub spec_file() {
    my $self = ref($_[0])
    ? shift
    : $default_object;
    $self->_spec_file(shift);
    return $self;
}

sub spec_string() {
    my $self = ref($_[0])
    ? shift
    : $default_object;
    $self->_spec_string(shift);
    return $self;
}

sub filters() {
    my $self = ref($_[0])
    ? shift
    : $default_object;
    my $filters = $self->_filters;
    push @$filters, @_;
    return $self;
}

sub filters_map() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    $self->_filters_map(shift || {});
    return $self;
}

sub filter_norm {
    my $text = shift || '';
    $text =~ s/\015\012/\n/g;
    $text =~ s/\r/\n/g;
    return $text;
}

sub filter_chomp {
    my $text = shift;
    chomp($text);
    return $text;
}

sub filter_trim {
    my $text = shift;
    $text =~ s/\A([ \t]*\n)+//;
    $text =~ s/(?<=\n)\s*\z//g;
    return $text;
}

sub filter_base64 {
    require MIME::Base64;
    MIME::Base64::decode_base64(shift);
}

sub filter_esc {
    my $text = shift;
    $text =~ s/(\\.)/eval "qq{$1}"/ge;
    return $text;
}

sub filter_eval {
    return eval(shift);
}

sub filter_yaml {
    require YAML;
    return YAML::Load(shift);
}

sub filter_lines {
    my $text = shift;
    return [] unless length $text;
    my @lines = ($text =~ /^(.*\n?)/gm);
    return \@lines;
}

sub filter_list {
    return [ 
        map {
            chomp; $_
        } @{$self->filter_lines(shift)}
    ];
}

sub chunks_init {
    my $spec = $self->spec;
    my $cd = $self->chunk_delim;
    my @hunks = ($spec =~ /^(\Q${cd}\E.*?(?=^\Q${cd}\E|\z))/msg);
    my @chunks;
    for my $hunk (@hunks) {
        my $chunk = $self->_make_chunk($hunk);
        return [$chunk]
          if defined $chunk->{ONLY};
        next if defined $chunk->{SKIP};
        push @chunks, $chunk;
    }
    return [@chunks];
}

sub _make_chunk {
    my $hunk = shift;
    my $cd = $self->chunk_delim;
    my $dd = $self->data_delim;
    my $chunk = $self->chunk_class->new;
    $hunk =~ s/\A\Q${cd}\E[ \t]*(.*)\s+// or die;
    my $description = $1;
    my @parts = split /^\Q${dd}\E +(\w+) *(.*)?\n/m, $hunk;
    shift @parts;
    while (@parts) {
        my ($type, $filters, $text) = splice(@parts, 0, 3);
        for my $filter ($self->_get_filters($type, $filters)) {
            $text = $self->$filter($text);
        }
        $chunk->set_chunk($type, $text);
    }
    for (keys %$chunk) {
        $chunk->{$_} ||= '';
    }
    $chunk->description($description);
    return $chunk;
}

sub _get_filters {
    my $type = shift;
    my $string = shift || '';
    $string =~ s/\s*(.*?)\s*/$1/;
    my @filters = ();
    my $map_filters = $self->_filters_map->{$type} || [];
    $map_filters = [ $map_filters ] unless ref $map_filters;
    for my $filter (
        @{$self->_filters}, 
        @$map_filters,
        split(/\s+/, $string),
    ) {
        last unless length $filter;
        if ($filter =~ s/^-//) {
            @filters = grep { $_ ne $filter } @filters;
        }
        else {
            @filters = grep { $_ ne $filter } @filters;
            push @filters, $filter;
        }
    }
    return map { "filter_$_" } @filters;
}

sub spec_init {
    return $self->_spec_string
      if $self->_spec_string;
    local $/;
    my $spec;
    if (my $spec_file = $self->_spec_file) {
        open FILE, $spec_file or die $!;
        $spec = <FILE>;
        close FILE;
    }
    else {    
        $spec = do { 
            package main; 
            no warnings 'once';
            <DATA>;
        };
    }
    return $spec;
}

sub run(&) {
    my $self = $default_object;
    my $callback = shift;
    for my $chunk ($self->chunks) {
        &{$callback}($chunk);
    }
}

# XXX Dummy implementation for now.
sub diff_is() {
    require Algorithm::Diff;
    is($_[0], $_[1], (@_ > 1 ? ($_[2]) : ()));
}

# XXX Copied from Spiffy. Refactor at some point.
sub strict_warnings() {
    require Filter::Util::Call;
    my $done = 0;
    Filter::Util::Call::filter_add(
        sub {
            return 0 if $done;
            my ($data, $end) = ('', '');
            while (my $status = Filter::Util::Call::filter_read()) {
                return $status if $status < 0;
                if (/^__(?:END|DATA)__\r?$/) {
                    $end = $_;
                    last;
                }
                $data .= $_;
                $_ = '';
            }
            $_ = "use strict;use warnings;$data$end";
            $done = 1;
        }
    );
}

package Test::Chunk;
use Spiffy -base;

field 'description';

sub set_chunk {
    my ($type, $text) = @_;
    field $type
      unless $self->can($type);
    $self->$type($text);
}

__DATA__

=head1 NAME

Test::Chunks - Chunky Data Driven Testing Support

=head1 SYNOPSIS

    use Test::Chunks;
    use Pod::Simple;

    delimiters qw(=== +++);
    plan tests => 1 * chunks;
    
    for my $chunk (chunks) {
        # Note that this code is conceptual only. Pod::Simple is not so
        # simple as to provide a simple pod_to_html function.
        diff_is(
            Pod::Simple::pod_to_html($chunk->pod),
            $chunk->text,
            $chunk->description, 
        );
    }

    __END__

    === Header 1 Test
    +++ pod
    =head1 The Main Event
    +++ html
    <h1>The Main Event</h1>

    === List Test
    +++ pod
    =over
    =item * one
    =item * two
    =back

    +++ html
    <ul>
    <li>one</li>
    <li>two</li>
    </ul>

=head1 DESCRIPTION

There are many testing situations where you have a set of inputs and a
set of expected outputs and you want to make sure your process turns
each input chunk into the corresponding output chunk. Test::Chunks
allows you do this with a minimal amount of code.

Test::Chunks is optimized for input and output chunks that span multiple
lines of text.

=head1 EXPORTED FUNCTIONS

Test::Chunks extends Test::More and exports all of its functions. So you
can basically write your tests the same as Test::More. Test::Chunks
exports a few more functions though:

=head2 run(&subroutine)

The C<run> function takes a subroutine as an argument, and calls the sub one
time for each chunk in the specification. It passes the current chunk object
to the sub routine.

    run {
        my $chunk = shift;
        is(process($chunk->foo), $chunk->bar, $chunk->description);
    };

=head2 chunks()

The most important function is C<chunks>. In list context it returns a
list of C<Test::Chunk> objects that are generated from the test
specification in the C<DATA> section of your test file. In scalar
context it returns the number of objects. This is useful to calculate
your Test::More plan.

=head2 delimiters($chunk_delimiter, $data_delimiter)

Override the default delimiters of C<===> and C<--->.

=head2 spec_file($file_name)

By default, Test::Chunks reads its input from the DATA section. This
function tells it to get the spec from a file instead.

=head2 spec_string($test_data)

By default, Test::Chunks reads its input from the DATA section. This
function tells it to get the spec from a string that has been
prepared somehow.

=head2 filters(@filter_list)

Specify a list of additional filters to be applied to all chunks. See
C<FILTERS> below.

=head2 filters_map($hash_ref)

This function allows you to specify a hash that maps data section names
to an array ref of filters for that data type.

    filters_map({
        xxx => [qw(chomp lines)],
        yyy => ['yaml'],
        zzz => 'eval',
    });

If a filters list has only one element, the array ref is optional.

=head2 diff_is()

Like Test::More's C<is()>, but on failure reports a diff of the expected
and actual output. This is often very useful when your chunks are large.
Requires the Algorithm::Diff module.

=head2 default_object()

Returns the default Test::Chunks object. This is useful if you feel
the need to do an OO operation in otherwise functional test code. See
L<OO> below.

=head2 WWW() XXX() YYY() ZZZ()

These debugging functions are exported from the Spiffy.pm module. See
L<Spiffy> for more info.

=head1 TEST SPECIFICATION

Test::Chunks allows you to specify your test data in an external file,
the DATA section of your program or from a scalar variable containing
all the text input.

A I<test specification> is a series of text lines. Each test (or chunk)
is separated by a line containing the chunk delimiter and an optional
description. Each chunk is further subdivided into named sections with a
line containing the data delimiter and the data section name.

Here is an example:

    use Test::Chunks;
    
    delimiters qw(### :::);

    # test code here

    __END__
    
    ### Test One
    
    ::: foo
    a foo line
    another foo line

    ::: bar
    a bar line
    another bar line

    ### Test Two
    
    ::: foo
    some foo line
    some other foo line
    
    ::: bar
    some bar line
    some other bar line

    ::: baz
    some baz line
    some other baz line

This example specifies two chunks. They both have foo and bar data
sections. The second chunk has a baz component. The chunk delimiter is
C<###> and the data delimiter is C<:::>.

The default chunk delimiter is C<===> and the default data delimiter
is C<--->.

There are two special data section names.

    --- SKIP
    --- ONLY

A chunk with a SKIP section causes that test to be ignored. This is
useful to disable a test temporarily.

A chunk with an ONLY section causes only that chunk to be return. This
is useful when you are concentrating on getting a single test to pass.
If there is more than one chunk with ONLY, the first one will be chosen.

=head1 FILTERS

Test::Chunks allows you to specify a list of filters. The default
filters are C<norm> and C<trim>. These filters will be applied (in
order) to the data after it has been parsed from the specification and
before it is set into its Test::Chunk object.

You can specify the default filters with the C<filters> function. You
can specify additional filters to a specific chunk by listing them after
the section name on a data section delimiter line.

Example:

    use Test::Chunks;

    filters(norm foo bar);

    __END__
    === Test one
    --- foo trim chomp upper
    ...
    --- bar -norm
    ...

Putting a C<-> before a filter on a delimiter line, disables that
filter.

=head2 norm

Normalize the data. Change non-Unix line endings to Unix line endings.

=head2 chomp

Remove the final newline. The newline on the last line.

=head2 trim

Remove extra blank lines from the beginning and end of the data. This
allows you to visually separate your test data with blank lines.

=head2 lines

Break the data into an anonymous array of lines. Each line (except
possibly the last one if the C<chomp> filter came first) will have a
newline at the end.

=head2 list

Same as the C<lines> filter, except all newlines are chomped.

=head2 eval

Run Perl's C<eval> command against the data and use the returned value
as the data.

=head2 yaml

Apply the YAML::Load function to the data chunk and use the resultant
structure. Requires YAML.pm.

=head2 base64

Decode base64 data. Useful for binary tests.

=head2 esc

Unescape all backslash escaped chars.

=head2 Rolling Your Own Filters

Creating filter extensions is very simple. Here is a self
explanatory example:

    use Test::Chunks;

    filters(foo);

    sub Test::Chunks::filter_foo {
        my $self = shift;
        my $data = shift;
        # transform $data in a fooish manner
        return $data;
    }    

=head1 OO

Test::Chunks has a nice functional interface for simple usage. Under the
hood everything is object oriented. A default Test::Chunks object is
created and all the functions are really just method calls on it.

This means if you need to get fancy, you can use all the object
oriented stuff too. Just create new Test::Chunk objects and use the
functions as methods.

    use Test::Chunks;
    my $chunks1 = Test::Chunks->new;
    my $chunks2 = Test::Chunks->new;

    $chunks1->delimiters(qw(!!! @@@))->spec_file('test1.txt');
    $chunks2->delimiters(qw(### $$$))->spec_string($test_data);

    plan tests => $chunks1->chunks + $chunks2->chunks;

    # ... etc

=head1 OTHER COOL FEATURES

Test::Chunks automatically adds

    use strict;
    use warnings;

to all of your test scripts. A Spiffy feature indeed.

=head1 TODO

* diff_is() just calls is() for now. Need to implement.

=head1 AUTHOR

Brian Ingerson <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
