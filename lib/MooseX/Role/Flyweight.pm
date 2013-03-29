package MooseX::Role::Flyweight;
# ABSTRACT: Automatically memoize and reuse your Moose objects

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    with 'MooseX::Role::Flyweight';

    package main;

    my $unshared_object = MyClass->new(%args);
    my $shared_object   = MyClass->instance(%args);
    my $same_object     = MyClass->instance(%args);

=head1 DESCRIPTION

A million tiny objects can weigh a ton. They can also be expensive to construct.
Instead of creating a multitude of identical copies of objects, a flyweight
is a memoized instance that may be reused in multiple contexts simultaneously.

C<MooseX::Role::Flyweight> enables your L<Moose> class to automatically manage
a cache of reusable instances.
In other words, the class becomes its own flyweight factory.

B<WARNING!> Your flyweight objects should be immutable. It is dangerous to
have flyweight objects that can change state because it means you may get
something you don't expect when you retrieve it from the cache the next time.

    my $flight = Flight->instance(destination => 'Australia');
    $flight->set_destination('Antarctica');

    # later, in another context
    my $flight = Flight->instance(destination => 'Australia');
    die 'How did I end up in Antarctica?'
        if $flight->destination ne 'Australia';

=cut

use JSON ();
use Moose::Role;

my %objectpool;
my $json;

=method instance

    my $obj = MyClass->instance(%constructor_args);

This class method retrieves the object from the cache for reuse,
or constructs the object and stores it in the cache if it is not there already.
The given arguments are those that are used by C<new()> to construct the object.
They are also used to identify the object in the cache.

The arguments may be in any form that C<new()> will accept.
This is normally a hash or hash reference of named parameters.
Non-hash(ref) arguments are also possible if you have defined your own
C<BUILDARGS> class method to handle them (see L<Moose::Manual::Construction>).

Note that this method will never return any object that has been constructed
by directly calling C<new()>.

=cut

sub instance {
    my ($class, @args) = @_;

    my $key = $class->normalizer(@args);
    return $objectpool{$key} ||= $class->new(@args);
}

=method normalizer

    my $obj_key = MyClass->normalizer(%constructor_args);

A class method that returns a string representation of the given arguments.
This string representation is used by C<instance> as the key to identify
an object for storage and retrieval in the cache.
Equivalent named parameters in a hash(ref) argument will always produce the
same string because the hash keys will be sorted.

You may override this method with your own implementation.

=cut

sub normalizer {
    my ($class, @args) = @_;

    $json ||= JSON->new->utf8->canonical->convert_blessed;

    my $args = $class->BUILDARGS(@args);
    return $json->encode($args);
}

no Moose::Role;
1;
