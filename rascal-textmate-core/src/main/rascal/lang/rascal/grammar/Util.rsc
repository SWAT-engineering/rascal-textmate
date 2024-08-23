@synopsis{
    Utility functions to work with grammars, productions, and symbols.
}

module lang::rascal::grammar::Util

import Exception;
import Grammar;
import ParseTree;
import String;

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

default Symbol destar(Symbol s) = s;

@synopsis{
    Retain from set `symbols` each symbol that is a strict prefix of any other
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