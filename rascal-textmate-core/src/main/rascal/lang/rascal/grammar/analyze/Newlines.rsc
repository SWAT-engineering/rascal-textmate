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
    Representation of a *newline-free* segment of symbols. A segment is
    *initial* when it occurs first in a production/list of symbols; it is
    *final* when it occurs last.
}

data Segment = segment(
    list[Symbol] symbols,
    bool initial = false,
    bool final = false);

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

    // Base case: No symbols remaining
    Maybe[set[Segment]] get(Segment running, [], bool final = true) {
        return just(_ <- running.symbols ? {running[final = final]} : {});
    }

    // Recursive case: At least one symbol remaining
    Maybe[set[Segment]] get(Segment running, [Symbol head, *Symbol tail]) {
        set[Symbol] nested = {s | /Symbol s := head};

        Maybe[set[Segment]] finished = get(running, [], final = tail == []);

        // If the head contains a non-terminal, then: (1) finish the running
        // segment; (2) look up the segments of the non-terminals in the
        // environment, if any; (3) compute the segments of the tail. Return the
        // union of 1-3.
        if (any(s <- nested, isNonTerminalType(s))) {
            list[Maybe[set[Segment]]] sets = [];

            // (1)
            sets += finished;

            // (2)
            sets += for (s <- nested, isNonTerminalType(s), p <- prodsOf(g, s)) {

                bool isInitial(Segment seg)
                    = seg.initial && running.initial && running.symbols == [];
                bool isFinal(Segment seg)
                    = seg.final && tail == [];
                Segment update(Segment seg)
                    = seg[initial = isInitial(seg)][final = isFinal(seg)];

                append just(segs) := env[p] ? just({update(seg) | seg <- segs}) : nothing();
            }

            // (3)
            sets += get(segment([]), tail);

            // Return union
            return (sets[0] | union(it, \set) | \set <- sets[1..]);
        }

        // If the head doesn't contain a non-terminal, but it has a newline,
        // then: (1) finish the running segment; (2) compute the segments of the
        // tail. Return the union of 1-2. Note: the head, as it has a newline,
        // is ignored and won't be part of any segment.
        else if (any(s <- nested, hasNewline(g, s))) {
            return union(finished, get(segment([]), tail));
        }

        // If the head doesn't contain a non-terminal, and if it doesn't have a
        // newline, then add the head to the running segment and proceed with
        // the tail.
        else {
            Segment old = running;
            Segment new = old[symbols = old.symbols + head];
            return get(new, tail);
        }
    }

    return get(segment([], initial = true), symbols);
}

@synopsis{
    Checks if a symbol has a newline character
}

bool hasNewline(Grammar g, Symbol s) {
    return any(p <- prodsOf(g, delabel(s)), hasNewline(g, p));
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
                            || any(s <- nonTerminals, Production child <- prodsOf(g, s), ret[child]);
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