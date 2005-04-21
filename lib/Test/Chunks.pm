package Test::Chunks;
use Spiffy 0.23 -Base;
use Spiffy -XXX;
use Test::More;

our @EXPORT = qw(
    plan is ok like is_deeply fail 
    chunks diff_is
    WWW XXX YYY ZZZ
);

our $VERSION = '0.10';

my $chunk_delim_default = '===';
my $data_delim_default = '---';

const chunk_class => 'Test::Chunk';

field 'spec_file';
field 'spec_string';
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

sub paired_arguments { '-delims' }

# sub import {
#     super;
#     my ($args) = $self->parse_arguments(@_);
#     if (my $delims = $args->{'-delims'}) {
#         $delims = [$delims, '---'] unless ref $delims;
#         ($chunk_delim_default, $data_delim_default) = @$delims;
#     }
# }

sub chunks {
    $self ||= $default_object;
    my $chunks = $self->chunks_list;
    return @$chunks;
}

sub chunks_init {
    my $spec = $self->spec;
    my $cd = $self->chunk_delim;
    my $dd = $self->data_delim;
    my @hunks = ($spec =~ /^(${cd}.*?(?=^${cd}|\z))/msg);
    my @chunks;
    for my $hunk (@hunks) {
        my $chunk = $self->chunk_class->new;
        $hunk =~ s/\A${cd}[ \t]*(.*)\s+// or die;
        my $description = $1 || 'No test description';
        my @parts = split /^${dd}\s+(\w+)\s+/m, $hunk;
        shift @parts;
        while (@parts) {
            my ($type, $text) = splice(@parts, 0, 2);
            $chunk->set_chunk($type, $text);
        }
        for (keys %$chunk) {
            $chunk->{$_} ||= '';
        }
        $chunk->description($description);
        return [$chunk]
          if defined $chunk->{ONLY};
        next if defined $chunk->{SKIP};
        push @chunks, $chunk;
    }
    return [@chunks];
}

sub spec_init {
    return $self->spec_string
      if $self->spec_string;
    local $/;
    my $spec;
    if (my $spec_file = $self->spec_file) {
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

# XXX Dummy implementation for now.
sub diff_is() {
    require Algorithm::Diff;
    is($_[0], $_[1], (@_ > 1 ? ($_[2]) : ()));
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

    use Test::Chunks -delims => qw(=== +++);
    use Pod::Simple;

    plan tests => 1 * chunks;
    
    for my $chunk (chunks) {
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
    +++ 
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

=head2 chunks()

The most important function is C<chunks>. In list context it returns a
list of C<Test::Chunk> objects that are generated from the test
specification in the C<DATA> section of your test file. In scalar
context it returns the number of objects. This is useful to calculate
your Test::More plan.

=head2 diff_is()

Like Test::More's C<is()>, but on failure reports a diff of the expected
and actual output. This is often very useful when your chunks are large.

=head1 TEST SPECIFICATION

Test::Chunks allows you to specify your test data in an external file, the
DATA section of your program or from a scalar variable containing all the text
input.

=head1 AUTHOR

Brian Ingerson <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005. Brian Ingerson. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
