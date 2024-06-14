module lang::rascal::Util

import Exception;
import Grammar;
import Map;
import ParseTree;
import Relation;

bool tryParse(Grammar gr, Symbol s, str input) {
    return tryParse(gr.rules, s, input);
}

bool tryParse(map[Symbol, Production] rules, Symbol s, str input) {
    if (isNonTerminalType(s) && \parameterized-sort(_, _) !:= s && \parameterized-lex(_, _) !:= s) {
        if (value v := type(s, rules), type[Tree] t := v) {
            try { parse(t, input, allowAmbiguity=true); return true; }
            catch ParseError(_): return false;
        }
    }
    return false;
}

@synopsis{
    Utility functions for symbols
}

Symbol expand(\iter-seps(symbol, separators))
    = \seq([symbol, \iter-star(\seq(separators + symbol))]);
Symbol expand(\iter-star-seps(symbol, separators))
    = \opt(expand(\iter-seps(symbol, separators)));

Symbol delabel(label(_, Symbol s)) = s;
default Symbol delabel(Symbol s)   = s;

set[Symbol] defs(set[Production] productions)
    = {delabel(def) | \prod(def, _, _) <- productions};

set[Symbol] descendants(Grammar gr, set[Symbol] parents, bool withParents = false)
    = range(domainR(dependencies(gr), parents))
    + (withParents ? parents : {});

rel[Symbol, Symbol] dependencies(Grammar gr)
    = {<delabel(from), to> | \prod(from, [*_, /Symbol to, *_], _) <- prods(gr), isNonTerminalType(to)}+;

@synopsis{
    Utility functions for productions
}

set[Production] prods(Grammar gr, bool(Production) keep = bool(_) { return true; })
    = {p | /p: \prod(_, _, _) <- range(gr.rules), keep(p)};

&T subst(&T t, list[Symbol] from, list[Symbol] to)
    = subst(t, toMapUnique(zip2(from, to))) when size(from) == size(to);
&T subst(&T t, map[Symbol, Symbol] m)
    = visit (t) { case Symbol s => m[s] when s in m };