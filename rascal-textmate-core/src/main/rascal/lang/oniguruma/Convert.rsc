module lang::oniguruma::Convert

import Grammar;
import IO;
import List;
import Map;
import ParseTree;
import Set;
import String;
import util::Maybe;

import lang::oniguruma::RegExp;
import lang::rascal::Util;

alias Env = map[Production, Maybe[RegExp]];

@synopsis{
    Converts a set of rules to a set of regular expressions.
}

map[Symbol, Maybe[RegExp]] toRegExps(map[Symbol, Production] rules) {
    Env old = ();
    Env new = (p: nothing() | p <- range(rules));
    while (old != new) {
        old = new;
        new = old + (p: toRegExp(old, p) | p <- old, nothing() := old[p]);
    }
    return (def: new[c] | c: \choice(def, _) <- new);
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
Maybe[RegExp] toRegExp(Env e, parameter(_, _))
    = nothing();

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
Maybe[RegExp] toRegExp(Env e, s: \parameterized-sort(_, _))
    = lookup(e, s);
Maybe[RegExp] toRegExp(Env e, s: \parameterized-lex(_, _))
    = lookup(e, s);

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

    // Conditions are classified and converted in ascending class number:
    //  1. Except conditions: conversion depends on `symbol`;
    //  2. Prefix conditions: conversion depends on class 1 conversions;
    //  3. Suffix conditions: conversion depends on class 1-2 conversions;
    //  4. Delete conditions: conversion depends on class 1-3 conversions.

    list[Condition] exceptConditions
        = [c | c: \except(_) <- conditions];
    list[Condition] prefixConditions
        = [c | c: \precede(_) <- conditions]
        + [c | c: \not-precede(_) <- conditions]
        + [c | c: \at-column(_) <- conditions]
        + [c | c: \begin-of-line() <- conditions];
    list[Condition] suffixConditions
        = [c | c: \follow(_) <- conditions]
        + [c | c: \not-follow(_) <- conditions]
        + [c | c: \end-of-line() <- conditions];
    list[Condition] deleteConditions
        = [c | c: \precede(_) <- conditions];
    
    Maybe[RegExp] ret = toRegExp(e, symbol);

    // 1. Convert `\except` conditions
    if (!isEmpty(exceptConditions)) {
        if (/\choice(symbol, alternatives) := e) {
            bool except(prod(label(l, _), _, _)) = \except(l) <- exceptConditions;
            bool except(prod(def, _, _)) = false when label(_, _) !:= def;
            ret = toRegExp(e, \choice(symbol, {a | a <- alternatives, !except(a)}));
        } else {
            ret = nothing();
        }
    }

    // 2. Convert prefix conditions
    if (!isEmpty(prefixConditions)) {
        ret = infix("", toRegExps(e, prefixConditions) + [ret]);
    }

    // 3. Convert suffix conditions
    if (!isEmpty(suffixConditions)) {
        ret = infix("", [ret] + toRegExps(e, suffixConditions));
    }

    // 4. Convert `\delete` conditions
    if (!isEmpty(deleteConditions)) {
        Maybe[RegExp] delete = infix("|", [toRegExp(e, s) | \delete(s) <- deleteConditions]);
        if (just(regExp(string1, categories1)) := ret, just(regExp(string2, categories2)) := delete) {
            str string = "(?=(?\<head\><string1>)(?\<tail\>.*)$)(?!(?:<string2>)\\k\<tail\>$)\\k\<head\>";
            list[str] categories = ["", *categories1, "", *categories2];
            ret = just(regExp(string, categories));
        } else {
            ret = nothing();
        }
    }

    return ret;
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
    = nothing();
Maybe[RegExp] toRegExp(Env _, \at-column(n))
    = just(regExp("(?\<=$<right("", n, ".")>)", []));
Maybe[RegExp] toRegExp(Env _, \begin-of-line())
    = just(regExp("(?:^)", []));
Maybe[RegExp] toRegExp(Env _, \end-of-line())
    = just(regExp("(?:$)", []));
Maybe[RegExp] toRegExp(Env _, \except(_))
    = nothing();

default Maybe[RegExp] toRegExp(Env _, Condition c) {
    println("[LOG] toRegExp: Unsupported condition <c>");
    return nothing();
}

@synopsis{
    Lookup a symbol in an environment.
}

Maybe[RegExp] lookup(Env e, s: \parameterized-sort(name, actual))
    = /\choice(\parameterized-sort(name, formal), alternatives) := e
    ? toRegExp(e, \choice(s, subst(alternatives, formal, actual)))
    : nothing();
Maybe[RegExp] lookup(Env e, s: \parameterized-lex(name, actual))
    = /\choice(\parameterized-lex(name, formal), alternatives) := e
    ? toRegExp(e, \choice(s, subst(alternatives, formal, actual)))
    : nothing();

default Maybe[RegExp] lookup(Env e, Symbol s)
    = /c: \choice(s, _) := e ? e[c] : nothing();

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