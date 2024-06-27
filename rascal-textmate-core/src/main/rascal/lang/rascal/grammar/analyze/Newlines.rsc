module lang::rascal::grammar::analyze::Newlines

import Grammar;
import ParseTree;
import String;

import lang::rascal::grammar::Util;

@synopsis{
    Checks if a set/list of values (presumably: productions, symbols, or
    conditions) has a newline character
}

bool haveNewline(Grammar g, set[value] values)
    = any(v <- values, hasNewline(g, v));
bool haveNewline(Grammar g, list[value] values)
    = any(v <- values, hasNewline(g, v));

@synopsis{
    Checks if a production has a newline character
}

bool hasNewline(Grammar g, prod(_, symbols, _))
    = haveNewline(g, symbols);

default bool hasNewline(Grammar _, Production p) {
    throw "Unsupported production <p>";
}

@synopsis{
    Checks if a symbol has a newline character
}

// `Type`
bool hasNewline(Grammar g, \label(_, symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \parameter(_, _))
    = false;

// `ParseTree`: Start
bool hasNewline(Grammar g, \start(symbol))
    = hasNewline(g, symbol);

// `ParseTree`: Non-terminals
bool hasNewline(Grammar g, s: \sort(_))
    = any(p <- lookup(g, s), hasNewline(g, p));
bool hasNewline(Grammar g, s: \lex(_))
    = any(p <- lookup(g, s), hasNewline(g, p));
bool hasNewline(Grammar g, s: \layouts(_))
    = any(p <- lookup(g, s), hasNewline(g, p));
bool hasNewline(Grammar g, s: \keywords(_))
    = any(p <- lookup(g, s), hasNewline(g, p));
bool hasNewline(Grammar g, s: \parameterized-sort(_, _))
    = any(p <- lookup(g, s), hasNewline(g, p));
bool hasNewline(Grammar g, s: \parameterized-lex(_, _))
    = any(p <- lookup(g, s), hasNewline(g, p));

// `ParseTree`: Terminals
bool hasNewline(Grammar _, \lit(string))
    = hasNewline(string);
bool hasNewline(Grammar _, \cilit(string))
    = hasNewline(string);
bool hasNewline(Grammar _, \char-class(ranges))
    = any(r <- ranges, hasNewline(r));

// `ParseTree`: Regular expressions
bool hasNewline(Grammar _, \empty())
    = false;
bool hasNewline(Grammar g, \opt(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \iter(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \iter-star(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \iter-seps(symbol, separators))
    = haveNewline(g, [symbol] + separators);
bool hasNewline(Grammar g, \iter-star-seps(symbol, separators))
    = haveNewline(g, [symbol] + separators);
bool hasNewline(Grammar g, \alt(alternatives))
    = haveNewline(g, alternatives);
bool hasNewline(Grammar g, \seq(symbols))
    = haveNewline(g, symbols);

// `ParseTree`: Conditional
bool hasNewline(Grammar g, \conditional(symbol, conditions))
    = hasNewline(g, symbol) || haveNewline(g, conditions);

default bool hasNewline(Grammar _, Symbol s) {
    throw "Unsupported symbol <s>";
}

@synopsis{
    Checks if a condition is single-line
}

bool hasNewline(Grammar g, \follow(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \not-follow(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \precede(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \not-precede(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar g, \delete(symbol))
    = hasNewline(g, symbol);
bool hasNewline(Grammar _, \at-column(_))
    = false;
bool hasNewline(Grammar _, \begin-of-line())
    = false;
bool hasNewline(Grammar _, \end-of-line())
    = false;
bool hasNewline(Grammar _, \except(_))
    = false;

default bool hasNewline(Grammar _, Condition c) {
    throw "Unsupported condition <c>";
}

@synopsis{
    Checks if a string/character range has a newline character
}

// TODO: Check which other characters are newline characters for TextMate

bool hasNewline(str s)
    = LF in chars(s);
bool hasNewline(range(begin, end))
    = begin <= LF && LF <= end;

int LF = 10;