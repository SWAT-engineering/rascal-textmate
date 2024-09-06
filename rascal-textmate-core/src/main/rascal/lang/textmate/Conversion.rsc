@synopsis{
    Types and functions to convert Rascal grammars to TextMate grammars
}

module lang::textmate::Conversion

import Grammar;
import IO;
import ParseTree;
import String;
import util::Maybe;

import lang::oniguruma::Conversion;
import lang::oniguruma::RegExp;
import lang::rascal::grammar::Util;
import lang::rascal::grammar::analyze::Delimiters;
import lang::rascal::grammar::analyze::Dependencies;
import lang::rascal::grammar::analyze::Newlines;
import lang::rascal::grammar::analyze::Symbols;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionUnit;
import lang::textmate::Grammar;
import lang::textmate::NameGeneration;

alias RscGrammar = Grammar;

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

TmGrammar toTmGrammar(RscGrammar rsc, ScopeName scopeName, NameGeneration nameGeneration = long())
    = transform(analyze(preprocess(rsc)), nameGeneration = nameGeneration) [scopeName = scopeName];

@synopsis{
    Preprocess Rascal grammar `rsc` to make it suitable for analysis and
    transformation
}

RscGrammar preprocess(RscGrammar rsc) {
    // Replace occurrences of singleton ranges with just the corresponding
    // literal. This makes it easier to identify delimiters.
    return visit (rsc) {
        case s: \char-class([range(char, char)]) => d
            when d := \lit("<stringChar(char)>"), isDelimiter(d)
    }
}

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
      - next, productions that only involve single-line matching are retained;
      - next, productions that only involve non-empty word matching are retained;
      - next, productions that have a `@category` tag are retained.

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
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;

    // Analyze dependencies among productions
    println("[LOG] Analyzing dependencies among productions");
    Dependencies dependencies = deps(toGraph(rsc));
    list[Production] prods = dependencies
        .removeProds(isCyclic, true) // `true` means "also remove ancestors"
        .retainProds(isNonEmpty)
        .retainProds(hasCategory)
        .getProds();

    // Analyze delimiters
    println("[LOG] Analyzing delimiters");
    set[Symbol] delimiters
        = removeStrictPrefixes({s | /Symbol s := rsc, isDelimiter(delabel(s))})
        - {s | p <- prods, /just(s) := getOuterDelimiterPair(rsc, p)}
        - {s | p <- prods, /just(s) := getInnerDelimiterPair(rsc, p, getOnlyFirst = true)};
    list[Production] prodsDelimiters = [prod(lex(DELIMITERS_PRODUCTION_NAME), [\alt(delimiters)], {})];

    // Analyze keywords
    println("[LOG] Analyzing keywords");
    set[Symbol] keywords = {s | /Symbol s := rsc, isKeyword(delabel(s))};
    list[Production] prodsKeywords = [prod(lex(KEYWORDS_PRODUCTION_NAME), [\alt(keywords)], {\tag("category"("keyword.control"))})];

    // Return
    bool isEmptyProd(prod(_, [\alt(alternatives)], _)) = alternatives == {};
    list[ConversionUnit] units
        = [unit(rsc, p, hasNewline(rsc, p), getOuterDelimiterPair(rsc, p), getInnerDelimiterPair(rsc, p, getOnlyFirst = true)) | p <- prods]
        + [unit(rsc, p, false, <nothing(), nothing()>, <nothing(), nothing()>) | p <- prodsDelimiters, !isEmptyProd(p)]
        + [unit(rsc, p, false, <nothing(), nothing()>, <nothing(), nothing()>) | p <- prodsKeywords, !isEmptyProd(p)];

    return sort(units);
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

