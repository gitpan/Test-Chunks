use inc::Module::Install;

name('Test-Chunks');
author('Brian Ingerson <ingy@cpan.org>');
abstract('Chunky Data Driven Testing Support');
license('perl');
version_from('lib/Test/Chunks.pm');

requires(qw(
    perl 5.6.1
    Spiffy 0.23
));

check_nmake();

&WriteAll();
