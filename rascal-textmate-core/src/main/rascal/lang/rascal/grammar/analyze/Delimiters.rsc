module lang::rascal::grammar::analyze::Delimiters

import Grammar;
import ParseTree;
import Set;
import util::Maybe;

import lang::rascal::grammar::Util;

alias DelimiterPair = tuple[Symbol begin, Symbol end];

@synopsis{
    Gets all delimiter pairs that enclose symbol `s` in grammar `g`
}

set[DelimiterPair] getDelimiterPairs(Grammar g, Symbol s) {
    map[Symbol, set[DelimiterPair]] index = ();

    set[DelimiterPair] getDelimiterPairs(Symbol s) {
        if (s in index) {
            return index[s];
        } else {
            index += (s: {});
        }

        set[DelimiterPair] pairs = {};
        for (/prod(def, symbols: [*_, /s, *_], _) := g) {

            set[DelimiterPair] morePairs
                = just(DelimiterPair pair) := getDelimiterPair(symbols, s)
                ? {pair}
                : getDelimiterPairs(delabel(def));
            
            if (isEmpty(morePairs)) {
                pairs = {};
                break;
            }
        }

        index += (s: pairs);
        return pairs;
    }

    return getDelimiterPairs(s);
}

@synopsis{
    Gets the delimiter pair that encloses symbol `s` in a list, if any
}

Maybe[DelimiterPair] getDelimiterPair([*_, Symbol begin, *between, Symbol end, *_], Symbol s)
    = just(<begin, end>) when
        isDelimiter(begin) && isDelimiter(end),
        [*between1, /s, *between2] := between,
        !containsDelimiter(between1 + between2);

default Maybe[DelimiterPair] getDelimiterPair(list[Symbol] _, Symbol _)
    = nothing();

@synopsis{
    Checks if a list contains a delimiter
}

bool containsDelimiter(list[Symbol] symbols)
    = any(s <- symbols, isDelimiter(s));

@synopsis{
    Checks if a symbol is a delimiter
}

bool isDelimiter(lit(string))
    = true when /^\w+$/ !:= string;
bool isDelimiter(cilit(string))
    = true when /^\w+$/ !:= string;

default bool isDelimiter(Symbol _)
    = false;

@synopsis{
    Checks if a symbol is a keyword
}

bool isKeyword(lit(string))
    = true when /^\w+$/ := string;
bool isKeyword(cilit(string))
    = true when /^\w+$/ := string;

default bool isKeyword(Symbol _)
    = false;