TmGrammar transform(list[ConversionUnit] units, NameGeneration nameGeneration = long()) {

    // Transform productions to rules
    println("[LOG] Transforming productions to rules");
    units = addNames(units, nameGeneration);
    units = addInnerRules(units);
    units = addOuterRules(units);

    // Transform rules to grammar
    println("[LOG] Transforming rules to grammar");
    set[TmRule] innerRules = {*u.innerRules | u <- units};
    set[TmRule] outerRules = {*u.outerRules | u <- units};
    Repository repository = ("<r.name>": r | TmRule r <- innerRules + outerRules);
    list[TmRule] patterns = dupLast([include("#<r.name>") | u <- units, r <- getTopLevelRules(u)]);
    TmGrammar tm = lang::textmate::Grammar::grammar(repository, "", patterns);

    // Return
    return tm;
}

private list[ConversionUnit] addNames(list[ConversionUnit] units, NameGeneration nameGeneration) {
    NameGenerator g = newNameGenerator([u.prod | u <- units], nameGeneration);
    return [u[name = g(u.prod)] | u <- units];
}

// Convenience type to fetch all conversion units that have a common `begin`
// delimiter, if any
private alias Index = rel[Maybe[Symbol] begin, ConversionUnit unit];

private list[ConversionUnit] addInnerRules(list[ConversionUnit] units) {

    // Define map to temporarily store inner rules
    map[ConversionUnit, list[TmRule]] rules = (u: [] | u <- units);

    // Compute and iterate over *groups* of units with a common `begin` inner
    // delimiter, if any. This is needed to convert multi-line units that have a
    // common `begin` inner delimiter.
    Index index = {<u.innerDelimiters.begin, u> | u <- units};
    for (key <- index.begin, group := index[key]) {

        // Convert all units in the group to match patterns (including,
        // optimistically, multi-line units as-if they are single-line)
        for (u <- group) {
            TmRule r = toTmRule(toRegExp(u.rsc, u.prod, guard = true))
                       [name = "/inner/single/<u.name>"];
            
            rules = insertIn(rules, (u: r));
        }

        // Convert multi-line units in the group, with a common `begin` inner
        // delimiter, and with a common category, to one begin/end pattern
        group = {u | u <- group, u.multiLine};
        set[RscGrammar] grammars = {u.rsc | u <- group};
        set[Symbol]     begins   = {begin | u <- group, <just(begin), _> := u.innerDelimiters};
        set[Symbol]     ends     = {  end | u <- group, <_, just(end)>   := u.innerDelimiters};
        set[Attr]       tags     = {    t | u <- group, prod(_, _, /t: \tag("category"(_))) := u.prod};

        if ({rsc} := grammars, {begin} := begins, {t} := tags) {

            // Simple case: each unit does have an `end` inner delimiter
            if (_ <- group && all(u <- group, just(_) := u.innerDelimiters.end)) {

                // Compute a list of segments that need to be consumed between
                // the `begin` delimiter and the `end` delimiters. Each of these
                // segments will be converted to a match pattern.
                set[Segment] segs = {*getSegments(rsc, u.prod) | u <- group};
                segs = {removeBeginEnd(seg, begins, ends) | seg <- segs};

                list[Symbol] terminals = [\seq(seg.symbols) | seg <- segs];
                terminals = [s | s <- terminals, [] != s.symbols];
                terminals = [destar(s) | s <- terminals]; // The tokenization engine always tries to apply rules repeatedly
                terminals = dup(terminals);
                terminals = sortByMinimumLength(terminals); // Small symbols first
                terminals = reverse(terminals); // Large symbols first
                terminals = terminals + \char-class([range(1,0x10FFFF)]); // Any char (as a fallback)
                
                TmRule r = toTmRule(
                    toRegExp(rsc, [begin], {t}),
                    toRegExp(rsc, [\alt(ends)], {t}),
                    [toTmRule(toRegExp(rsc, [s], {t})) | s <- terminals])
                    [name = "/inner/multi/<intercalate(",", [u.name | u <- group])>"];
                
                rules = insertIn(rules, (u: r | u <- group));
            }

            // Complex case: some unit doesn't have an `end` inner delimiter
            else {
                ; // TODO (part of future support for *recursive* multi-line units)
            }
        }
    }

    // Add inner rules to conversion units and return
    return [u[innerRules = rules[u]] | u <- units];
}

