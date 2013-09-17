# NAME

MooseX::Role::Flyweight - Automatically memoize your Moose objects for reuse

# VERSION

version 1.00

# SYNOPSIS

Compose MooseX::Role::Flyweight into your Moose class.

    package Glyph::Character;
    use Moose;
    with 'MooseX::Role::Flyweight';

    has 'c' => (is => 'ro', required => 1);

    sub draw {
        my ($self, $context) = @_;
        ...
    }

Get cached object instances by calling `instance()` instead of `new()`.

    my $shared_object = Glyph::Character->instance(%args);
    my $same_object   = Glyph::Character->instance(%args);
    my $diff_object   = Glyph::Character->instance(%diff_args);

    my $unshared_object = Glyph::Character->new(%args);

# DESCRIPTION

"A million tiny objects can weigh a ton." Instead of creating a multitude of
identical copies of objects, a flyweight is a memoized instance that may be
reused in multiple contexts simultaneously to minimize memory usage. And due
to the cost of constructing objects the reuse of flyweights has the potential
to speed up your code.

MooseX::Role::Flyweight is a Moose role that enables your Moose class to
automatically manage a cache of reusable instances. In other words, the class
becomes its own flyweight factory.

## Flyweight v. Singleton

MooseX::Role::Flyweight provides an `instance()` method which looks similar
to [MooseX::Singleton](https://metacpan.org/module/MooseX::Singleton). This is in part because MooseX::Role::Flyweight
departs from the original "Gang of Four" design pattern in that the role of
the Flyweight Factory has been merged into the Flyweight class itself. But the
choice of the method name was based on MooseX::Singleton.

While MooseX::Role::Flyweight and MooseX::Singleton look similar, understanding
their intentions will highlight their differences:

- Singleton

    MooseX::Singleton limits the number of instances allowed for that class to
    ONE. For this reason, its `instance()` method does not accept construction
    arguments and will always return the same instance. If arguments are required
    for construction, then you will need to call its `initialize()` method.

- Flyweight

    MooseX::Role::Flyweight is used to facilitate the reuse of objects to reduce
    the cost of having many instances. The number of instances created will be
    reduced, but it does not set a limit on how many instances are allowed. Its
    `instance()` method does accept construction arguments because it is
    responsible for managing the construction of new instances when it finds
    that it cannot reuse an existing one.

# METHODS

## instance

    my $obj = MyClass->instance(%constructor_args);

This class method returns an instance that has been constructed from the given
arguments. The first time it is called with a given set of arguments it will
construct the object and cache it. On subsequent calls with the equivalent set
of arguments it will reuse the existing object by retrieving it from the cache.

The arguments may be in any form that `new()` will accept. This is normally a
hash or hash reference of named parameters. Non-hash(ref) arguments are also
possible if you have defined your own `BUILDARGS` class method to handle them
(see [Moose::Manual::Construction](https://metacpan.org/module/Moose::Manual::Construction)).

Note that instances that are constructed by calling `new()` directly do not
get cached and therefore will never be returned by this method.

## normalizer

    my $obj_key = MyClass->normalizer(%constructor_args);

This class method generates the keys used by `instance()` to identify objects
for storage and retrieval in the cache. Generally you should not need to
access this method directly unless you want to modify the way it generates the
cache keys.

It accepts the arguments used for construction and returns a string
representation of those arguments as the key. Equivalent arguments will result
in the same string.

It does not handle blessed references as arguments.

# NOTES ON USAGE

## Flyweights should be immutable

Your flyweight object attributes should be read-only. It is dangerous to have
mutable flyweight objects because it means you may get something you don't
expect when you retrieve it from the cache the next time.

    my $flight = Flight->instance(destination => 'Australia');
    $flight->set_destination('Antarctica');

    # ... later, in another context
    my $flight = Flight->instance(destination => 'Australia');
    die 'hypothermia' if $flight->destination eq 'Antarctica';

Value objects are the type of objects that are suited as flyweights.

## Argument normalization

Instances are identified for reuse based on the equivalency of the named
parameters used for construction as interpreted by `normalizer()`.

Factors to consider when determining equivalency:

- There is no distinction between hash and hashref (and non-hash) arguments.

        # same object is returned
        $obj1 = My::Flyweight->instance( attr => 'value' );
        $obj2 = My::Flyweight->instance({attr => 'value'});
- The order of named parameters does not affect equivalency.

    The keys in the hash(ref) are sorted, which means that the same string will
    always be produced for the same named parameters regardless of the order
    they are given.

        # same object is returned
        $obj1 = My::Flyweight->instance( attr1 => 1, attr2 => 2 );
        $obj2 = My::Flyweight->instance( attr2 => 2, attr1 => 1 );

On the other hand, `normalizer()` does not handle:

- Unused construction parameters.

    You can use [MooseX::StrictConstructor](https://metacpan.org/module/MooseX::StrictConstructor) to prevent this.

        # different objects with same values returned
        $obj1 = My::Flyweight->instance( attr => 'value' );
        $obj2 = My::Flyweight->instance( attr => 'value', unused_attr => 'value' );

- Default attribute values.

    You can extend/override `normalizer()` to handle this if you wish.

        # different objects with same values returned
        $obj1 = My::Flyweight->instance( attr1 => 'value' );
        $obj2 = My::Flyweight->instance( attr1 => 'value', attr2 => 'default' );

## Garbage collection of cached objects

The cache uses weak references to the objects so that the cache references
do not prevent the objects from being garbage collected. This means that an
object in the cache will be destroyed when all other references to it go out
of scope.

    my $obj = My::Flyweight->instance(%args);
    # $obj is in the cache
    undef $obj;
    # $obj is garbage collected and disappears from the cache

# AUTHOR

Steven Lee <stevenwh.lee@gmail.com>

# ACKNOWLEDGEMENTS

Mark Stosberg (MARKSTOS) for suggesting to explain the difference to Singleton.

# SEE ALSO

[Perl Design Patterns](http://www.perl.com/pub/2003/06/13/design1.html)

[Memoize](https://metacpan.org/module/Memoize)

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Steven Lee.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
