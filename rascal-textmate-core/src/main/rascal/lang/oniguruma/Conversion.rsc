module lang::oniguruma::Conversion

import Grammar;
import List;
import ParseTree;
import Set;
import String;

import lang::oniguruma::RegExp;
import lang::rascal::grammar::Util;

@synopsis{
    Converts a set/list of values (presumably: productions, symbols, or
    conditions) to a list of regular expressions.
}

list[RegExp] toRegExps(Grammar g, set[value] values)
    = [toRegExp(g, v) | v <- values];
list[RegExp] toRegExps(Grammar g, list[value] values)
    = [toRegExp(g, v) | v <- values];

@synopsis{
    Converts a production to a regular expression.
}

RegExp toRegExp(Grammar g, prod(_, symbols, /\tag("category"(c))))
    = group(infix("", toRegExps(g, symbols)), category=c);
RegExp toRegExp(Grammar g, prod(_, symbols, attributes))
    = infix("", toRegExps(g, symbols)) when /\tag("category"(_)) !:= attributes;

default RegExp toRegExp(Grammar _, Production p) {
    throw "Unsupported production <p>";
}

@synopsis{
    Converts a symbol to a regular expression.
}

// `Type`
RegExp toRegExp(Grammar g, label(_, symbol))
    = toRegExp(g, symbol);
RegExp toRegExp(Grammar g, parameter(_, _))
    = nil(); // Covered by `lookup` (which substitutes actuals for formals)

// `ParseTree`: Start
RegExp toRegExp(Grammar g, \start(symbol))
    = toRegExp(g, symbol);

// `ParseTree`: Non-terminals
RegExp toRegExp(Grammar g, s: \sort(_)) 
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);
RegExp toRegExp(Grammar g, s: \lex(_))
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);
RegExp toRegExp(Grammar g, s: \layouts(_))
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);
RegExp toRegExp(Grammar g, s: \keywords(_))
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);
RegExp toRegExp(Grammar g, s: \parameterized-sort(_, _))
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);
RegExp toRegExp(Grammar g, s: \parameterized-lex(_, _))
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]);

// `ParseTree`: Terminals
RegExp toRegExp(Grammar _, \lit(string))
    = regExp("(?:<toCodeUnits(chars(string), bound = /^\w+$/ := string)>)", []);
RegExp toRegExp(Grammar _, \cilit(string))
    = regExp("(?i:<toCodeUnits(chars(string), bound = /^\w+$/ := string)>)", []);
RegExp toRegExp(Grammar g, \char-class(ranges))
    = infix("|", toRegExps(g, ranges));

// `ParseTree`: Regular expressions
RegExp toRegExp(Grammar _, \empty())
    = nil();
RegExp toRegExp(Grammar g, \opt(symbol))
    = suffix("??", toRegExp(g, symbol));
RegExp toRegExp(Grammar g, \iter(symbol))
    = suffix("+?", toRegExp(g, symbol));
RegExp toRegExp(Grammar g, \iter-star(symbol))
    = suffix("*?", toRegExp(g, symbol));
RegExp toRegExp(Grammar g, Symbol s: \iter-seps(_, _))
    = toRegExp(g, expand(s));
RegExp toRegExp(Grammar g, Symbol s: \iter-star-seps(_, _))
    = toRegExp(g, expand(s));
RegExp toRegExp(Grammar g, \alt(alternatives))
    = infix("|", toRegExps(g, alternatives));
RegExp toRegExp(Grammar g, \seq(symbols))
    = infix("", toRegExps(g, symbols));

// `ParseTree`: Condition
RegExp toRegExp(Grammar g, \conditional(symbol, conditions)) {

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
    
    RegExp ret = toRegExp(g, symbol);

    // 1. Convert `\except` conditions
    if (!isEmpty(exceptConditions)) {
        if (/\choice(symbol, alternatives) := g) {
            bool except(prod(label(l, _), _, _)) = \except(l) <- exceptConditions;
            bool except(prod(def, _, _)) = false when label(_, _) !:= def;
            ret = toRegExp(g, \choice(symbol, {a | a <- alternatives, !except(a)}));
        } else {
            ret = nil();
        }
    }

    // 2. Convert prefix conditions
    if (!isEmpty(prefixConditions)) {
        ret = infix("", toRegExps(g, prefixConditions) + [ret]);
    }

    // 3. Convert suffix conditions
    if (!isEmpty(suffixConditions)) {
        ret = infix("", [ret] + toRegExps(g, suffixConditions));
    }

    // 4. Convert `\delete` conditions
    if (!isEmpty(deleteConditions)) {
        RegExp delete = infix("|", [toRegExp(g, s) | \delete(s) <- deleteConditions]);
        if (regExp(string1, categories1) := ret, regExp(string2, categories2) := delete) {
            str string = "(?=(?\<head\><string1>)(?\<tail\>.*)$)(?!(?:<string2>)\\k\<tail\>$)\\k\<head\>";
            list[str] categories = ["", *categories1, "", *categories2];
            ret = regExp(string, categories);
        } else {
            ret = nil();
        }
    }

    return ret;
}

default RegExp toRegExp(Grammar _, Symbol s) {
    throw "Unsupported symbol <s>";
}

@synopsis{
    Converts a condition to a regular expression.
}

RegExp toRegExp(Grammar g, \follow(symbol))
    = prefix("(?=", suffix(")", toRegExp(g, symbol)));
RegExp toRegExp(Grammar g, \not-follow(symbol))
    = prefix("(?!", suffix(")", toRegExp(g, symbol)));
RegExp toRegExp(Grammar g, \precede(symbol))
    = prefix("(?\<=", suffix(")", toRegExp(g, symbol)));
RegExp toRegExp(Grammar g, \not-precede(symbol))
    = prefix("(?\<!", suffix(")", toRegExp(g, symbol)));
RegExp toRegExp(Grammar g, \delete(symbol))
    = nil(); // Covered by `toRegExp(Grammar g, \conditional(symbol, conditions))`
RegExp toRegExp(Grammar _, \at-column(n))
    = regExp("(?\<=$<right("", n, ".")>)", []);
RegExp toRegExp(Grammar _, \begin-of-line())
    = regExp("(?:^)", []);
RegExp toRegExp(Grammar _, \end-of-line())
    = regExp("(?:$)", []);
RegExp toRegExp(Grammar _, \except(_))
    = nil(); // Covered by `toRegExp(Grammar g, \conditional(symbol, conditions))`

default RegExp toRegExp(Grammar _, Condition c) {
    throw "Unsupported condition <c>";
}

@synopsis{
    Converts a character range to a regular expression.
}

RegExp toRegExp(Grammar _, range(begin, end))
    = regExp("[<toCodeUnit(begin)>-<toCodeUnit(end)>]", []);

@synopsis{
    Converts a (list of) char(s) to a (list of) code unit(s).
}

str toCodeUnits(list[int] chars, bool bound = false)
    = bound
    ? "\\b<toCodeUnits(chars, bound = false)>\\b"
    : ("" | it + toCodeUnit(i) | i <- chars);

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