private list[ConversionUnit] addOuterRules(list[ConversionUnit] units) {

    // Define a map to temporarily store outer rules
    map[ConversionUnit, list[TmRule]] rules = (u: [] | u <- units);

    // Compute and iterate over *groups* of units with a common `begin` outer
    // delimiter, if any. This is needed to convert multi-line units that have a
    // common `begin` outer delimiter.
    Index index = {<u.outerDelimiters.begin, u> | u <- units};
    for (key <- index.begin, group := index[key]) {

        // Convert multi-line units, with a common `begin` outer delimiter, and
        // with an `end` outer delimiter, to one begin/end pattern
        group = {u | u <- group, <just(_), just(_)> := u.outerDelimiters};
        set[RscGrammar] grammars = {u.rsc | u <- group};
        set[Symbol]     begins   = {begin | u <- group, <just(begin), _> := u.outerDelimiters};
        set[Symbol]     ends     = {  end | u <- group, <_, just(end)>   := u.outerDelimiters};

        if ({rsc} := grammars, {begin} := begins) {
            list[TmRule] innerRules = [*u.innerRules | u <- sort([*group, *index[nothing()]])];

            TmRule r = toTmRule(
                toRegExp(rsc, [begin], {}),
                toRegExp(rsc, [\alt(ends)], {}),
                [include("#<r.name>") | TmRule r <- innerRules])
                [name = "/outer/<begin.string>"];
            
            rules = insertIn(rules, (u: r | u <- group));
        }
    }

    // Add outer rules to conversion units and return
    return [u[outerRules = rules[u]] | u <- units];

    // TODO: The current approach is *unit-driven*: for each (group of) unit(s),
    // check if it has outer delimiters, and if so, generate a corresponding
    // outer rule. An alternative approach could be *delimiter-driven*: for each
    // delimiter that occurs in the grammar, analyze the grammer to figure out
    // which productions (with a category) follow that delimiter (before the
    // next delimiter occurs), and generate outer rules accordingly. It could be
    // worthwhile to explore if a delimiter-driven approach leads to higher
    // precision than a unit-driven approach; I suspect it might.
}

private Segment removeBeginEnd(Segment seg, set[Symbol] begins, set[Symbol] ends) {
    list[Symbol] symbols = seg.symbols;
    if (seg.initial, _ <- symbols, symbols[0] in begins) {
        symbols = symbols[1..];
    }
    if (seg.final, _ <- symbols, symbols[-1] in ends) {
        symbols = symbols[..-1];
    }
    
    return seg[symbols = symbols];
}

// TODO: This function could be moved to a separate, generic module
private list[&T] dupLast(list[&T] l)
    = reverse(dup(reverse(l))); // TODO: Optimize/avoid `reverse`-ing?

// TODO: This function could be moved to a separate, generic module
private map[&K, list[&V]] insertIn(map[&K, list[&V]] m, map[&K, &V] values)
    // Updates the mapping of each key `k` in map of lists `m` to be the union
    // of: (1) the existing list `m[k]`, and (2) the new elements-to-be-inserted
    // `values[k]`. For instance:
    //   - m      = ("foo": [1, 2, 3],       "bar": [],    "baz": [1, 2])
    //   - values = ("foo": [4, 5],          "bar": [123], "qux": [3, 4])
    //   - return = ("foo": [1, 2, 3, 4, 5], "bar": [123], "baz": [1, 2])
    = (k: m[k] + (k in values ? [values[k]] : []) | k <- m);

private TmRule toTmRule(RegExp re)
    = match(
        re.string,
        captures = toCaptures(re.categories));

private TmRule toTmRule(RegExp begin, RegExp end, list[TmRule] patterns)
    = beginEnd(
        begin.string,
        end.string,
        beginCaptures = toCaptures(begin.categories),
        endCaptures = toCaptures(end.categories),
        patterns = patterns);