package MooseX::Role::Flyweight;
# ABSTRACT: Automatically memoize and reuse your Moose objects

=head1 SYNOPSIS

    package Glyph::Character;
    use Moose;
    with 'MooseX::Role::Flyweight';

    has 'c' => (is => 'ro', required => 1);

    sub draw {
        my ($self, $context) = @_;
        ...
    }

    package main;

    my $unshared_object = Glyph::Character->new(%args);

    my $shared_object = Glyph::Character->instance(%args);
    my $same_object   = Glyph::Character->instance(%args);
    my $diff_object   = Glyph::Character->instance(%diff_args);

=head1 DESCRIPTION

"A million tiny objects can weigh a ton."
Instead of creating a multitude of identical copies of objects, a flyweight
is a memoized instance that may be reused in multiple contexts simultaneously.

MooseX::Role::Flyweight is a Moose role that enables your Moose class
to automatically manage a cache of reusable instances.
In other words, the class becomes its own flyweight factory.

Because of the cost of constructing objects, reusing flyweights may have the
effect of improving speed.
However, this may be offset by the need to manage extrinsic state separately.

=head2 Flyweight v. Singleton

MooseX::Role::Flyweight provides an C<instance()> method which looks similar
to L<MooseX::Singleton>.
This is in part because MooseX::Role::Flyweight departs from the original
"Gang of Four" design pattern in that the role of the Flyweight Factory has
been merged into the Flyweight class itself. But the choice of the method
name was based on MooseX::Singleton.

While MooseX::Role::Flyweight and MooseX::Singleton look similar,
understanding their intentions will highlight their differences:

=begin :list

= Singleton

MooseX::Singleton limits the number of instances allowed for that class to ONE.
For this reason, its C<instance()> method does not accept
construction arguments and will always return the same instance.
If arguments are required for construction, then you will need to call its
C<initialize()> method.

= Flyweight

MooseX::Role::Flyweight is used to facilitate the reuse of objects to reduce
the cost of having many instances.
The number of instances created will be reduced,
but it does not set a limit on how many instances are allowed.
Its C<instance()> method does accept construction arguments
because it is responsible for managing the construction of
new instances when it finds that it cannot reuse an existing one.

=end :list

=head2 A note on usage

To use this module, you simply need to compose the role into your Moose class.
The consuming class may define its own attributes and methods as usual, but ...

B<WARNING!> Generally, your flyweight object attributes should be read-only.
It is dangerous to have mutable flyweight objects because it means you may get
something you don't expect when you retrieve it from the cache the next time.

    my $flight = Flight->instance(destination => 'Australia');
    $flight->set_destination('Antarctica');

    # ... later, in another context
    my $flight = Flight->instance(destination => 'Australia');
    die 'hypothermia' if $flight->destination eq 'Antarctica';

TIP: Instances are identified for reuse based on the equivalency of the named
parameters used for construction after they have passed through C<BUILDARGS>.
Whether these parameters are actually used for construction is not taken into
account. For this reason, you may want to use L<MooseX::StrictConstructor>
in your consuming class to disallow such unused parameters.

=cut

use JSON ();
use Moose::Role;
use MooseX::ClassAttribute;

my $json;

class_has '_instances' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { { } },
);

=method instance

    my $obj = MyClass->instance(%constructor_args);

This class method returns an instance that has been constructed
from the given arguments.
The first time it is called with a given set of arguments
it will construct the object and cache it.
On subsequent calls with the same set of arguments
it will reuse the existing object by retrieving it from the cache.

The arguments are those that are used by C<new()> to construct the object.
They are also used to identify the object in the cache.
They may be in any form that C<new()> will accept, which is normally
a hash or hash reference of named parameters.
Non-hash(ref) arguments are also possible if you have defined your own
C<BUILDARGS> class method to handle them (see L<Moose::Manual::Construction>).

Note that instances that are constructed by calling C<new()> directly
do not get cached and will never be returned by this method.

=cut

sub instance {
    my ($class, @args) = @_;

    my $key = $class->normalizer(@args);
    return $class->_instances->{$key} ||= $class->new(@args);
}

=method normalizer

    my $obj_key = MyClass->normalizer(%constructor_args);

This class method accepts the arguments used for construction
and returns a string representation of those arguments.
The string representation is used by C<instance()> as the key to identify
an object for storage and retrieval in the cache.
The hash keys in a hash(ref) argument will be sorted, which means that it will
always produce the same string for equivalent named parameters regardless of
their order.

You may override this method with your own implementation.
This can be used to customize the way construction arguments
are converted to a string to identify an unique instance.
It is also possible to use this to limit the instances that may be created
(i.e. to make it a singleton) by limiting its possible return values.

=cut

sub normalizer {
    my ($class, @args) = @_;

    $json ||= JSON->new->utf8->canonical;

    my $args = $class->BUILDARGS(@args);
    return $json->encode($args);
}

no Moose::Role;
1;
