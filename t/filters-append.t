use Test::Chunks tests => 1;

filters qw(chomp +bar foo);

is(next_chunk->text, "this,foo,that,bar");

sub foo { $_[0] . ",foo" } 
sub bar { $_[0] . ",bar" } 
sub that { $_[0] . ",that" } 

__DATA__
===
--- text that
this
