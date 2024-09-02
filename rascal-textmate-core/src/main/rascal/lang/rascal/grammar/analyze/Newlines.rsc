@synopsis{
    Functions to analyze presence/absence of newline characters in productions
}

module lang::rascal::grammar::analyze::Newlines

import Grammar;
import ParseTree;
import String;
import util::Maybe;

import lang::rascal::grammar::Util;
import util::MaybeUtil;

@synopsis{
    Representation of a *newline-free* segment of symbols
}

alias Segment = list[Symbol];

@synopsis{
    Gets the (newline-free) segments of a production/list of symbols in grammar
    `g`, separated by symbols that have a newline (not part of any segment),
    recursively for non-terminals. For instance, the segments of
    `[lit("foo"), lit("bar"), lit("\n"), lit("baz")]` are:
      - `[lit("foo"), lit("bar")]`;
      - `[lit("baz")]`.
}

set[Segment] getSegments(Grammar g, Production p) {
    return unmaybe(getSegmentsByProduction(g)[p]);
}

set[Segment] getSegments(Grammar g, list[Symbol] symbols) {
    map[Production, Maybe[set[Segment]]] env = getSegmentsByProduction(g);
    return unmaybe(getSegmentsWithEnvironment(g, symbols, env));
}

@memo
private map[Production, Maybe[set[Segment]]] getSegmentsByProduction(Grammar g) {
    map[Production, Maybe[set[Segment]]] ret = (p : nothing() | /p: prod(_, _, _) := g);

    solve (ret) {
        for (p <- ret, nothing() == ret[p]) {
            ret[p] = getSegmentsWithEnvironment(g, p.symbols, ret);
        }
    }

    return ret;
}

private Maybe[set[Segment]] getSegmentsWithEnvironment(
        Grammar g, list[Symbol] symbols, 
        map[Production, Maybe[set[Segment]]] env) {

    // General idea: Recursively traverse `symbols` from left to right, while
    // keeping track of a "running segment" (initially empty). Each time a
    // symbol that has a newline is encountered, finish/collect the running
    // segment, and start a new one for the remainder of `symbols`.

    // Final case: No symbols remaining
    Maybe[set[Segment]] get(Segment runningSegment, []) {
        return just(_ <- runningSegment ? {runningSegment} : {});
    }

    // Recursive case: At least one symbol remaining
    Maybe[set[Segment]] get(Segment segment, [Symbol head, *Symbol tail]) {
        set[Symbol] nested = {s | /Symbol s := head};
        
        // If the head contains a non-terminal, then: (1) finish the running
        // segment; (2) lookup the segments of the non-terminals in the
        // environment, if any; (3) compute the segments of the tail. Return the
        // union of 1-3.
        if (any(s <- nested, isNonTerminalType(s))) {

            list[Maybe[set[Segment]]] sets
                = [get(segment, [])] // (1)
                + [env[p] | s <- nested, isNonTerminalType(s), p <- lookup(g, s)] // (2)
                + [get([], tail)]; // (3)
            
            return (sets[0] | union(it, \set) | \set <- sets[1..]);
        }
        
        // If the head doesn't contain a non-terminal, but it has a newline,
        // then: (1) finish the running segment; (2) compute the segments of the
        // tail. Return the union of 1-2. Note: the head, as it has a newline,
        // is ignored and won't be part of any segment.
        else if (any(s <- nested, hasNewline(g, s))) {
            return union(get(segment, []), get([], tail));
        }
        
        // If the head doesn't contain a non-terminal, and if it doesn't have a
        // newline, then add the head to the running segment and proceed with
        // the tail.
        else {
            return get(segment + head, tail);
        }
    }

    return get([], symbols);
}

@synopsis{
    Checks if a symbol has a newline character
}

bool hasNewline(Grammar g, Symbol s) {
    return any(p <- lookup(g, delabel(s)), hasNewline(g, p));
}

@synopsis{
    Checks if a production has a newline character
}

bool hasNewline(Grammar g, Production p) {
    return hasNewlineByProduction(g)[p];
}

@memo
private map[Production, bool] hasNewlineByProduction(Grammar g) {
    map[Production, bool] ret = (p: false | /p: prod(_, _, _) := g);

    solve (ret) {
        for (p <- ret, !ret[p]) {
            set[Symbol] nonTerminals = {s | /Symbol s := p.symbols, isNonTerminalType(s)};
            ret[p] = ret[p] || any(/r: range(_, _) := p.symbols, hasNewline(r))
                            || any(s <- nonTerminals, Production child <- lookup(g, s), ret[child]);
        }
    }

    return ret;
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

private int LF = 10;