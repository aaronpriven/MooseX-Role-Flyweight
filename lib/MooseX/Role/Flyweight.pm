package MooseX::Role::Flyweight;
# ABSTRACT: Automatically memoize your Moose objects for reuse

=head1 SYNOPSIS

Compose MooseX::Role::Flyweight into your Moose class.

    package Glyph::Character;
    use Moose;
    with 'MooseX::Role::Flyweight';

    has 'c' => (is => 'ro', required => 1);

    sub draw {
        my ($self, $context) = @_;
        ...
    }

    # Optional: override normalizer()
    sub normalizer {
        my ($class, $init_args) = @_;
        return $init_args->{c};
    }

Get cached object instances by calling C<instance()> instead of C<new()>.

    # the same initialisation arguments produces the same object
    $shared_object   = Glyph::Character->instance( %init_args );
    $same_object     = Glyph::Character->instance( %init_args );

    # different initialisation arguments produces a different object
    $another_object  = Glyph::Character->instance( %diff_args );

    # new() still works but its objects are not shared
    $unshared_object = Glyph::Character->new( %init_args );

=head1 DESCRIPTION

"A million tiny objects can weigh a ton." Instead of creating a multitude of
identical copies of objects, a flyweight is a memoized instance that may be
reused in multiple contexts simultaneously to minimize memory usage. And due
to the cost of constructing objects the reuse of flyweights has the potential
to speed up your code.

MooseX::Role::Flyweight is a Moose role that enables your Moose class to
automatically manage a cache of reusable instances. In other words, the class
becomes its own flyweight factory.

=head2 Flyweight v. Singleton

MooseX::Role::Flyweight provides an C<instance()> method which looks similar
to L<MooseX::Singleton>. This is in part because MooseX::Role::Flyweight
departs from the original "Gang of Four" design pattern in that the role of
the Flyweight Factory has been merged into the Flyweight class itself. But the
choice of the method name was based on MooseX::Singleton.

While MooseX::Role::Flyweight and MooseX::Singleton look similar, understanding
their intentions will highlight their differences:

=begin :list

= Singleton

MooseX::Singleton limits the number of instances allowed for that class to
ONE. For this reason, its C<instance()> method does not accept construction
arguments and will always return the same instance. If arguments are required
for construction, then you will need to call its C<initialize()> method.

= Flyweight

MooseX::Role::Flyweight is used to facilitate the reuse of objects to reduce
the cost of having many instances. The number of instances created will be
reduced, but it does not set a limit on how many instances are allowed. Its
C<instance()> method does accept construction arguments because it is
responsible for managing the construction of new instances when it finds
that it cannot reuse an existing one.

=end :list

=cut

use 5.006;
use JSON 2.00 (); # works with JSON::XS
use Moose::Role;
use MooseX::ClassAttribute 0.27;
use namespace::autoclean;
use Scalar::Util ();

my $json = JSON->new->utf8->canonical;

class_has '_instances' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { { } },
);

=method instance

    $instance = My::Class->instance( %init_args );

This class method returns an instance that has been constructed from the given
arguments. The first time it is called with a given set of arguments it will
construct the object and cache it. On subsequent calls with the equivalent set
of arguments it will reuse the existing object by retrieving it from the cache.

The arguments may be in any form that C<new()> will accept. This is normally a
hash or hash reference of named parameters. Non-hash(ref) arguments are also
possible if you have defined your own C<BUILDARGS> class method to handle them
(see L<Moose::Manual::Construction>).

Note that instances that are constructed by calling C<new()> directly do not
get cached and therefore will never be returned by this method.

=cut

sub instance {
    my ($class, @args) = @_;
    my $args = $class->BUILDARGS(@args);
    my $key  = $class->normalizer($args);

    # return the existing instance
    return $class->_instances->{$key} if defined $class->_instances->{$key};

    # create a new instance
    my $instance = $class->new(@args);
    $class->_instances->{$key} = $instance;
    Scalar::Util::weaken $class->_instances->{$key};

    return $instance;
}

=method normalizer

    $instance_identifier_string = My::Class->normalizer( $init_args_hashref );

This class method generates the keys used by C<instance()> to identify objects
for storage and retrieval in the cache. It is passed the arguments used for
construction as a hashref (after they have passed through C<BUILDARGS>). It
returns a string representation of those arguments as the key. Equivalent
arguments will result in the same string.

Note that this does not handle blessed references as arguments.

Generally you should not need to access this method directly. The only reason
you would want to know about this method is if you want to change the way it
generates the cache keys, in which case you should wrap or override this
method in your class that consumes this role.

=cut

sub normalizer {
    my ($class, $args) = @_;
    return $json->encode($args);
}

1;

=head1 NOTES ON USAGE

=head2 Flyweights should be immutable

Your flyweight object attributes should be read-only. It is dangerous to have
mutable flyweight objects because it means you may get something you don't
expect when you retrieve it from the cache the next time.

    my $flight = Flight->instance( destination => 'Australia' );
    $flight->set_destination('Antarctica');

    # ... later, in another context
    my $flight = Flight->instance( destination => 'Australia' );
    die 'hypothermia'  if $flight->destination eq 'Antarctica';

Value objects are the type of objects that are suited as flyweights.

=head2 Argument normalization

Instances are identified for reuse based on the equivalency of the named
parameters used for construction as interpreted by C<normalizer()>.

Factors to consider when determining equivalency:

=begin :list

* There is no distinction between hash and hashref (and non-hash) arguments.

    # same object is returned
    $obj1 = My::Flyweight->instance( attr => 'value' );
    $obj2 = My::Flyweight->instance({attr => 'value'});

* The order of named parameters does not affect equivalency.

The keys in the hash(ref) are sorted, which means that the same string will
always be produced for the same named parameters regardless of the order
they are given.

    # same object is returned
    $obj1 = My::Flyweight->instance( attr1 => 1, attr2 => 2 );
    $obj2 = My::Flyweight->instance( attr2 => 2, attr1 => 1 );

=end :list

On the other hand, C<normalizer()> does not handle:

=begin :list

* Unused construction parameters.

You can use L<MooseX::StrictConstructor> to prevent this.

    # different objects with same values returned
    $obj1 = My::Flyweight->instance( attr => 'value' );
    $obj2 = My::Flyweight->instance( attr => 'value', unused_attr => 'value' );

* Default attribute values.

You can extend/override C<normalizer()> to handle this if you wish.

    # different objects with same values returned
    $obj1 = My::Flyweight->instance( attr1 => 'value' );
    $obj2 = My::Flyweight->instance( attr1 => 'value', attr2 => 'default' );

=end :list

=head2 Garbage collection of cached objects

The cache uses weak references to the objects so that the cache references
do not prevent the objects from being garbage collected. This means that an
object in the cache will be destroyed when all other references to it go out
of scope.

    my $obj = My::Flyweight->instance(%args);
    # $obj is in the cache
    undef $obj;
    # $obj is garbage collected and disappears from the cache

=head1 ACKNOWLEDGEMENTS

Thanks to Mark Stosberg (MARKSTOS) for suggesting to explain the difference
between MooseX::Role::Flyweight and MooseX::Singleton.

=head1 SEE ALSO

L<Perl Design Patterns|http://www.perl.com/pub/2003/06/13/design1.html>

L<Memoize>

=cut
