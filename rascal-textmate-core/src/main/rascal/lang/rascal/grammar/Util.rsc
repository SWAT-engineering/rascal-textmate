@synopsis{
    Utility functions to work with grammars, productions, and symbols
}

module lang::rascal::grammar::Util

import Exception;
import Grammar;
import ParseTree;
import String;

import util::ListUtil;

@synopsis{
    Utility functions for grammars
}

bool tryParse(Grammar g, Symbol s, str input, bool allowAmbiguity = false) {
    if (isNonTerminalType(s) && !(s is \parameterized-sort) && !(s is \parameterized-lex)) {
        if (value v := type(s, g.rules), type[Tree] t := v) {
            try {
                parse(t, input, allowAmbiguity = allowAmbiguity);
                return true;
            }
            catch ParseError(_): {
                return false;
            }
            catch Ambiguity(_, _, _): {
                return false;
            }
        }
    }
    return false;
}

@synopsis{
    Checks if symbol `s` is recursive in grammar `g`
}

// TODO: Compute a map and memoize the results
bool isRecursive(Grammar g, Symbol s, set[Symbol] checking = {})
    = s in checking
    ? true
    : any(p <- lookup(g, delabel(s)),
          /Symbol child := p.symbols, 
          isRecursive(g, child, checking = checking + s));

@synopsis{
    Checks if production `p` is recursive in grammar `g`
}

bool isRecursive(Grammar g, Production p)
    = any(/Symbol s := p.symbols, isRecursive(g, s));

@synopsis{
    Representation of a pointer to a symbol in (the list of symbols of) a
    production. This is useful to distinguish between different occurrences of
    the same symbol in a grammar (i.e., they have different pointers).
}

alias Pointer = tuple[Production p, int index];

@synopsis{
    Finds the list of pointers -- a *trace* -- to the first occurrence of symbol
    `s`, if any, starting from production `p`, optionally in a particular
    direction (default: `forward()`). That is: if `<p1,i>` is followed by
    `<p2,_>` in the returned list, then `p1.symbols[i]` is a non-terminal and
    `p2` is one of its productions.
}

@description{
    For instance, consider the following grammar:

    ```
    lexical X  = Y;
    lexical Y  = alt1: "[" "[" "[" Z1 "]" "]" "]" | alt2: "<" Z2 ">"; 
    lexical Z1 = "foo" "bar";
    lexical Z2 = "baz";
    ```

    The list of pointers to `"bar"`, starting from `X`, is:

      - `<X,0>`
      - `<Y.alt1,3>`
      - `<Z1,1>`
    
    The list of pointers to `"qux"` is just empty.
}

list[Pointer] find(Grammar g, Production p, Symbol s, Direction dir = forward()) {

    list[Pointer] doFind(set[Production] doing, Production haystack, Symbol needle) {
        for (haystack notin doing, i <- reorder([0..size(haystack.symbols)], dir)) {
            Symbol ith = delabel(haystack.symbols[i]);
            if (ith == needle) {
                return [<haystack, i>];
            }
            for (isNonTerminalType(ith), child <- lookup(g, ith)) {
                if (list[Pointer] l: [_, *_] := doFind(doing + haystack, child, s)) {
                    return [<haystack, i>] + l;
                }
            }
        }

        return [];
    }

    return doFind({}, p, s);
}

@synopsis{
    Lookdowns a list of productions for symbol `s` in grammar `g`
}

// TODO: Rename this function because the current name makes little sense in
// isolation (it's supposed to be the opposite of `lookup`, but in that sense,
// the directions are illogical)

set[Production] lookdown(Grammar g, Symbol s)
    = {parent | /parent: prod(_, /Symbol _: s, _) := g};

@synopsis{
    Lookups a list of productions for symbol `s` in grammar `g`, replacing
    formal parameters with actual parameters when needed
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
    Replaces in `t` each occurrence of each symbol in `from` with the
    corresponding symbol (at the same index) in `to`
}

&T subst(&T t, list[Symbol] from, list[Symbol] to)
    = subst(t, toMapUnique(zip2(from, to)))
    when size(from) == size(to);
    
private &T subst(&T t, map[Symbol, Symbol] m)
    = visit (t) { case Symbol s => m[s] when s in m };

@synopsis{
    Expands symbols as follows:
      - `{s ","}+` => `s ("," s)*`
      - `{s ","}*` => `(s ("," s)*)?`
}

Symbol expand(\iter-seps(symbol, separators))
    = \seq([symbol, \iter-star(\seq(separators + symbol))]);
Symbol expand(\iter-star-seps(symbol, separators))
    = \opt(expand(\iter-seps(symbol, separators)));

@synopsis{
    Removes the label from symbol `s`, if any
}

Symbol delabel(\label(_, Symbol s)) = delabel(s);
default Symbol delabel(Symbol s)    = s;

@synopsis{
    Removes operators `?` and `*` from symbol `s`, if any
}

Symbol destar(\label(name, symbol))
    = label(name, destar(symbol));

Symbol destar(\opt(symbol))
    = destar(symbol);
Symbol destar(\iter-star(symbol))
    = \iter(destar(symbol));
Symbol destar(\iter-star-seps(symbol, separators))
    = \iter-seps(destar(symbol), separators);
Symbol destar(\seq([symbol]))
    = \seq([destar(symbol)]);
Symbol destar(\alt({symbol}))
    = \alt({destar(symbol)});

Symbol destar(\conditional(symbol, conditions))
    = \conditional(destar(symbol), conditions);

default Symbol destar(Symbol s) = s;

@synopsis{
    Removes the conditional from symbol `s`, if any
}

Symbol decond(\conditional(Symbol s, _)) = decond(s);
default Symbol decond(Symbol s)          = s;

@synopsis{
    Retains from set `symbols` each symbol that is a strict prefix of any other
    symbol in `symbols`
}

set[Symbol] retainStrictPrefixes(set[Symbol] symbols)
    = {s1 | s1 <- symbols, any(s2 <- symbols, isStrictPrefix(s1, s2))};

@synopsis{
    Removes from set `symbols` each symbol that is a strict prefix of any other
    symbol in `symbols`
}

set[Symbol] removeStrictPrefixes(set[Symbol] symbols)
    = symbols - retainStrictPrefixes(symbols);

@synopsis{
    Checks if symbol `s1` is a strict prefix of symbol `s2`
}

bool isStrictPrefix(Symbol s1, Symbol s2)
    = s1.string? && s2.string? && s1.string != s2.string && startsWith(s2.string, s1.string);

@synopsis{
    Checks if a condition is an except condition
}

bool isExceptCondition(\except(_))          = true;
default bool isExceptCondition(Condition _) = false;

@synopsis{
    Checks if a condition is a prefix condition
}

bool isPrefixCondition(\precede(_))         = true;
bool isPrefixCondition(\not-precede(_))     = true;
bool isPrefixCondition(\at-column(_))       = true;
bool isPrefixCondition(\begin-of-line())    = true;
default bool isPrefixCondition(Condition _) = false;

@synopsis{
    Checks if a condition is an suffix condition
}

bool isSuffixCondition(\follow(_))          = true;
bool isSuffixCondition(\not-follow(_))      = true;
bool isSuffixCondition(\end-of-line())      = true;
default bool isSuffixCondition(Condition _) = false;

@synopsis{
    Checks if a condition is a delete condition
}

bool isDeleteCondition(\delete(_))          = true;
default bool isDeleteCondition(Condition _) = false;