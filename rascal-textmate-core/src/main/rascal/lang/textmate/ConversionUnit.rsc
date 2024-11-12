@license{
BSD 2-Clause License

Copyright (c) 2024, Swat.engineering

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}
@synopsis{
    Types and functions to represent conversion units from Rascal grammars
    to TextMate grammars
}

module lang::textmate::ConversionUnit

import Grammar;
import ParseTree;
import util::Math;
import util::Maybe;

import lang::rascal::grammar::Util;
import lang::rascal::grammar::analyze::Delimiters;
import lang::textmate::ConversionConstants;
import lang::textmate::Grammar;
import lang::textmate::NameGeneration;
import util::ListUtil;

@synopsis{
    Representation of a production in a Rascal grammar to be converted to a rule
    in a TextMate grammar
}

@description{
    Terminology:

      - The *inner delimiters* of a unit are those delimiters that occur at
        the beginning and at the ending of the content of the unit's production,
        if any.
      - The *outer delimiters* of a unit are those delimiters that occur at the
        ending and at the beginning of the enclosing context of the unit's
        production, if any.

      - The *inner rules* of a unit are patterns to detect the content of the
        unit's production, optionally based on its inner delimiters.
      - The *outer rules* of a unit are patterns to detect the enclosing context
        of the unit's production, mandatorily based on its outer delimiters.
    
      - The *top level rules* of a unit are:
          - its inner rules, if it doesn't have any outer rules;
          - its outer rules (in which all inner rules are nested), otherwise.
}

data ConversionUnit = unit(
    // The following parameters are set when a unit is created during analysis:
    Grammar rsc,
    Production prod,
    bool recursive,
    bool multiLine,
    DelimiterPair outerDelimiters,
    DelimiterPair innerDelimiters,

    // The following parameters are set when a unit is updated during
    // transformation:
    str name = "",
    list[TmRule] outerRules = [],
    list[TmRule] innerRules = []);

@synopsis{
    Gets the top-level rules of unit `u`
}

list[TmRule] getTopLevelRules(ConversionUnit u)
    = _ <- u.outerRules ? u.outerRules : u.innerRules;

@synopsis{
    Sorts list `units` in ascending order according to `isStrictlyLess`
}

list[ConversionUnit] sort(list[ConversionUnit] units)
    = sort(units, isStrictlyLess);

@synopsis{
    Checks if unit `u1` is strictly less than unit `u2`. In that case the rules
    of `u1` should occur before the rules of `u2` in any TextMate grammar that
    contains all those rules.
}

bool isStrictlyLess(ConversionUnit u1, ConversionUnit u2) {
    if (u1 == u2) {
        return false;
    }

    // Special cases:
    //   - delimiters production (synthetic) before user-defined productions;
    //   - user-defined productions before keywords production (synthetic).

    if (u1.prod.def.name == DELIMITERS_PRODUCTION_NAME) {
        return true;
    }
    if (u2.prod.def.name == DELIMITERS_PRODUCTION_NAME) {
        return false;
    }
    if (u1.prod.def.name == KEYWORDS_PRODUCTION_NAME) {
        return false;
    }
    if (u2.prod.def.name == KEYWORDS_PRODUCTION_NAME) {
        return true;
    }

    // Normal cases:
    //  - sort by `begin` delimiter;
    //  - if equal, then sort by production name;
    //  - if equal, then sort by stringified production.

    for (<keygen, compare> <- sorters) {
        str key1 = keygen(u1);
        str key2 = keygen(u2);
        if (key1 != key2) {
            return compare(key1, key2);
        }
    }

    return "<u1>" < "<u2>"; // Fallback
}

private alias Keygen  = str(ConversionUnit);
private alias Compare = bool(str, str);

private str getDelimiterKey(ConversionUnit u) // `Keygen`
    = <just(begin), _> := u.outerDelimiters ? begin.string
    : <just(begin), _> := u.innerDelimiters ? begin.string
    : ""
    ;

private str getProductionNameKey(ConversionUnit u) // `Keygen`
    = toName(u.prod.def);

private str getStringifiedProduction(ConversionUnit u) // `Keygen`
    = "<u.prod>";

private list[tuple[Keygen, Compare]] sorters = [

    // Sort by `begin` delimiter (e.g., "//" before "/")
    <getDelimiterKey,          bool(str s1, str s2) { return s1 > s2; }>,

    // Sort by production name (e.g., "comment.block" before "comment.line")
    <getProductionNameKey,     bool(str s1, str s2) { return s1 < s2; }>,

    // Sort by stringified production
    <getStringifiedProduction, bool(str s1, str s2) { return s1 < s2; }>
];

@synopsis{
    Retains from set `units` each unit that is a prefix (i.e., the list of
    symbols of its production) of any other unit in `units`
}

set[ConversionUnit] retainStrictPrefixes(set[ConversionUnit] units)
    = {u1 | u1 <- units, any(u2 <- units, u1 != u2, isStrictPrefix(u1, u2))};

@synopsis{
    Removes from set `units` each units that is a prefix (i.e., the list of
    symbols of its production) of any other unit in `units`
}

set[ConversionUnit] removeStrictPrefixes(set[ConversionUnit] units)
    = units - retainStrictPrefixes(units);

@synopsis{
    Checks if unit `u1` is a strict prefix of unit `u2`
}

bool isStrictPrefix(ConversionUnit u1, ConversionUnit u2)
    = isStrictPrefix(u1.prod.symbols, u2.prod.symbols);

@synopsis{
    Representation of a *decomposition* of a list of units (i.e., the lists of
    symbols of their productions) into their maximally common *prefix*
    (non-recursive) and their minimally disjoint *suffixes*. See also function
    `decompose`.
}

@description{
    For instance, consider the following lists of symbols:
      - `[lit("foo"), lit("bar"), lit("baz")]`;
      - `[lit("foo"), lit("bar"), lit("qux"), lit("quux")]`.
    
    The maximally common prefix is `[lit("foo"), lit("bar")]`. The minimally
    disjoint suffixes are `[lit("baz")]` and `[lit("qux"), lit("quux")]]`.
}

alias Decomposition = tuple[
    list[Symbol] prefix,
    list[list[Symbol]] suffixes
];

@synopsis{
    Decomposes list `units`. See also type `Decomposition`.
}

Decomposition decompose(list[ConversionUnit] units) {
    list[Symbol] prefix = [];
    list[list[Symbol]] suffixes = [];

    list[Production] prods    = [u.prod | u <- units];
    set[Grammar]     grammars = {u.rsc  | u <- units};

    if (_ <- prods && {rsc} := grammars) {
        list[int] sizes = [size(p.symbols) | p <- prods];
        int n = (sizes[0] | min(it, size) | size <- sizes[1..]);

        // Compute prefix (at most of size `n`)
        prefix = for (i <- [0..n]) {
            set[Symbol] iths = {p.symbols[i] | p <- prods};
            if ({ith} := iths && !isRecursive(rsc, delabel(ith))) {
                append ith;
            } else {
                break;
            }
        }

        // Compute suffixes
        suffixes = for (p <- prods) {
            list[Symbol] suffix = p.symbols[size(prefix)..];
            if (_ <- suffix) {
                append suffix;
            }
        }
    }

    return <prefix, suffixes>;    
}