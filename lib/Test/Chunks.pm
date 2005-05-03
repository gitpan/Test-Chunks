package Test::Chunks;
use Spiffy 0.24 -Base;
use Spiffy ':XXX';
use Test::More;
use Carp;

our @EXPORT = qw(
    ok is isnt like unlike is_deeply cmp_ok
    skip todo_skip pass fail
    eq_array eq_hash eq_set
    plan can_ok isa_ok diag
    $TODO

    chunks delimiters spec_file spec_string filters filters_map 
    run run_is run_is_deeply run_like
    WWW XXX YYY ZZZ
);
#     diff_is

our $VERSION = '0.22';

sub import() {
    _strict_warnings();
    goto &Spiffy::import;
}

my $chunk_delim_default = '===';
my $data_delim_default = '---';

field chunk_class => 'Test::Chunk';
field filter_class => 'Test::Chunks::Filter';

field '_spec_file';
field '_spec_string';
field '_filters' => [qw(norm trim)];
field '_filters_map' => {};
field spec =>
      -init => '$self->_spec_init';
field chunks_list =>
      -init => '$self->_chunks_init';
field chunk_delim =>
      -init => '$self->_chunk_delim_default';
field data_delim =>
      -init => '$self->_data_delim_default';

sub _chunk_delim_default { $chunk_delim_default }
sub _data_delim_default { $data_delim_default }

my $default_object = __PACKAGE__->new;
sub default_object { $default_object }

sub check_late {
    if ($self->{chunks_list}) {
        my $caller = (caller(1))[3];
        $caller =~ s/.*:://;
        croak "Too late to call $caller()"
    }
}

sub chunks() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    my $chunks = $self->chunks_list;
    if (@_ == 0) {
        return @$chunks;
    }
    elsif (@_ == 1) {
        my $name = shift;
        my @chunks = grep {
            exists $_->{$name};
        } @$chunks;
        return @chunks;
    }
    else {
        croak "Invalid arguments passed to 'chunks'";
    }
}

sub delimiters() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    $self->check_late;
    my ($chunk_delimiter, $data_delimiter) = @_;
    $chunk_delimiter ||= $chunk_delim_default;
    $data_delimiter ||= $data_delim_default;
    $self->chunk_delim($chunk_delimiter);
    $self->data_delim($data_delimiter);
    return $self;
}

sub spec_file() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    $self->check_late;
    $self->_spec_file(shift);
    return $self;
}

sub spec_string() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    $self->check_late;
    $self->_spec_string(shift);
    return $self;
}

sub filters() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    $self->check_late;
    if (ref($_[0]) eq 'HASH') {
        $self->_filters_map(shift);
    }
    else {    
        my $filters = $self->_filters;
        push @$filters, @_;
    }
    return $self;
}

sub filters_map() {
    croak <<'...';
The 'filters_map' function has been deprecated. Use 'filters' instead.
...
}

sub run(&) {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    my $callback = shift;
    for my $chunk ($self->chunks) {
        &{$callback}($chunk);
    }
}

sub run_is() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    my ($x, $y) = @_;
    for my $chunk ($self->chunks) {
        next unless exists($chunk->{$x}) and exists($chunk->{$y});
        is($chunk->$x, $chunk->$y, 
           $chunk->description ? $chunk->description : ()
          );
    }
}

sub run_is_deeply() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    my ($x, $y) = @_;
    for my $chunk ($self->chunks) {
        next unless exists($chunk->{$x}) and exists($chunk->{$y});
        is_deeply($chunk->$x, $chunk->$y, 
           $chunk->description ? $chunk->description : ()
          );
    }
}

sub run_like() {
    my $self = ref($_[0]) eq __PACKAGE__
    ? shift
    : $default_object;
    my ($x, $y) = @_;
    for my $chunk ($self->chunks) {
        my $regexp = ref $y ? $y : $chunk->$y;
        next unless exists($chunk->{$x}) and defined($y);
        like($chunk->$x, $regexp,
             $chunk->description ? $chunk->description : ()
            );
    }
}

