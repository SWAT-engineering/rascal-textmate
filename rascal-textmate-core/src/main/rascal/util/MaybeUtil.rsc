@license{
BSD 2-Clause License

Copyright (c) 2024, Swat.engineering

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}
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
    Returns just the union of the sets of two `Maybe` values when both are
    present. Returns nothing if at least one is absent.
}

Maybe[set[&T]] union(just(set[&T] set1), just(set[&T] set2))
    = just(set1 + set2);

default Maybe[set[&T]] union(Maybe[set[&T]] _, Maybe[set[&T]] _)
    = nothing();