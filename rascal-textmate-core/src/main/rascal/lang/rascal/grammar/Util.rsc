module lang::rascal::grammar::Util

import Exception;
import Grammar;
import ParseTree;
import String;

@synopsis{
    Utility functions for grammars
}

bool tryParse(Grammar g, Symbol s, str input) {
    if (isNonTerminalType(s) && \parameterized-sort(_, _) !:= s && \parameterized-lex(_, _) !:= s) {
        if (value v := type(s, g.rules), type[Tree] t := v) {
            try { parse(t, input); return true; }
            catch ParseError(_): return false;
        }
    }
    return false;
}

list[Production] lookup(Grammar g, s: \parameterized-sort(name, actual))
    = [subst(p, formal, actual) | /p: prod(\parameterized-sort(name, formal), _, _) := g.rules[s] ? []]
    + [subst(p, formal, actual) | /p: prod(label(_, \parameterized-sort(name, formal)), _, _) := g.rules[s] ? []];

list[Production] lookup(Grammar g, s: \parameterized-lex(name, actual))
    = [subst(p, formal, actual) | /p: prod(\parameterized-lex(name, formal), _, _) := g.rules[s] ? []]
    + [subst(p, formal, actual) | /p: prod(label(_, \parameterized-lex(name, formal)), _, _) := g.rules[s] ? []];

default list[Production] lookup(Grammar g, Symbol s)
    = [p | /p: prod(s, _, _) := g.rules[s] ? []]
    + [p | /p: prod(label(_, s), _, _) := g.rules[s] ? []];

@synopsis{
    Utility functions for productions
}

&T subst(&T t, list[Symbol] from, list[Symbol] to)
    = subst(t, toMapUnique(zip2(from, to))) when size(from) == size(to);
&T subst(&T t, map[Symbol, Symbol] m)
    = visit (t) { case Symbol s => m[s] when s in m };

@synopsis{
    Utility functions for symbols
}

Symbol expand(\iter-seps(symbol, separators))
    = \seq([symbol, \iter-star(\seq(separators + symbol))]);
Symbol expand(\iter-star-seps(symbol, separators))
    = \opt(expand(\iter-seps(symbol, separators)));

Symbol delabel(label(_, Symbol s))
    = s;
default Symbol delabel(Symbol s)
    = s;

set[Symbol] getStrictPrefixes(set[Symbol] symbols)
    = {s1 | s1 <- symbols, any(s2 <- symbols, isStrictPrefix(s1, s2))};

bool isStrictPrefix(Symbol s1, Symbol s2)
    = s1.string? && s2.string? && s1.string != s2.string && startsWith(s2.string, s1.string);