# XXX Dummy implementation for now.
# sub diff_is($$;$) {
#     require Algorithm::Diff;
#     is($_[0], $_[1], (@_ > 1 ? ($_[2]) : ()));
# }

sub _chunks_init {
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

sub _check_reserved {
    my $name = shift;
    croak "'$name' is a reserved name. Use something else.\n"
      if $name =~ /^(
         new |
         field |
         description
      )$/x or
      $name =~ /^_/;
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
        my ($type, $filters, @value) = splice(@parts, 0, 3);
        @value = ('') unless @value > 0;
        $self->_check_reserved($type);
        for my $filter ($self->_get_filters($type, $filters)) {
            $Test::Chunks::Filter::arguments =
              $filter =~ s/=(.*)$// ? $1 : undef;
            my $function = "main::$filter";
            no strict 'refs';
            if (defined &$function) {
                @value = &$function(@value);
            }
            elsif ($self->filter_class->can($filter)) {
                @value = $self->filter_class->$filter(@value);
            }
            else {
                die "Can't find a function or method for '$filter' filter\n";
            }
        }
        $chunk->_set_value($type, @value);
    }
    for (keys %$chunk) {
        $chunk->{$_} ||= '';
    }
    $chunk->_set_value(description => $description);
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
    return @filters;
}

