@synopsis{
    Types and functions to analyze delimiters in productions
}

module lang::rascal::grammar::analyze::Delimiters

import Grammar;
import ParseTree;
import util::Maybe;

import Prelude;

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
    delimiter `end`, if any, that occur **inside** productions of symbol `s`
    (when `s` is a non-terminal) or `s` itself (when `s` is a delimiter). If
    `getOnlyFirst` is `true` (default: `false`), then only the first (resp.
    last) symbol of the productions can be considered as leftmost (resp.
    rightmost).
}

DelimiterPair getInnerDelimiterPair(Grammar g, Symbol s, bool getOnlyFirst = false) {
    s = delabel(s);
    if (isDelimiter(s)) {
        return <just(s), just(s)>;
    } else if (isNonTerminalType(s)) {
        Maybe[Symbol] begin = getInnerDelimiterBySymbol(g, forward(),  getOnlyFirst = getOnlyFirst)[s];
        Maybe[Symbol] end   = getInnerDelimiterBySymbol(g, backward(), getOnlyFirst = getOnlyFirst)[s];
        return <begin, end>;
    } else {
        return <nothing(), nothing()>;
    }
}

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
    Maybe[Symbol] begin = getInnerDelimiterByProduction(g, forward(),  getOnlyFirst = getOnlyFirst)[p];
    Maybe[Symbol] end   = getInnerDelimiterByProduction(g, backward(), getOnlyFirst = getOnlyFirst)[p];
    return <begin, end>;
}

@memo
private map[Symbol, Maybe[Symbol]] getInnerDelimiterBySymbol(Grammar g, Direction direction, bool getOnlyFirst = false) {
    map[Production, Maybe[Symbol]] m = getInnerDelimiterByProduction(g, direction, getOnlyFirst = getOnlyFirst);
    return (s: unique({m[p] | p <- m, s == delabel(p.def)}) | p <- m, s := delabel(p.def));
}

@memo
private map[Production, Maybe[Symbol]] getInnerDelimiterByProduction(Grammar g, Direction direction, bool getOnlyFirst = false) {
    map[Production, Maybe[Symbol]] ret = (p: nothing() | /p: prod(_, _, _) := g);
        
    solve (ret) {
        for (p <- ret, ret[p] == nothing()) {
            for (s <- reorder(p.symbols, direction)) {
                s = delabel(s);
                s = decond(s);
                if (isDelimiter(s)) {
                    ret[p] = just(s);
                    break;
                }
                if (isNonTerminalType(s) && just(delimiter) := unique({ret[child] | child <- getChildren(g, s)})) {
                    ret[p] = just(delimiter);
                    break;
                }
                if (getOnlyFirst) {
                    break;
                }
            }
        }
    }

    return ret;
}

private set[Production] getChildren(Grammar g, Symbol s)
    = {*lookup(g, s)};

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
    = <getOuterDelimiterByProduction(g, backward())[p], getOuterDelimiterByProduction(g, forward())[p]>;

@memo
private map[Symbol, Maybe[Symbol]] getOuterDelimiterBySymbol(Grammar g, Direction direction) {
    map[Symbol, Maybe[Symbol]] ret = (s: nothing() | /p: prod(_, _, _) := g, s := delabel(p.def));

    solve (ret) {
        for (s <- ret, ret[s] == nothing()) {
            set[Maybe[Symbol]] delimiters = {};
            for (prod(def, symbols, _) <- getParents(g, s)) {
                if ([*_, /s, *rest] := reorder(symbols, direction) && /s !:= rest) {
                    // Note: `rest` contains the symbols that follow/precede
                    // (depending on `direction`) `s` in the parent production
                    Maybe[Symbol] delimiter = nothing();
                    for (Symbol s <- rest) {
                        s = delabel(s);
                        if (isDelimiter(s)) {
                            delimiter = just(s);
                            break;
                        }
                        if (isNonTerminalType(s) && d: just(_) := getInnerDelimiterBySymbol(g, direction)[s]) {
                            delimiter = d;
                            break;
                        }
                    }
                    delimiters += just(_) := delimiter ? delimiter : ret[delabel(def)];
                }
            }
            ret[s] = unique(delimiters);
        }
    }
    
    return ret;
}

@memo
private map[Production, Maybe[Symbol]] getOuterDelimiterByProduction(Grammar g, Direction direction) {
    map[Symbol, Maybe[Symbol]] m = getOuterDelimiterBySymbol(g, direction);
    return (p: m[delabel(p.def)] | /p: prod(_, _, _) := g);
}

private set[Production] getParents(Grammar g, Symbol s)
    = {parent | /parent: prod(_, [*_, /s, *_], _) := g, s != delabel(parent.def)};

@synopsis{
    Returns the single delimiter if set `delimiters` is a singleton. Returns
    `nothing()` otherwise.
}

Maybe[Symbol] unique({d: just(Symbol _)}) = d;

default Maybe[Symbol] unique(set[Maybe[Symbol]] _) = nothing();

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
