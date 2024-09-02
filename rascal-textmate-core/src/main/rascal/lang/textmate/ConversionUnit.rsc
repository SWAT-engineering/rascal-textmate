@synopsis{
    Types and functions to represent conversion units from Rascal grammars
    to TextMate grammars
}

module lang::textmate::ConversionUnit

import Grammar;
import ParseTree;
import util::Maybe;

import lang::rascal::grammar::analyze::Delimiters;
import lang::textmate::ConversionConstants;
import lang::textmate::Grammar;
import lang::textmate::NameGeneration;

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
    Retains from set `units` each unit that is a prefix (i.e., the symbols of
    its production) of any other unit in `units`
}

set[ConversionUnit] retainStrictPrefixes(set[ConversionUnit] units)
    = {u1 | u1 <- units, any(u2 <- units, u1 != u2, isStrictPrefix(u1, u2))};

@synopsis{
    Removes from set `units` each units that is a prefix (i.e., the symbols of
    its production) of any other unit in `units`
}

set[ConversionUnit] removeStrictPrefixes(set[ConversionUnit] units)
    = units - retainStrictPrefixes(units);

@synopsis{
    Checks if unit `u1` is a strict prefix of unit `u2`
}

bool isStrictPrefix(ConversionUnit u1, ConversionUnit u2)
    = isStrictPrefix(u1.prod.symbols, u2.prod.symbols);

// TODO: This function could be moved to a separate, generic module
private bool isStrictPrefix([], [])
    = false;
private bool isStrictPrefix([], [_, *_])
    = true;
private bool isStrictPrefix([_, *_], [])
    = false;
private bool isStrictPrefix([head1, *tail1], [head2, *tail2])
    = head1 == head2 && isStrictPrefix(tail1, tail2);