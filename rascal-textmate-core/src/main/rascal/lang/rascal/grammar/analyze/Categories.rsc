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
        for (old != new, /Symbol s := p.symbols, child <- lookup(g, delabel(s))) {
            doGet(child, new);
        }
    }

    // Propagate categories from the roots of the grammar
    for (root: prod(\start(_), _, _) <- ret) {
        doGet(root, {NO_CATEGORY});
    }

    return ret;
}