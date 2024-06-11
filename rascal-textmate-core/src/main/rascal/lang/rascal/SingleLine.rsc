module lang::rascal::SingleLine

import Grammar;
import IO;
import Map;
import ParseTree;
import String;
import util::Maybe;

alias Env = map[Symbol, Maybe[bool]];

@synopsis{
    Gets the single-line symbols in a set of productions.
}

set[Symbol] getSingleLineSymbols(map[Symbol, Production] rules) {
    Env old = ();
    Env new = (s: nothing() | s <- domain(rules));
    while (old != new) {
        old = new;
        new = old + (s: isSingleLine(old, rules[s]) | s <- old, nothing() := old[s]);
    }
    return {s | s <- new, just(true) := new[s]};
}

@synopsis{
    Checks if a set/list of values (presumably: productions, symbols, or
    conditions) is single-line.
}

Maybe[bool] areSingleLine(Env e, set[value] values)
    = (just(true) | min(it, isSingleLine(e, v)) | v <- values);
Maybe[bool] areSingleLine(Env e, list[value] values)
    = (just(true) | min(it, isSingleLine(e, v)) | v <- values);

@synopsis{
    Checks if a production is single-line.
}

// `Type`
Maybe[bool] isSingleLine(Env e, \choice(_, alternatives))
    = areSingleLine(e, alternatives);

// `ParseTree`
Maybe[bool] isSingleLine(Env e, prod(_, symbols, _))
    = areSingleLine(e, symbols);
Maybe[bool] isSingleLine(Env e, \priority(_, choices))
    = areSingleLine(e, choices);
Maybe[bool] isSingleLine(Env e, \associativity(_, _, alternatives))
    = areSingleLine(e, alternatives);

default Maybe[bool] isSingleLine(Env _, Production p) {
    println("[LOG] isSingleLine: Unsupported production <p>");
    return nothing();
}

@synopsis{
    Checks if a symbol is single-line.
}

// `Type`
Maybe[bool] isSingleLine(Env e, label(_, symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, parameter(_, _))
    = just(true);

// `ParseTree`: Start
Maybe[bool] isSingleLine(Env e, \start(symbol))
    = isSingleLine(e, symbol);

// `ParseTree`: Non-terminals
Maybe[bool] isSingleLine(Env e, s: \sort(_))
    = lookup(e, s);
Maybe[bool] isSingleLine(Env e, s: \lex(_))
    = lookup(e, s);
Maybe[bool] isSingleLine(Env e, s: \layouts(_))
    = lookup(e, s);
Maybe[bool] isSingleLine(Env e, s: \keywords(_))
    = lookup(e, s);
Maybe[bool] isSingleLine(Env e, s: \parameterized-sort(_, parameters))
    = min(lookup(e, s), areSingleLine(e, parameters));
Maybe[bool] isSingleLine(Env e, s: \parameterized-lex(_, parameters))
    = min(lookup(e, s), areSingleLine(e, parameters));

// `ParseTree`: Terminals
Maybe[bool] isSingleLine(Env _, \lit(string))
    = just(!containsLineTerminator(string));
Maybe[bool] isSingleLine(Env _, \cilit(string))
    = just(!containsLineTerminator(string));
Maybe[bool] isSingleLine(Env _, \char-class(ranges))
    = just(isEmpty(ranges) || all(r <- ranges, !containsLineTerminator(r)));

// `ParseTree`: Regular expressions
Maybe[bool] isSingleLine(Env _, \empty())
    = just(true);
Maybe[bool] isSingleLine(Env e, \opt(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \iter(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \iter-star(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \iter-seps(symbol, separators))
    = areSingleLine(e, [symbol] + separators);
Maybe[bool] isSingleLine(Env e, \iter-star-seps(symbol, separators))
    = areSingleLine(e, [symbol] + separators);
Maybe[bool] isSingleLine(Env e, \alt(alternatives))
    = areSingleLine(e, alternatives);
Maybe[bool] isSingleLine(Env e, \seq(symbols))
    = areSingleLine(e, symbols);

// `ParseTree`: Conditional
Maybe[bool] isSingleLine(Env e, \conditional(symbol, conditions))
    = min(isSingleLine(e, symbol), areSingleLine(e, conditions));

default Maybe[bool] isSingleLine(Env _, Symbol s) {
    println("[LOG] isSingleLine: Unsupported symbol <s>");
    return nothing();
}

@synopsis{
    Checks if a condition is single-line.
}

Maybe[bool] isSingleLine(Env e, \follow(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \not-follow(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \precede(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \not-precede(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env e, \delete(symbol))
    = isSingleLine(e, symbol);
Maybe[bool] isSingleLine(Env _, \at-column(_))
    = just(true);
Maybe[bool] isSingleLine(Env _, \begin-of-line())
    = just(true);
Maybe[bool] isSingleLine(Env _, \end-of-line())
    = just(true);
Maybe[bool] isSingleLine(Env _, \except(_))
    = just(true);

default Maybe[bool] isSingleLine(Env _, Condition c) {
    println("[LOG] isSingleLine: Unsupported condition <c>");
    return nothing();
}

@synopsis{
    Lookup a symbol in an evironment.
}

Maybe[bool] lookup(Env e, \parameterized-sort(name, _))
    =  /s: \parameterized-sort(name, _) := e ? e[s] : nothing();
Maybe[bool] lookup(Env e, \parameterized-lex(name, _))
    =  /s: \parameterized-lex(name, _) := e ? e[s] : nothing();

default Maybe[bool] lookup(Env e, Symbol s)
    = s in e ? e[s] : nothing();

@synopsis{
    Checks if a string/character range contains a line terminator.
}

bool containsLineTerminator(str s)
    = LF in chars(s);
bool containsLineTerminator(range(begin, end))
    = begin <= LF && LF <= end;

int LF = 10;

@synopsis{
    Computes the *minimum* of two `Maybe[bool]` values, according to the 
    following total order: `just(false)` < `nothing()` < `just(true)`. This
    coincides with the disjunction operator in three-valued logic.
}

Maybe[bool] min(just(true),  just(true))  = just(true);
Maybe[bool] min(just(true),  nothing())   = nothing();
Maybe[bool] min(just(true),  just(false)) = just(false);
Maybe[bool] min(nothing(),   just(true))  = nothing();
Maybe[bool] min(nothing(),   nothing())   = nothing();
Maybe[bool] min(nothing(),   just(false)) = just(false);
Maybe[bool] min(just(false), just(true))  = just(false);
Maybe[bool] min(just(false), nothing())   = just(false);
Maybe[bool] min(just(false), just(false)) = just(false);

@synopsis{
    Computes the *maximum* of two `Maybe[bool]` values, according to the 
    following total order: `just(false)` < `nothing()` < `just(true)`. This
    coincides with the conjunction operator in three-valued logic.
}

Maybe[bool] max(just(true),  just(true))  = just(true);
Maybe[bool] max(just(true),  nothing())   = just(true);
Maybe[bool] max(just(true),  just(false)) = just(true);
Maybe[bool] max(nothing(),   just(true))  = just(true);
Maybe[bool] max(nothing(),   nothing())   = nothing();
Maybe[bool] max(nothing(),   just(false)) = nothing();
Maybe[bool] max(just(false), just(true))  = just(true);
Maybe[bool] max(just(false), nothing())   = nothing();
Maybe[bool] max(just(false), just(false)) = just(false);