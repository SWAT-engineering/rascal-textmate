module lang::oniguruma::Convert

import Grammar;
import IO;
import Map;
import ParseTree;
import String;
import util::Maybe;

import lang::oniguruma::RegExp;
import lang::rascal::Util;

alias Env = map[Symbol, Maybe[RegExp]];

@synopsis{
    Converts a set of rules to a set of regular expressions.
}

map[Symbol, Maybe[RegExp]] toRegExps(map[Symbol, Production] rules) {
    Env old = ();
    Env new = (s: nothing() | s <- domain(rules));
    while (old != new) {
        old = new;
        new = old + (s: toRegExp(old, rules[s]) | s <- old, nothing() := old[s]);
    }
    return new;
}

@synopsis{
    Converts a set/list of values (presumably: productions, symbols, or
    conditions) to a list of regular expressions.
}

list[Maybe[RegExp]] toRegExps(Env e, set[value] values)
    = [toRegExp(e, v) | v <- values];
list[Maybe[RegExp]] toRegExps(Env e, list[value] values)
    = [toRegExp(e, v) | v <- values];

@synopsis{
    Converts a production to a regular expression.
}

// `Type`
Maybe[RegExp] toRegExp(Env e, \choice(_, alternatives))
    = infix("|", toRegExps(e, alternatives));

// `ParseTree`
Maybe[RegExp] toRegExp(Env e, prod(_, symbols, {\tag("category"(c)), *_}))
    = group(infix("", toRegExps(e, symbols)), category=c);
Maybe[RegExp] toRegExp(Env e, prod(_, symbols, attributes))
    = infix("", toRegExps(e, symbols)) when {\tag("category"(_)), *_} !:= attributes;

default Maybe[RegExp] toRegExp(Env _, Production p) {
    println("[LOG] toRegExp: Unsupported production <p>");
    return nothing();
}

@synopsis{
    Converts a symbol to a regular expression.
}

// `Type`
Maybe[RegExp] toRegExp(Env e, label(_, symbol))
    = toRegExp(e, symbol);
// Maybe[RegExp] isSingleLine(Env e, parameter(_, _))
//     = nothing(); // TODO

// `ParseTree`: Start
Maybe[RegExp] toRegExp(Env e, \start(symbol))
    = toRegExp(e, symbol);

// `ParseTree`: Non-terminals
Maybe[RegExp] toRegExp(Env e, s: \sort(_)) 
    = lookup(e, s);
Maybe[RegExp] toRegExp(Env e, s: \lex(_))
    = lookup(e, s);
Maybe[RegExp] toRegExp(Env e, s: \layouts(_))
    = lookup(e, s);
Maybe[RegExp] toRegExp(Env e, s: \keywords(_))
    = lookup(e, s);
// Maybe[RegExp] toRegExp(Env _, \parameterized-sort(_, _))
//     = nothing(); // TODO
// Maybe[RegExp] toRegExp(Env _, \parameterized-lex(_, _))
//     = nothing(); // TODO

// `ParseTree`: Terminals
Maybe[RegExp] toRegExp(Env _, \lit(string))
    = just(regExp("(?:<toCodeUnits(chars(string))>)", []));
Maybe[RegExp] toRegExp(Env _, \cilit(string))
    = just(regExp("(?i:<toCodeUnits(chars(string))>)", []));
Maybe[RegExp] toRegExp(Env e, \char-class(ranges))
    = infix("|", toRegExps(e, ranges));

// `ParseTree`: Regular expressions
Maybe[RegExp] toRegExp(Env _, \empty())
    = nothing();
Maybe[RegExp] toRegExp(Env e, \opt(symbol))
    = suffix("??", toRegExp(e, symbol));
Maybe[RegExp] toRegExp(Env e, \iter(symbol))
    = suffix("+?", toRegExp(e, symbol));
Maybe[RegExp] toRegExp(Env e, \iter-star(symbol))
    = suffix("*?", toRegExp(e, symbol));
Maybe[RegExp] toRegExp(Env e, Symbol s: \iter-seps(_, _))
    = toRegExp(e, expand(s));
Maybe[RegExp] toRegExp(Env e, Symbol s: \iter-star-seps(_, _))
    = toRegExp(e, expand(s));
Maybe[RegExp] toRegExp(Env e, \alt(alternatives))
    = infix("|", toRegExps(e, alternatives));
Maybe[RegExp] toRegExp(Env e, \seq(symbols))
    = infix("", toRegExps(e, symbols));

