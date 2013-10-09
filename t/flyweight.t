#!/usr/bin/perl -T

use strict;
use warnings;

use Test::More tests => 16;
use Test::Fatal;

use lib 't/lib';

BEGIN {
    use_ok 'MooseX::Role::Flyweight';
    use_ok 'Flyweight::Test1';
    use_ok 'Flyweight::Test2';
}

isa_ok(
    Flyweight::Test1->instance,
    'Flyweight::Test1',
    'handles no args'
);
isa_ok(
    Flyweight::Test1->instance(id => 123, value => 'simple'),
    'Flyweight::Test1',
    'handles simple args'
);
is(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test1->instance({id => 123}),
    'hash and hashref args are handled the same'
);
is(
    Flyweight::Test1->instance(id => 123, value => 'hello'),
    Flyweight::Test1->instance(value => 'hello', id => 123),
    'arg order makes no difference'
);
is(
    Flyweight::Test2->instance(id => 123),
    Flyweight::Test2->instance(123),
    'handles non-hash arg via BUILDARGS'
);

is(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test1->instance(id => 123),
    'same args returns same instance'
);
isnt(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test1->instance(id => 123, value => ''),
    'different (equivalent) args returns different instance'
);

like(
    exception { Flyweight::Test1->instance(id => 'abc') },
    qr/\(id\) does not pass the type constraint/,
    'does not interfere with construction exceptions'
);

is_deeply(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test1->new(id => 123),
    'instance() and new() return equivalent instances'
);
isnt(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test1->new(id => 123),
    'instance() and new() equivalent instances are different'
);

isnt(
    Flyweight::Test1->instance(id => 123),
    Flyweight::Test2->instance(id => 123),
    'class caches are independent of each other'
);

subtest 'cached references are weak' => sub {
    my $args = { id => 123 };
    my $key  = Flyweight::Test1->normalizer($args);

    my $obj = Flyweight::Test1->instance($args);
    ok defined Flyweight::Test1->_instances->{$key}, 'cached ref exists';

    undef $obj;
    ok ! defined Flyweight::Test1->_instances->{$key}, 'cached ref discarded';
};

subtest 'backwards compatibility' => sub {
    is(
        Flyweight::Test1->normalizer(id => 123),
        Flyweight::Test1->normalizer({id => 123}),
        'normalizer() accepts hashes'
    );

    is(
        Flyweight::Test1->normalizer(123),
        Flyweight::Test1->normalizer({id => 123}),
        'normalizer() accepts a scalar'
    );
};
