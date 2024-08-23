@synopsis{
    Utility functions for `Maybe` values
}

module util::MaybeUtil

import util::Maybe;

@synopsis{
    Returns the set of a `Maybe` value when present. Returns the empty set when
    absent.
}

set[&T] unmaybe(Maybe[set[&T]] _: nothing())
    = {};
set[&T] unmaybe(Maybe[set[&T]] _: just(set[&T] \set))
    = \set;

@synopsis{
    Returns just the union of the sets of two `Maybe` values when present.
    Returns nothing if absent.
}

Maybe[set[&T]] union(just(set[&T] set1), just(set[&T] set2))
    = just(set1 + set2);

default Maybe[set[&T]] union(Maybe[set[&T]] _, Maybe[set[&T]] _)
    = nothing();