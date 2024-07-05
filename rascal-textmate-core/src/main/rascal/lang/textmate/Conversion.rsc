@synopsis{
    Types and functions to transform Rascal grammars to TextMate grammars
}

module lang::textmate::Conversion

import Grammar;
import IO;
import ParseTree;
import Set;

import lang::oniguruma::Conversion;
import lang::oniguruma::RegExp;
import lang::rascal::grammar::Util;
import lang::rascal::grammar::analyze::Delimiters;
import lang::rascal::grammar::analyze::Dependencies;
import lang::rascal::grammar::analyze::Newlines;
import lang::textmate::Grammar;

alias RscGrammar = Grammar;

data ConversionUnit = unit(
    RscGrammar rsc,
    Production prod);

@synopsis{
    Converts Rascal grammar `rsc` to a TextMate grammar
}

@description{
    The conversion consists of two stages:
      - analysis (function `analyze`);
      - transformation (function `transform`).

    The aim of the analysis stage is to select those productions of the Rascal
    grammar that are "suitable for conversion" to TextMate rules. The aim of the
    transformation stage is to subsequently convert those productions and
    produce a TextMate grammar.

    To be able to cleanly separate analysis and transformation, productions
    selected during the analysis stage are wrapped into *conversion units* that
    may contain additional meta-data needed during the transformation stage.
}

TmGrammar toTmGrammar(RscGrammar rsc, ScopeName scopeName)
    = transform(analyze(rsc)) [scopeName = scopeName];

@synoposis{
    Analyzes Rascal grammar `rsc`. Returns a list of productions, in the form of
    conversion units, consisting of:
      - one synthetic *delimiters* production;
      - zero-or-more *user-defined* productions (from `rsc`);
      - one synthetic *keywords* production.
    
    Each production in the list (including the synthetic ones) is *suitable for
    conversion* to a TextMate rule. A production is "suitable for conversion"
    when it satisfies each of the following conditions:
      - it is non-recursive;
      - it does not match newlines;
      - it does not match the empty word;
      - it has a `@category` tag.
    
    See the walkthrough for further motivation and examples.
}

@description{
    The analysis consists of three stages:
      1. selection of user-defined productions;
      2. creation of synthetic delimiters production;
      3. creation of synthetic keywords production.

    In stage 1, a dependency graph among all productions that occur in `rsc`
    (specifically: `prod` constructors) is created. This dependency graph is
    subsequently pruned to keep only the suitable-for-conversion productions:
      - first, productions with a cyclic dependency on themselves are removed;
      - next, productions that only involve single-line matching are filtered;
      - next, productions that only involve non-empty word matching are filtered;
      - next, productions that have a `@category` tag are filtered.

    In stage 2, the set of all delimiters that occur in `rsc` is created. This
    set is subsequently reduced by removing:
      - strict prefixes of delimiters;
      - delimiters that enclose user-defined productions;
      - delimiters that occur at the beginning of user-defined productions.

    In stage 3, the set of all keywords that occur in `rsc` is created.
}

list[ConversionUnit] analyze(RscGrammar rsc) {

    // Define auxiliary predicates
    bool isCyclic(Production p, set[Production] ancestors, _)
        = p in ancestors;
    bool isSingleLine(Production p, _, _)
        = !hasNewline(rsc, p);
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;

    // Analyze dependencies among productions
    println("[LOG] Analyzing dependencies among productions");
    Dependencies dependencies = deps(toGraph(rsc));
    list[Production] prods = dependencies
        .removeProds(isCyclic, true) // `true` means "also remove ancestors"
        .filterProds(isSingleLine)
        .filterProds(isNonEmpty)
        .filterProds(hasCategory)
        .getProds();

    // Analyze delimiters
    println("[LOG] Analyzing delimiters");
    set[Symbol] delimiters = {s | /Symbol s := rsc, isDelimiter(delabel(s))};
    delimiters -= getStrictPrefixes(delimiters);
    delimiters -= {s | prod(_, [s, *_], _) <- prods, isDelimiter(delabel(s))};
    delimiters -= {s | prod(def, _, _) <- prods, /s := getDelimiterPairs(rsc, delabel(def))};
    list[Production] prodsDelimiters = [prod(lex("delimiters"), [\alt(delimiters)], {})];

    // Analyze keywords
    println("[LOG] Analyzing keywords");
    set[Symbol] keywords = {s | /Symbol s := rsc, isKeyword(delabel(s))};
    list[Production] prodsKeywords = [prod(lex("keywords"), [\alt(keywords)], {\tag("category"("keyword.control"))})];

    // Return
    bool isEmptyProd(prod(_, [\alt(alternatives)], _)) = isEmpty(alternatives);
    list[ConversionUnit] units
        = [unit(rsc, p) | p <- prodsDelimiters, !isEmptyProd(p)]
        + [unit(rsc, p) | p <- prods]
        + [unit(rsc, p) | p <- prodsKeywords, !isEmptyProd(p)];

    return units;
}

@synopsis{
    Transforms a list of productions, in the form of conversion units, to a
    TextMate grammar
}

@description{
    The transformation consists of two stages:
      1. creation of TextMate rules;
      2. composition of TextMate rules into a TextMate grammar.
}

TmGrammar transform(list[ConversionUnit] units) {

    // Transform productions to rules
    println("[LOG] Transforming productions to rules");
    list[TmRule] rules = [toTmRule(u) | u <- units];

    // Transform rules to grammar
    println("[LOG] Transforming rules to grammar");
    TmGrammar tm = lang::textmate::Grammar::grammar((), "", []);
    for (r <- rules) {
        // If the repository already contains a rule with the same name as `r`,
        // then: (1) the patterns of that "old" rule must be combined with the
        // patterns of the "new" rule; (2) the new rule replaces the old rule.
        if (tm.repository[r.name]?) {
            TmRule old = tm.repository[r.name];
            TmRule new = r;
            r = r[patterns = old.patterns + new.patterns];
        }
        tm = addRule(tm, r);
    }

    // Return
    return tm[patterns = tm.patterns];
}

@synopsis{
    Converts a conversion unit to a TextMate rule
}

TmRule toTmRule(ConversionUnit u)
    = toTmRule(u.rsc, u.prod);

// TODO: Check if the size of rule names materially affects VS Code. Currently,
// we use stringified productions as names, which is quite useful for debugging,
// but maybe it leads to performance issues. If so, we should add a conversion
// configuration flag to control generation of "long names" vs "short names" (as
// long as names continue to be unique, everything should continue to work ok).

private TmRule toTmRule(RscGrammar rsc, p: prod(def, _, _))
    = {<begin, end>} := getDelimiterPairs(rsc, delabel(def)) // TODO: Support non-singleton sets of delimiter pairs
    ? toTmRule(toRegExp(rsc, begin), toRegExp(rsc, end), "<begin>:<end>", [toTmRule(toRegExp(rsc, p), "<p>")])
    : toTmRule(toRegExp(rsc, p), "<p>");

private TmRule toTmRule(RegExp re, str name)
    = match(re.string, captures = toCaptures(re.categories), name = name);

private TmRule toTmRule(RegExp begin, RegExp end, str name, list[TmRule] patterns)
    = beginEnd(begin.string, end.string, name = name, patterns = patterns);