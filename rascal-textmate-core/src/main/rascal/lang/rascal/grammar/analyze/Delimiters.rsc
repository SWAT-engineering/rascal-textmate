module lang::rascal::grammar::analyze::Delimiters

import Grammar;
import ParseTree;
import Set;
import util::Maybe;

import lang::rascal::grammar::Util;

@synopsis{
    Gets all delimiter pairs that enclose symbol `s` in grammar `g` when `s` is
    always enclosed by delimiters. Returns the empty set when at least one
    occurrence of `s` in `g` is not enclosed by delimiters.
}

alias DelimiterPair = tuple[Symbol begin, Symbol end];

set[DelimiterPair] getDelimiterPairs(Grammar g, Symbol s) {
    map[Symbol, set[DelimiterPair]] index = ();

    set[DelimiterPair] getDelimiterPairs(Symbol s) {
        set[DelimiterPair] pairs = {};
        index += (s: pairs); // Provisionally added for cycle detection

        // For each production in which `s` occurs, search for delimiter pairs
        // that enclose `s`.
        for (/prod(sParent, symbols: [*_, /s, *_], _) := g) {

            // Case 1: The production itself has enclosing delimiters for `s`
            if (just(DelimiterPair pair) := getDelimiterPair(symbols, s)) {
                pairs += {pair};
            }
            
            // Case 2: The production itself does not have enclosing delimiters
            // for `s`. In this case, proceed by searching for delimiter pairs
            // that enclose the parent of `s`.
            else {

                // Case 2a: `sParent` is already being searched for (i.e., there
                // is a cyclic dependency). In this case, `sParent` can be
                // ignored by the present call of this function (top of the call
                // stack), as it is already dealt with by a past/ongoing call of
                // this function (middle of the call stack).
                if (delabel(sParent) in index) {
                    continue;
                }
                
                // Case 2b: `sParent` has delimiter pairs
                else if (morePairs := getDelimiterPairs(delabel(sParent)), !isEmpty(morePairs)) {
                    pairs += morePairs;
                }
                
                // Case 2c: `sParent` does not have delimiter pairs. In this
                // case, at least one occurrence of `s` in `g` is not enclosed
                // by delimiters. Thus, the empty set is returned (and
                // registered in the index), while the remaining productions in
                // which `s` occurs, are ignored.
                else {
                    pairs = {};
                    break;
                }
            }
        }

        index += (s: pairs); // Definitively added 
        return pairs;
    }

    return getDelimiterPairs(s);

    // TODO: The current version of this function does not find delimiter pairs
    // that are spread across multiple productions. For instance:
    //
    // ```
    // lexical DelimitedNumber = Left Number Right;
    //
    // lexical Left   = "<";
    // lexical Right  = ">";
    // lexical Number = [0-9]+ !>> [0-9];
    // ```
    //
    // In this example, `getDelimiterPairs(lex("Number"))` returns the empty
    // set. This could be further improved.
}

@synopsis{
    Gets the delimiter pair that encloses symbol `s` in a list, if any
}

Maybe[DelimiterPair] getDelimiterPair([*_, Symbol begin, *between, Symbol end, *_], Symbol s)
    = just(<begin, end>)
    when isDelimiter(begin) && isDelimiter(end),
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
    = /^\w+$/ !:= string;
bool isDelimiter(cilit(string))
    = /^\w+$/ !:= string;

default bool isDelimiter(Symbol _)
    = false;

@synopsis{
    Checks if a symbol is a keyword
}

bool isKeyword(lit(string))
    = /^\w+$/ := string;
bool isKeyword(cilit(string))
    = /^\w+$/ := string;

default bool isKeyword(Symbol _)
    = false;
