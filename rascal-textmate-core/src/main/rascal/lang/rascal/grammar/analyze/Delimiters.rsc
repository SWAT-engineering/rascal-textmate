@synopsis{
    Types and functions to analyse delimiters in productions
}

module lang::rascal::grammar::analyze::Delimiters

import Grammar;
import ParseTree;
import util::Maybe;

import lang::rascal::grammar::Util;

alias Delimiter     = Maybe[Symbol];
alias DelimiterPair = tuple[Delimiter begin, Delimiter end];

data Direction    // Traverse lists of symbols (in productions)...
    = forward()   //   - ...from left to right;
    | backward(); //   - ...from right to left.

@synopsis{
    Reorder a list according to the specified direction
}

list[&T] reorder(list[&T] l, forward())  = l;
list[&T] reorder(list[&T] l, backward()) = reverse(l);

@synopsis{
    Gets the leftmost common delimiter (`begin`) and the rightmost common
    delimiter (`end`), if any, that occur inside production `p` in grammar `g`
}

DelimiterPair getInnerDelimiterPair(Grammar g, Production p)
    = <getInnerDelimitersByProduction(g, forward())[p], getInnerDelimitersByProduction(g, backward())[p]>;

@memo
private map[Symbol, Delimiter] getInnerDelimitersBySymbol(Grammar g, Direction direction) {
    map[Production, Delimiter] m = getInnerDelimitersByProduction(g, direction);
    return (s: unique({m[p] | p <- m, s == delabel(p.def)}) | p <- m, s := delabel(p.def));
}

@memo
private map[Production, Delimiter] getInnerDelimitersByProduction(Grammar g, Direction direction) {
    map[Production, Delimiter] delimiters = (p: nothing() | /p: prod(_, _, _) := g);
    set[Production] todo() = {p | p <- delimiters, delimiters[p] == nothing()};

    Delimiter \do(Production p) {
        for (s <- reorder(p.symbols, direction)) {
            s = delabel(s);
            if (isDelimiter(s)) {
                return just(s);
            }
            if (isNonTerminalType(s) && just(delimiter) := unique({delimiters[child] | child <- getChildren(g, s)})) {
                return just(delimiter);
            }
        }
        return nothing();
    }

    solve (delimiters) delimiters = delimiters + (p: \do(p) | p <- todo());
    return delimiters;
}

set[Production] getChildren(Grammar g, Symbol s)
    = {child | child <- lookup(g, s)};

@synopsis{
    Gets the rightmost common delimiter (`begin`) and the leftmost common
    delimiter (`end`), if any, that occur outside production `p` in grammar `g`.
}

DelimiterPair getOuterDelimiterPair(Grammar g, Production p)
    = <getOuterDelimitersByProduction(g, backward())[p], getOuterDelimitersByProduction(g, forward())[p]>;

@memo
private map[Symbol, Delimiter] getOuterDelimitersBySymbol(Grammar g, Direction direction) {
    map[Symbol, Delimiter] delimiters = (s: nothing() | /p: prod(_, _, _) := g, s := delabel(p.def));
    set[Symbol] todo() = {s | s <- delimiters, delimiters[s] == nothing()};

    Delimiter \do(Symbol s)
        = unique({\do(parent.def, rest) | parent <- getParents(g, s), [*_, /s, *rest] := reorder(parent.symbols, direction), /s !:= rest});

    Delimiter \do(Symbol def, list[Symbol] rest) {
        for (s <- rest) {
            s = delabel(s);
            if (isDelimiter(s)) {
                return just(s);
            }
            if (isNonTerminalType(s) && just(delimiter) := getInnerDelimitersBySymbol(g, direction)[s]) {
                return just(delimiter);
            }
        }
        return delimiters[delabel(def)];
    }

    solve (delimiters) delimiters = delimiters + (s: \do(s) | s <- todo());
    return delimiters;
}

@memo
private map[Production, Delimiter] getOuterDelimitersByProduction(Grammar g, Direction direction) {
    map[Symbol, Delimiter] m = getOuterDelimitersBySymbol(g, direction);
    return (p: m[delabel(p.def)] | /p: prod(_, _, _) := g);
}

private set[Production] getParents(Grammar g, Symbol s)
    = {parent | /parent: prod(_, [*_, /s, *_], _) := g, s != delabel(parent.def)};

@synopsis{
    Returns the single delimiter if set `delimiters` is a singleton. Returns
    `nothing()` otherwise.
}

Delimiter unique(set[Delimiter] delimiters)
    = {d: just(_)} := delimiters
    ? d
    : nothing();

@synopsis{
    Checks if a symbol is a delimiter
}

bool isDelimiter(lit(string))
    = /^\w+$/ !:= string;
bool isDelimiter(cilit(string))
    = /^\w+$/ !:= string;

default bool isDelimiter(Symbol _)
    = false;

@synopsis{
    Checks if a symbol is a keyword
}

bool isKeyword(lit(string))
    = /^\w+$/ := string;
bool isKeyword(cilit(string))
    = /^\w+$/ := string;

default bool isKeyword(Symbol _)
    = false;
