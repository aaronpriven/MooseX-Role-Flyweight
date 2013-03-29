#!/usr/bin/perl -T
use strict;
use warnings;
use Test::More tests => 4;
use lib 't/lib';

use_ok 'MooseX::Role::Flyweight';
use_ok 'Flyweight::Test3';

subtest 'normalize equivalent' => sub {
    is(
        Flyweight::Test3->normalizer(id => 123),
        Flyweight::Test3->normalizer({id => 135}),
    );
    is(
        Flyweight::Test3->instance(id => 123),
        Flyweight::Test3->instance({id => 135}),
    );
    is( Flyweight::Test3->instance(id => 135)->id, 123 );
};

subtest 'normalize non-equivalent' => sub {
    isnt(
        Flyweight::Test3->normalizer(id => 123),
        Flyweight::Test3->normalizer({id => 124}),
    );
    isnt(
        Flyweight::Test3->instance(id => 123),
        Flyweight::Test3->instance({id => 124}),
    );
    is( Flyweight::Test3->instance(id => 124)->id, 124 );
};
