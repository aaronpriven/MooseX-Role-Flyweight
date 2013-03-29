package Flyweight::Test1;
use Moose;

with 'MooseX::Role::Flyweight';

has id => ( is => 'ro', isa => 'Int', default => 0 );
has value => ( is => 'ro', isa => 'Str', default => '' );

__PACKAGE__->meta->make_immutable;
1;