// `ParseTree`: Condition
Maybe[RegExp] toRegExp(Env e, \conditional(symbol, conditions)) {
    // TODO: Document what's happening here...

    if ({delete: \delete(_), *rest} := conditions) {
        Maybe[RegExp] m1 = toRegExp(e, \conditional(symbol, rest));
        Maybe[RegExp] m2 = toRegExp(e, delete);
        if (just(regExp(string1, categories1)) := m1, just(regExp(string2, categories2)) := m2) {
            str string = "(?=(?\<head\><string1>)(?\<tail\>.*)$)(?!(?:<string2>)\\k\<tail\>$)\\k\<head\>";
            list[str] categories = ["", *categories1, "", *categories2];
            return just(regExp(string, categories));
        } else {
            return nothing();
        }
    } else {

        list[Condition] prefixConditions
            = [c | Condition c: /\precede(_) <- conditions]
            + [c | Condition c: /\not-precede(_) <- conditions]
            + [c | Condition c: /\begin-of-line() <- conditions];

        list[Condition] suffixConditions
            = [c | Condition c: /\follow(_) <- conditions]
            + [c | Condition c: /\not-follow(_) <- conditions]
            + [c | Condition c: /\end-of-line() <- conditions];

        list[Maybe[RegExp]] regExps
            = toRegExps(e, prefixConditions)
            + [toRegExp(e, symbol)]
            + toRegExps(e, suffixConditions);

        return infix("", regExps);
    }
}

default Maybe[RegExp] toRegExp(Env _, Symbol s) {
    println("[LOG] toRegExp: Unsupported symbol <s>");
    return nothing();
}

@synopsis{
    Converts a condition to a regular expression.
}

Maybe[RegExp] toRegExp(Env e, \follow(symbol))
    = prefix("(?=", suffix(")", toRegExp(e, symbol)));
Maybe[RegExp] toRegExp(Env e, \not-follow(symbol))
    = prefix("(?!", suffix(")", toRegExp(e, symbol)));
Maybe[RegExp] toRegExp(Env e, \precede(symbol))
    = prefix("(?\<=", suffix(")", toRegExp(e, symbol)));
Maybe[RegExp] toRegExp(Env e, \not-precede(symbol))
    = prefix("(?\<!", suffix(")", toRegExp(e, symbol)));
Maybe[RegExp] toRegExp(Env e, \delete(symbol))
    = toRegExp(e, symbol);
// Maybe[RegExp] toRegExp(Env _, \at-column(_))
//     = nothing(); // TODO
Maybe[RegExp] toRegExp(Env _, \begin-of-line())
    = just(regExp("(?:^)", []));
Maybe[RegExp] toRegExp(Env _, \end-of-line())
    = just(regExp("(?:$)", []));
// Maybe[RegExp] toRegExp(Env _, \except(_))
//     = nothing(); // TODO

default Maybe[RegExp] toRegExp(Env _, Condition c) {
    println("[LOG] toRegExp: Unsupported condition <c>");
    return nothing();
}

@synopsis{
    Lookup a symbol in an evironment.
}

Maybe[RegExp] lookup(Env e, \parameterized-sort(name, _))
    = {<\parameterized-sort(name, _), m>, *_} := toRel(e) ? m : nothing();
Maybe[RegExp] lookup(Env e, \parameterized-lex(name, _))
    = {<\parameterized-lex(name, _), m>, *_} := toRel(e) ? m : nothing();

default Maybe[RegExp] lookup(Env e, Symbol s)
    = s in e ? e[s] : nothing();

@synopsis{
    Converts a character range to a regular expression.
}

Maybe[RegExp] toRegExp(Env _, range(begin, end))
    = just(regExp("[<toCodeUnit(begin)>-<toCodeUnit(end)>]", []));

@synopsis{
    Converts a (list of) char(s) to a (list of) code unit(s).
}

str toCodeUnits(list[int] chars)
    = ("" | it + toCodeUnit(i) | i <- chars);

str toCodeUnit(int i)
    = "\\u" + right(toHex(i), 4, "0");

str toHex(int i) = "<i>" when 0 <= i && i < 10;
str toHex(   10) = "A";
str toHex(   11) = "B";
str toHex(   12) = "C";
str toHex(   13) = "D";
str toHex(   14) = "E";
str toHex(   15) = "F";
str toHex(int i) = "<toHex(i / 16)><toHex(i % 16)>" when 15 < i;