package Flyweight::Test3;
use Moose;

with 'MooseX::Role::Flyweight';

has 'id' => ( is => 'ro', isa => 'Int', required => 1 );

# normalizer returns (id % 2)
sub normalizer {
    my $class = shift;
    my $args  = $class->BUILDARGS(@_);
    return $args->{id} % 2;
}

__PACKAGE__->meta->make_immutable;
1;
