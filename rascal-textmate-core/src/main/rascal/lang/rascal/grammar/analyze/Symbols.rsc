@synopsis{
    Types and functions to analyze symbols
}

@description{
    Note: Some functions in this module seemingly overlap with those in module
    `lang::rascal::grammar::Lookahead` (i.e., computation of first/follow sets).
    However, only symbols of the form `\char-class(_)` are considered terminals
    in that module, which is too strict for the purpose of this project.
}

// TODO: The analysis of delimiters in module
// `lang::rascal::grammar::analyze::Delimiters` can probably be rewritten (less
// code) to use functions in this module.

module lang::rascal::grammar::analyze::Symbols

import Grammar;
import ParseTree;
import util::Maybe;

import lang::rascal::grammar::Util;
import util::MaybeUtil;

@synopsis{
    Representation of a traversal direction along a list of symbols
}

data Direction   // Traverse lists of symbols (in productions)...
    = forward()  //   - ...from left to right;
    | backward() //   - ...from right to left.
    ;

private list[&T] reorder(list[&T] l, forward())  = l;
private list[&T] reorder(list[&T] l, backward()) = reverse(l);

@synopsis{
    Computes the *last* set of symbol `s` in grammar `g`
}

set[Symbol] last(Grammar g, Symbol s)
    = unmaybe(firstBySymbol(g, isTerminal, backward())[delabel(s)]);

@synopsis{
    Computes the *first* set of symbol `s` in grammar `g`
}

set[Symbol] first(Grammar g, Symbol s)
    = unmaybe(firstBySymbol(g, isTerminal, forward())[delabel(s)]);

@memo
private map[Symbol, Maybe[set[Symbol]]] firstBySymbol(Grammar g, bool(Symbol) predicate, Direction dir) {
    map[Symbol, Maybe[set[Symbol]]] ret
        = (delabel(s): nothing() | s <- g.rules) // Non-terminals
        + (delabel(s): nothing() | /prod(_, [*_, s, *_], _) := g, !isNonTerminalType(s)); // Terminals

    Maybe[set[Symbol]] firstOf([])
        = just({});
    Maybe[set[Symbol]] firstOf([h, *t])
        = \set: just({\empty(), *_}) := ret[delabel(h)]
        ? union(\set, firstOf(t))
        : ret[delabel(h)];

    solve (ret) {
        for (s <- ret, nothing() == ret[s]) {
            if (predicate(s)) {
                ret[s] = just({s});
            } else if (list[Production] prods: [_, *_] := lookup(g, s)) {
                ret[s] = (just({}) | union(it, firstOf(reorder(p.symbols, dir))) | p <- prods);
            } else {
                ret[s] = just({\empty()});
            }
        }
    }

    return ret;
}

@synopsis{
    Computes the *precede* set of symbol `s` in grammar `g`
}

set[Symbol] precede(Grammar g, Symbol s)
    = unmaybe(followBySymbol(g, isTerminal, backward())[delabel(s)]);

@synopsis{
    Computes the *follow* set of symbol `s` in grammar `g`
}

set[Symbol] follow(Grammar g, Symbol s)
    = unmaybe(followBySymbol(g, isTerminal, forward())[delabel(s)]);

@memo
private map[Symbol, Maybe[set[Symbol]]] followBySymbol(Grammar g, bool(Symbol) predicate, Direction dir) {
    map[Symbol, Maybe[set[Symbol]]] ret = (delabel(s): nothing() | s <- g.rules); // Non-terminals
    
    Maybe[set[Symbol]] followOf(Symbol parent, [])
        = ret[delabel(parent)];
    Maybe[set[Symbol]] followOf(Symbol parent, [h, *t])
        = just({\empty(), *rest}) := firstBySymbol(g, predicate, dir)[delabel(h)]
        ? union(just(rest), followOf(parent, t))
        : firstBySymbol(g, predicate, dir)[delabel(h)];

    solve (ret) {
        for (s <- ret, nothing() == ret[s]) {
            ret[s] = just({});
            for (/prod(def, symbols, _) := g, [*_, t, *after] := reorder(symbols, dir), s == delabel(t)) {
                ret[s] = union(ret[s], followOf(def, after));
            }
        }
    }

    return ret;
}

@synopsis{
    Checks if symbol `s` is a terminal
}

bool isTerminal(Symbol s)
    = !isNonTerminalType(s);