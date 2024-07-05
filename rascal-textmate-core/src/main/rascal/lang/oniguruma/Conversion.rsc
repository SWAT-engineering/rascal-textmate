module lang::oniguruma::Conversion

import Grammar;
import List;
import ParseTree;
import Set;
import String;
import lang::rascal::format::Escape;

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

RegExp toRegExp(Grammar g, prod(_, symbols, attributes)) {
    RegExp re = infix("", toRegExps(g, symbols)); // Empty separator for concatenation
    return /\tag("category"(c)) := attributes ? group(re, category = c) : re;
}

@synopsis{
    Converts a symbol to a regular expression.
}

// `Type`
RegExp toRegExp(Grammar g, \label(_, symbol))
    = toRegExp(g, symbol);
RegExp toRegExp(Grammar g, \parameter(_, _))
    = nil(); // Covered by `lookup` (which substitutes actuals for formals)

// `ParseTree`: Start
RegExp toRegExp(Grammar g, \start(symbol))
    = toRegExp(g, symbol);

// `ParseTree`: Non-terminals
RegExp toRegExp(Grammar g, Symbol s)
    = infix("|", [toRegExp(g, p) | p <- lookup(g, s)]) when isNonTerminalType(s);

// `ParseTree`: Terminals
RegExp toRegExp(Grammar _, \lit(string))
    = regExp("(?:<encode(chars(string), withBounds = /^\w+$/ := string)>)", []);
RegExp toRegExp(Grammar _, \cilit(string))
    = regExp("(?i:<encode(chars(string), withBounds = /^\w+$/ := string)>)", []);
RegExp toRegExp(Grammar g, \char-class(ranges))
    = infix("|", toRegExps(g, ranges));

// `ParseTree`: Regular expressions
RegExp toRegExp(Grammar _, \empty())
    = nil();
RegExp toRegExp(Grammar g, \opt(symbol))
    = suffix("??", toRegExp(g, symbol)); // Reluctant quantifier
RegExp toRegExp(Grammar g, \iter(symbol))
    = suffix("+?", toRegExp(g, symbol)); // Reluctant quantifier
RegExp toRegExp(Grammar g, \iter-star(symbol))
    = suffix("*?", toRegExp(g, symbol)); // Reluctant quantifier
RegExp toRegExp(Grammar g, Symbol s: \iter-seps(_, _))
    = toRegExp(g, expand(s));
RegExp toRegExp(Grammar g, Symbol s: \iter-star-seps(_, _))
    = toRegExp(g, expand(s));
RegExp toRegExp(Grammar g, \alt(alternatives))
    = infix("|", toRegExps(g, alternatives));
RegExp toRegExp(Grammar g, \seq(symbols))
    = infix("", toRegExps(g, symbols)); // Empty separator for concatenation

// `ParseTree`: Condition
RegExp toRegExp(Grammar g, \conditional(symbol, conditions)) {
    RegExp re = toRegExp(g, symbol);

    // Define four kinds of conditions (and convert them in a particular order)
    exceptConditions = [c | c <- conditions, isExceptCondition(c)];
    prefixConditions = [c | c <- conditions, isPrefixCondition(c)];
    suffixConditions = [c | c <- conditions, isSuffixCondition(c)];
    deleteConditions = [c | c <- conditions, isDeleteCondition(c)];
    
    // Convert except conditions (depends on previous conersion)
    if (!isEmpty(exceptConditions)) {
        if (/\choice(symbol, alternatives) := g) {

            bool keep(prod(def, _, _))
                = \label(l, _) := def
                ? \except(l) notin exceptConditions
                : true;
            
            re = infix("|", toRegExps(g, {a | a <- alternatives, keep(a)}));
        } else {
            re = nil(); // Indicates failure
        }
    }

    // Convert prefix conditions (depends on previous conversions)
    if (!isEmpty(prefixConditions)) {
        re = infix("", toRegExps(g, prefixConditions) + [re]);
    }

    // Convert suffix conditions (depends on previous conversions)
    if (!isEmpty(suffixConditions)) {
        re = infix("", [re] + toRegExps(g, suffixConditions));
    }

    // Convert delete conditions (depends on previous conversions)
    if (!isEmpty(deleteConditions)) {
        RegExp delete = infix("|", [toRegExp(g, s) | \delete(s) <- deleteConditions]);
        if (regExp(string1, categories1) := re, regExp(string2, categories2) := delete) {
            
            // TODO: Explain this complicated conversion...
            str string = "(?=(?\<head\><string1>)(?\<tail\>.*)$)(?!(?:<string2>)\\k\<tail\>$)\\k\<head\>";
            list[str] categories = ["", *categories1, "", *categories2];
            re = regExp(string, categories);
        } else {
            re = nil(); // Indicates failure
        }
    }

    return re;
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
    = regExp("[<encode(begin)>-<encode(end)>]", []);

@synopsis{
    Encodes a (list of) char(s) to a (list of) code unit(s).
}

str encode(list[int] chars, bool withBounds = false)
    = withBounds
    ? "\\b<encode(chars, withBounds = false)>\\b"
    : intercalate("", [encode(i) | i <- chars]);

str encode(int i)
    = makeStringChar(i);