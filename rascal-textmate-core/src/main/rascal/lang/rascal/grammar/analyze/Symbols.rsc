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
import String;
import util::Math;
import util::Maybe;

import lang::rascal::grammar::Util;
import util::ListUtil;
import util::MaybeUtil;

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
    Maybe[set[Symbol]] firstOf([Symbol h, *Symbol t])
        = \set: just({\empty(), *_}) := ret[delabel(h)]
        ? util::MaybeUtil::union(\set, firstOf(t))
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

@synposis{
    Sorts list of terminals `symbols` by minimum length (in ascending order)
}

list[Symbol] sortByMinimumLength(list[Symbol] symbols) {
    bool less(Symbol s1, Symbol s2) = length(s1).min < length(s2).min;
    return sort(symbols, less);
}

@synopsis{
    Representation of the minimum length and the maximum length of the text
    produced by a symbol. If `max` is `nothing()`, then the text produced is
    statically unbounded.
}

alias Range = tuple[int min, Maybe[int] max];

private Range ZERO = <0, just(0)>;
private Range seq(Range r1, Range r2) = <r1.min + r2.min, add(r1.max, r2.max)>;
private Range alt(Range r1, Range r2) = <min(r1.min, r2.min), max(r1.max, r2.max)>;

private Maybe[int] add(just(int i), just(int j)) = just(i + j);
private default Maybe[int] add(Maybe[int] _, Maybe[int] _) = nothing();

private Maybe[int] max(just(int i), just(int j)) = just(max(i, j));
private default Maybe[int] max(Maybe[int] _, Maybe[int] _) = nothing();

@synopsis{
    Computes the length of a terminal symbol as a range
}

Range length(\lit(string))   = <size(string), just(size(string))>;
Range length(\cilit(string)) = <size(string), just(size(string))>;
Range length(\char-class(_)) = <1, just(1)>;

Range length(\empty())                   = ZERO;
Range length(\opt(symbol))               = length(symbol)[min = 0];
Range length(\iter(symbol))              = length(symbol)[max = issue2007];
Range length(\iter-star(symbol))         = <0, max: just(0) := length(symbol).max ? max : nothing()>;
Range length(\iter-seps(symbol, _))      = length(symbol)[max = issue2007];
Range length(\iter-star-seps(symbol, _)) = <0, max: just(0) := length(symbol).max ? max : nothing()>;
Range length(\alt(alternatives))         = {Symbol first, *Symbol rest} := alternatives
                                         ? (length(first) | alt(it, length(s)) | s <- rest)
                                         : ZERO;
Range length(\seq(symbols))              = (ZERO | seq(it, length(s)) | s <- symbols);

Range length(\conditional(symbol, _)) = length(symbol);

// TODO: Remove this workaround when issue #2007 is fixed:
//   - https://github.com/usethesource/rascal/issues/2007
private Maybe[int] issue2007 = nothing();