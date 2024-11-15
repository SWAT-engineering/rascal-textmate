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
module lang::rascal::grammar::analyze::Categories

import Grammar;
import ParseTree;

import lang::rascal::grammar::Util;

@synopsis{
    Special value to indicate that a production has no category
}

public str NO_CATEGORY = "";

@synopsis{
    Gets a set of categories such that, for each category, there exists a string
    with that category produced by production `p`, as part of a string produced
    by a start production of grammar `g`
}

set[str] getCategories(Grammar g, Production p)
    = getCategoriesByProduction(g)[p];

@memo
private map[Production, set[str]] getCategoriesByProduction(Grammar g) {
    map[Production, set[str]] ret = (p: {} | /p: prod(_, _, _) := g);

    void doGet(Production p, set[str] parentCategories) {
        set[str] categories = {c | /\tag("category"(str c)) := p};

        set[str] old = ret[p];
        set[str] new = _ <- categories ? categories : old + parentCategories;
        ret[p] = new;

        // If the new categories of `p` are different from the old ones, then
        // propagate these changes to the children of `p`
        for (old != new, /Symbol s := p.symbols, child <- prodsOf(g, delabel(s))) {
            doGet(child, new);
        }
    }

    // Propagate categories from the roots of the grammar
    for (root: prod(\start(_), _, _) <- ret) {
        doGet(root, {NO_CATEGORY});
    }

    return ret;
}