@synopsis{
    Types and functions to transform Rascal grammars to TextMate grammars
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
    Symbol replaceIfDelimiter(Symbol old, Symbol new)
        = isDelimiter(new) ? new : old;

    // Replace occurrences of singleton ranges with just the corresponding
    // literal. This makes it easier to identify delimiters.
    return visit (rsc) {
        case s: \char-class([range(char, char)]) => 
            replaceIfDelimiter(s, \lit("<stringChar(char)>"))
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
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;

    // Analyze dependencies among productions
    println("[LOG] Analyzing dependencies among productions");
    Dependencies dependencies = deps(toGraph(rsc));
    list[Production] prods = dependencies
        .removeProds(isCyclic, true) // `true` means "also remove ancestors"
        .filterProds(isNonEmpty)
        .filterProds(hasCategory)
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

    // Transform productions to inner rules
    println("[LOG] Transforming productions to rules");
    NameGenerator g = newNameGenerator([u.prod | u <- units], nameGeneration);
    units = [u[name = g(u.prod)] | u <- units];
    units = addInnerRules(units);
    units = addOuterRules(units);

    // Transform rules to repository
    println("[LOG] Transforming rules to grammar");
    set[TmRule] innerRules = {*u.innerRules | u <- units};
    set[TmRule] outerRules = {*u.outerRules | u <- units};
    Repository repository = ("<r.name>": r | TmRule r <- innerRules + outerRules);
    list[TmRule] patterns = dupLast([include("#<r.name>") | u <- units, r <- getTopLevelRules(u)]);
    TmGrammar tm = lang::textmate::Grammar::grammar(repository, "", patterns);

    // Return
    return lang::textmate::Grammar::grammar(repository, "", patterns);
}

private list[ConversionUnit] addInnerRules(list[ConversionUnit] units) {

    // Define map to temporarily store inner rules
    map[ConversionUnit, list[TmRule]] rules = (u: [] | u <- units);

    // Compute and iterate over *sets* of conversion units with a common `begin`
    // delimiter, if any, to be able to use per-set conversion
    rel[Maybe[Symbol] begin, ConversionUnit unit] index
        = {<begin, u> | u <- units, <begin, _> := u.innerDelimiters};
    for (key <- index.begin, set[ConversionUnit] units := index[key]) {

        // Convert all units generically to match patterns (including,
        // optimistically, multi-line productions as-if they are single-line)
        for (u <- units) {
            TmRule r = toTmRule(
                toRegExp(u.rsc, u.prod),
                "/inner/single/<u.name>");

            rules = insertIn(rules, (u: r));
        }

        // Convert multi-line units, with a common `begin` delimiter, and with a
        // common category, specifically to begin/end patterns
        units = {u | u <- units, multiLine() == u.kind, <just(_), just(_)> := u.innerDelimiters};
        
        set[RscGrammar] grammars = {u.rsc | u <- units};
        set[Symbol]     begins   = {begin | u <- units, <just(begin), _> := u.innerDelimiters};
        set[Symbol]     ends     = {  end | u <- units, <_, just(end)>   := u.innerDelimiters};
        set[Attr]       tags     = {    t | u <- units, prod(_, _, /t: \tag("category"(_))) := u.prod};

        if ({rsc} := grammars, {begin} := begins, _ <- ends, {t} := tags) {

            // Compute symbols to generate nested patterns for
            list[Symbol] symbols = [*getTerminals(rsc, u.prod) | u <- units];
            symbols = [s | s <- symbols, s notin begins && s notin ends];
            symbols = [destar(s) | s <- symbols];
            symbols = dup(symbols);
            symbols = symbols + \char-class([range(1,1114111)]); // Any char (as a fallback)
            
            TmRule r = toTmRule(
                toRegExp(rsc, [begin], {t}),
                toRegExp(rsc, [\alt(ends)], {t}),
                "/inner/multi/<intercalate(",", [u.name | u <- units])>",
                [toTmRule(toRegExp(rsc, [s], {t})) | s <- symbols]);
            
            rules = insertIn(rules, (u: r | u <- units));
        }
    }

    // Add inner rules to conversion units and return
    return [u[innerRules = rules[u]] | u <- units];
}

// TODO: Rethink this approach for outer rules
private list[ConversionUnit] addOuterRules(list[ConversionUnit] units) {

    // Define a map to temporarily store outer rules
    map[ConversionUnit, list[TmRule]] rules = (u: [] | u <- units);

    // Compute and iterate over *sets* of conversion units with a common `begin`
    // delimiter, if any, to be able to use per-set conversion
    rel[Maybe[Symbol] begin, ConversionUnit unit] index
        = {<begin, u> | u <- units, <begin, _> := u.outerDelimiters};
    for (key <- index.begin, set[ConversionUnit] units := index[key], nothing() !:= key) {
        units -= {u | u <- units, <_, nothing()> := u.outerDelimiters};
        units += index[nothing()];
        
        set[RscGrammar] grammars = {u.rsc | u <- units};
        set[Symbol]     begins   = {begin | u <- units, <just(begin), _> := u.outerDelimiters};
        set[Symbol]     ends     = {  end | u <- units, <_, just(end)>   := u.outerDelimiters};

        if ({rsc} := grammars, {begin} := begins, _ <- ends) {
            TmRule r = toTmRule(
                toRegExp(rsc, [begin], {}),
                toRegExp(rsc, [\alt(ends)], {}),
                "/outer/<begin.string>",
                [include("#<r.name>") | u <- sort([*units]), TmRule r <- u.innerRules]);
            
            rules = insertIn(rules, (u: r | u <- units));
        }
    }

    // Add outer rules to conversion units and return
    return [u[outerRules = rules[u]] | u <- units];
// TODO: This function could be moved to a separate, generic module
private list[&T] dupLast(list[&T] l)
    = reverse(dup(reverse(l))); // TODO: Optimize/avoid `reverse`-ing?

// TODO: This function could be moved to a separate, generic module
private map[&K, list[&V]] insertIn(map[&K, list[&V]] m, map[&K, &V] values)
    = (k: m[k] + (k in values ? [values[k]] : []) | k <- m);

private TmRule toTmRule(RegExp re)
    = match(
        re.string,
        captures = toCaptures(re.categories));

private TmRule toTmRule(RegExp re, str name)
    = match(
        re.string,
        captures = toCaptures(re.categories),
        name = name);

private TmRule toTmRule(RegExp begin, RegExp end, str name, list[TmRule] patterns)
    = beginEnd(
        begin.string,
        end.string,
        beginCaptures = toCaptures(begin.categories),
        endCaptures = toCaptures(end.categories),
        name = name,
        patterns = patterns);