sub _spec_init {
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

# XXX Copied from Spiffy. Refactor at some point.
sub _strict_warnings() {
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

sub new() {
    bless {}, shift;
}

sub _make_accessor() {
    my $name = shift;
    no strict 'refs';
    return if defined &$name;
    *$name = sub {
        my $self = shift;
        if (@_) {
            Carp::croak "Not allowed to set values for '$name'";
        }
        my @list = @{$self->{$name}};
        return wantarray
        ? (@list)
        : $list[0];
    };
}

_make_accessor 'description';

sub _set_value {
    my $name = shift;
    _make_accessor $name
      unless $self->can($name);
    $self->{$name} = [@_];
}

package Test::Chunks::Filter;

our $arguments;

sub _assert_scalar {
    return if @_ == 1;
    require Carp;
    my $filter = (caller(1))[3];
    $filter =~ s/.*:://;
    Carp::croak "Input to the '$filter' filter must be a scalar, not a list";
}

sub norm {
    $self->_assert_scalar(@_);
    my $text = shift || '';
    $text =~ s/\015\012/\n/g;
    $text =~ s/\r/\n/g;
    return $text;
}

sub chomp {
    map { CORE::chomp; $_ } @_;
}

sub trim {
    map {
        s/\A([ \t]*\n)+//;
        s/(?<=\n)\s*\z//g;
        $_;
    } @_;
}

sub base64 {
    $self->_assert_scalar(@_);
    require MIME::Base64;
    MIME::Base64::decode_base64(shift);
}

sub escape {
    $self->_assert_scalar(@_);
    my $text = shift;
    $text =~ s/(\\.)/eval "qq{$1}"/ge;
    return $text;
}

sub eval {
    $self->_assert_scalar(@_);
    my @return = CORE::eval(shift);
    return $@ if $@;
    return @return;
}

sub yaml {
    $self->_assert_scalar(@_);
    require YAML;
    return YAML::Load(shift);
}

sub lines {
    $self->_assert_scalar(@_);
    my $text = shift;
    return () unless length $text;
    my @lines = ($text =~ /^(.*\n?)/gm);
    return @lines;
}

sub array {
    [@_];
}

sub dumper {
    no warnings 'once';
    require Data::Dumper;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Terse = 1;
    Data::Dumper::Dumper(@_);
}

sub strict {
    $self->_assert_scalar(@_);
    <<'...' . shift;
use strict;
use warnings;
...
}

sub regexp {
    $self->_assert_scalar(@_);
    my $text = shift;
    my $flags = $Test::Chunks::Filter::arguments;
    if ($text =~ /\n.*?\n/s) {
        $flags = 'xism'
          unless defined $flags;
    }
    else {
        CORE::chomp($text);
    }
    $flags ||= '';
    my $regexp = eval "qr{$text}$flags";
    die $@ if $@;
    return $regexp;
}

sub get_url {
    $self->_assert_scalar(@_);
    my $url = shift;
    CORE::chomp($url);
    require LWP::Simple;
    LWP::Simple::get($url);
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
        is(
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

=head2 chunks( [data-section-name] )

The most important function is C<chunks>. In list context it returns a
list of C<Test::Chunk> objects that are generated from the test
specification in the C<DATA> section of your test file. In scalar
context it returns the number of objects. This is useful to calculate
your Test::More plan.

Each Test::Chunk object has methods that correspond to the names of that
object's data sections. There is also a C<description> method for
accessing the description text of the object.

C<chunks> can take an optional single argument, that indicates to only
return the chunks that contain a particular named data section.
Otherwise C<chunks> returns all chunks.

    my @all_of_my_chunks = chunks;

    my @just_the_foo_chunks = chunks('foo');

=head2 run(&subroutine)

There are many ways to write your tests. You can reference each chunk
individually or you can loop over all the chunks and perform a common
operation. The C<run> function does the looping for you, so all you need
to do is pass it a code block to execute for each chunk.

The C<run> function takes a subroutine as an argument, and calls the sub
one time for each chunk in the specification. It passes the current
chunk object to the subroutine.

    run {
        my $chunk = shift;
        is(process($chunk->foo), $chunk->bar, $chunk->description);
    };

=head2 run_is(data_name1, data_name2)

Many times you simply want to see if two data sections are equivalent in
every chunk, probably after having been run through one or more filters.
With the C<run_is> function, you can just pass the names of any two data
sections that exist in every chunk, and it will loop over every chunk
comparing the two sections.

    run_is 'foo', 'bar';

NOTE: Test::Chunks will silently ignore any chunks that  don't contain both
sections.

=head2 run_is_deeply(data_name1, data_name2)

Like C<run_is> but uses C<is_deeply> for complex data structure comparison.

=head2 run_like(data_name, regexp | data_name);

The C<run_like> function is similar to C<run_is> except the second
argument is a regular expression. The regexp can either be a C<qr{}>
object or a data section that has been filtered into a regular
expression.

    run_like 'foo', qr{<html.*};
    run_like 'foo', 'match';

=head2 delimiters($chunk_delimiter, $data_delimiter)

Override the default delimiters of C<===> and C<--->.

=head2 spec_file($file_name)

By default, Test::Chunks reads its input from the DATA section. This
function tells it to get the spec from a file instead.

=head2 spec_string($test_data)

By default, Test::Chunks reads its input from the DATA section. This
function tells it to get the spec from a string that has been
prepared somehow.

=head2 filters( @filters_list or $filters_hashref )

Specify a list of additional filters to be applied to all chunks. See
C<FILTERS> below.

You can also specify a hash ref that maps data section names to an array
ref of filters for that data type.

    filters {
        xxx => [qw(chomp lines)],
        yyy => ['yaml'],
        zzz => 'eval',
    };

If a filters list has only one element, the array ref is optional.

=cut

# =head2 diff_is()
# 
# Like Test::More's C<is()>, but on failure reports a diff of the expected
# and actual output. This is often very useful when your chunks are large.
# Requires the Algorithm::Diff module.

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
C<description>. Each chunk is further subdivided into named sections
with a line containing the data delimiter and the data section name.

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

The real power in writing tests with Test::Chunks comes from its
filtering capabilities. Test::Chunks comes with an ever growing set
of useful generic filters than you can sequence and apply to various
test chunks. That means you can specify the chunk serialization in
the most readable format you can find, and let the filters translate
it into what you really need for a test. It is easy to write your own
filters as well.

Test::Chunks allows you to specify a list of filters. The default
filters are C<norm> and C<trim>. These filters will be applied (in
order) to the data after it has been parsed from the specification and
before it is set into its Test::Chunk object.

You can add to the the default filter list with the C<filters> function.
You can specify additional filters to a specific chunk by listing them
after the section name on a data section delimiter line.

Example:

    use Test::Chunks;

    filters qw(foo bar);
    filters { perl => 'strict' };

    sub upper { uc(shift) }

    __END__

    === Test one
    --- foo trim chomp upper
    ...

    --- bar -norm
    ...

    --- perl eval dumper
    my @foo = map {
        - $_;
    } 1..10;
    \ @foo;

Putting a C<-> before a filter on a delimiter line, disables that
filter.

=head2 Scalar vs List

Each filter can take either a scalar or a list as input, and will return
either a scalar or a list. Since filters are chained together, it is
important to learn which filters expect which kind of input and return
which kind of output.

For example, consider the following filter list:

    norm trim lines chomp array dumper eval

The data always starts out as a single scalar string. C<norm> takes a
scalar and returns a scalar. C<trim> takes a list and returns a list,
but a scalar is a valid list. C<lines> takes a scalar and returns a
list. C<chomp> takes a list and returns a list. C<array> takes a list
and returns a scalar (an anonymous array reference containing the list
elements). C<dumper> takes a list and returns a scalar. C<eval> takes a
scalar and creates a list.

A list of exactly one element works fine as input to a filter requiring
a scalar, but any other list will cause an exception. A scalar in list
context is considered a list of one element.

Data accessor methods for chunks will return a list of values when used
in list context, and the first element of the list in scalar context.
This usually does the right thing, but be aware.

=head2 norm

scalar => scalar

Normalize the data. Change non-Unix line endings to Unix line endings.

=head2 chomp

list => list

Remove the final newline from each string value in a list.

=head2 trim

list => list

Remove extra blank lines from the beginning and end of the data. This
allows you to visually separate your test data with blank lines.

=head2 lines

scalar => list

Break the data into an anonymous array of lines. Each line (except
possibly the last one if the C<chomp> filter came first) will have a
newline at the end.

=head2 array

list => scalar

Turn a list of values into an anonymous array reference.

=head2 eval

scalar => list

Run Perl's C<eval> command against the data and use the returned value
as the data.

=head2 regexp[=xism]

scalar => scalar

The C<regexp> filter will turn your data section into a regular
expression object. You can pass in extra flags after an equals sign.

If the text contains more than one line and no flags are specified, then
the 'xism' flags are assumed.

=head2 get_url

scalar => scalar

The text is chomped and considered to be a url. Then LWP::Simple::get is
used to fetch the contents of the url.

=head2 yaml

scalar => list

Apply the YAML::Load function to the data chunk and use the resultant
structure. Requires YAML.pm.

=head2 dumper

scalar => list

Take a data structure (presumably from another filter like eval) and use
Data::Dumper to dump it in a canonical fashion.

=head2 strict

scalar => scalar

Prepend the string:

    use strict; 
    use warnings;

to the chunk's text.

=head2 base64

scalar => scalar

Decode base64 data. Useful for binary tests.

=head2 escape

scalar => scalar

Unescape all backslash escaped chars.

=head2 Rolling Your Own Filters

Creating filter extensions is very simple. You can either write a
I<function> in the C<main> namespace, or a I<method> in the
C<Test::Chunks::Filter> namespace. In either case the text and any
extra arguments are passed in and you return whatever you want the new
value to be.

Here is a self explanatory example:

    use Test::Chunks;

    filters 'foo', 'bar=xyz';

    sub foo {
        transform(shift);
    }
        
    sub Test::Chunks::Filter::bar {
        my $class = shift;
        my $data = shift;
        my $args = shift;
        # transform $data in a barish manner
        return $data;
    }    

Normally you'll probably just use the functional interface, although all
the builtin filters are methods.

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

=head1 AUTHOR

Brian Ingerson <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
