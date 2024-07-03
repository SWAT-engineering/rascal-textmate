module lang::rascal::grammar::analyze::Newlines

import Grammar;
import ParseTree;
import String;

import lang::rascal::grammar::Util;

@synopsis{
    Checks if a production has a newline character
}

bool hasNewline(Grammar g, prod(_, symbols, _)) {
    set[Symbol] nonTerminals = {s | /Symbol s := symbols, isNonTerminalType(s)};
    return any(/r: range(_, _) := symbols, hasNewline(r)) ||
        any(s <- nonTerminals, Production p <- lookup(g, s), hasNewline(g, p));
}

@synopsis{
    Checks if a string/character range has a newline character
}

// TODO: Check which other characters are newline characters for TextMate
// TODO: Use `analysis::grammars::LOC` instead?

bool hasNewline(str s)
    = LF in chars(s);
    
bool hasNewline(range(begin, end))
    = begin <= LF && LF <= end;

int LF = 10;