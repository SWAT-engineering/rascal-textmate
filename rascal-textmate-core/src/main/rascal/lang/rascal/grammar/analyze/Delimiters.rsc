@synopsis{
    Types and functions to analyze delimiters in productions
}

module lang::rascal::grammar::analyze::Delimiters

import Grammar;
import ParseTree;
import util::Maybe;

import lang::rascal::grammar::Util;

alias DelimiterPair = tuple[Maybe[Symbol] begin, Maybe[Symbol] end];

data Direction   // Traverse lists of symbols (in productions)...
    = forward()  //   - ...from left to right;
    | backward() //   - ...from right to left.
    ;

@synopsis{
    Reorder a list according to the specified direction
}

list[&T] reorder(list[&T] l, forward())  = l;
list[&T] reorder(list[&T] l, backward()) = reverse(l);

@synopsis{
    Gets the unique leftmost delimiter (`begin`) and the unique rightmost
    delimiter (`end`), if any, that occur **inside** production `p` in grammar
    `g`. If `getOnlyFirst` is `true` (default: `false`), then only the first
    (resp. last) symbol of the production can be considered as leftmost (resp.
    rightmost).
}

@description{
    For instance, consider the following grammar:

    ```
    lexical X  = Y;
    lexical Y  = Y1 | Y2;
    lexical Y1 = "[" Z "]"; 
    lexical Y2 = "[" Z ")" [a-z];
    lexical Z  = [a-z];
    ```

    The unique leftmost delimiter of the `Y1`  production is `[`. The unique
    leftmost delimiter of the `Y2` production is `[`. The unique leftmost
    delimiter of the `X` production is `[`. The remaining productions do not
    have a unique leftmost delimiter.

    The unique rightmost delimiter of the `Y1` production is `]`. The unique
    rightmost delimiter of the `Y2` production is `)`. The remaining productions
    do not have a unique rightmost delimiter. In particular, the `X` production
    has two rightmost delimiters, but not one unique.

    If `getOnlyFirst` is `true`, then the `Y2` production does not have a
    rightmost delimiter.
}

DelimiterPair getInnerDelimiterPair(Grammar g, Production p, bool getOnlyFirst = false) {
    Maybe[Symbol] begin = getInnerDelimitersByProduction(g, forward(), getOnlyFirst = getOnlyFirst)[p];
    Maybe[Symbol] end = getInnerDelimitersByProduction(g, backward(), getOnlyFirst = getOnlyFirst)[p];
    return <begin, end>;
}

@memo
private map[Symbol, Maybe[Symbol]] getInnerDelimitersBySymbol(Grammar g, Direction direction, bool getOnlyFirst = false) {
    map[Production, Maybe[Symbol]] m = getInnerDelimitersByProduction(g, direction, getOnlyFirst = getOnlyFirst);
    return (s: unique({m[p] | p <- m, s == delabel(p.def)}) | p <- m, s := delabel(p.def));
}

@memo
private map[Production, Maybe[Symbol]] getInnerDelimitersByProduction(Grammar g, Direction direction, bool getOnlyFirst = false) {
    map[Production, Maybe[Symbol]] delimiters = (p: nothing() | /p: prod(_, _, _) := g);
    set[Production] todo() = {p | p <- delimiters, delimiters[p] == nothing()};

    Maybe[Symbol] \do(Production p) {
        for (s <- reorder(p.symbols, direction)) {
            s = delabel(s);
            if (isDelimiter(s)) {
                return just(s);
            }
            if (isNonTerminalType(s) && just(delimiter) := unique({delimiters[child] | child <- getChildren(g, s)})) {
                return just(delimiter);
            }
            if (getOnlyFirst) {
                return nothing();
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
    Gets the unique rightmost delimiter (`begin`) and the unique leftmost
    delimiter (`end`), if any, that occur **outside** production `p` in grammar
    `g`.
}

@description{
    For instance, consider the following grammar:

    ```
    lexical X  = Y;
    lexical Y  = Y1 | Y2;
    lexical Y1 = "[" Z "]"; 
    lexical Y2 = "[" Z ")" [a-z];
    lexical Z  = [a-z];
    ```

    The unique rightmost delimiter of the `Z` production is `[`. The remaining
    productions do not have a unique rightmost delimiter.

    The productions do not have a unique leftmost delimiter. In particular, the
    `Z` productions has two leftmost delimiters, but not one unique.
}

DelimiterPair getOuterDelimiterPair(Grammar g, Production p)
    = <getOuterDelimitersByProduction(g, backward())[p], getOuterDelimitersByProduction(g, forward())[p]>;

@memo
private map[Symbol, Maybe[Symbol]] getOuterDelimitersBySymbol(Grammar g, Direction direction) {
    map[Symbol, Maybe[Symbol]] delimiters = (s: nothing() | /p: prod(_, _, _) := g, s := delabel(p.def));
    set[Symbol] todo() = {s | s <- delimiters, delimiters[s] == nothing()};

    Maybe[Symbol] \do(Symbol s)
        = unique({\do(parent.def, rest) | parent <- getParents(g, s), [*_, /s, *rest] := reorder(parent.symbols, direction), /s !:= rest});

    Maybe[Symbol] \do(Symbol def, list[Symbol] rest) {
        for (Symbol s <- rest) {
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
private map[Production, Maybe[Symbol]] getOuterDelimitersByProduction(Grammar g, Direction direction) {
    map[Symbol, Maybe[Symbol]] m = getOuterDelimitersBySymbol(g, direction);
    return (p: m[delabel(p.def)] | /p: prod(_, _, _) := g);
}

private set[Production] getParents(Grammar g, Symbol s)
    = {parent | /parent: prod(_, [*_, /s, *_], _) := g, s != delabel(parent.def)};

@synopsis{
    Returns the single delimiter if set `delimiters` is a singleton. Returns
    `nothing()` otherwise.
}

Maybe[Symbol] unique(set[Maybe[Symbol]] delimiters)
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
