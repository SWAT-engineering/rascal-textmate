module lang::textmate::Conversion

import Grammar;
import IO;
import ParseTree;
import Set;
import String;

import lang::oniguruma::Conversion;
import lang::oniguruma::RegExp;
import lang::rascal::grammar::Util;
import lang::rascal::grammar::analyze::Delimiters;
import lang::rascal::grammar::analyze::Dependencies;
import lang::rascal::grammar::analyze::Newlines;
import lang::textmate::Grammar;

alias RscGrammar = Grammar::Grammar;
alias TmGrammar = lang::textmate::Grammar::Grammar;
alias TmRule = lang::textmate::Grammar::Rule;

@synopsis{
    Converts Rascal grammar `rsc` to a TextMate grammar
}

data ConversionUnit = unit(
    RscGrammar rsc,
    Production prod,
    bool ignoreDelimiterPairs = false);

TmGrammar toTmGrammar(RscGrammar rsc, ScopeName scopeName)
    = transform(analyze(rsc)) [scopeName = scopeName];

private list[ConversionUnit] analyze(RscGrammar rsc) {

    // Define auxiliary predicates
    bool isCyclic(Production p, set[Production] ancestors, _)
        = p in ancestors;
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool isSingleLine(Production p, _, _)
        = !hasNewline(rsc, p);
    bool isLayout(prod(def, _, _), _, _)
        = \layouts(_) := delabel(def);

    // Analyze dependencies among productions
    println("[LOG] Analyzing dependencies among productions");
    Dependencies dependencies = deps(rsc);
    
    list[Production] prods = dependencies
        .removeProds(isCyclic, true, false) // Remove ancestors too
        .filterProds(isNonEmpty, false, true) // Filter descendants too
        .filterProds(isSingleLine, false, false)
        .filterProds(hasCategory, false, false)
        .getProds();
    
    list[Production] prodsLayouts = dependencies
        .filterProds(isLayout, false, true) // Filter descendants too
        .getProds();

    // Analyze delimiters
    println("[LOG] Analyzing delimiters");
    set[Symbol] delimiters = {s | /Symbol s := rsc, isDelimiter(delabel(s))};
    delimiters -= getStrictPrefixes(delimiters);
    delimiters -= {s | prod(def, _, _) <- prods, /s := getDelimiterPairs(rsc, delabel(def))};
    delimiters -= {s | prod(_, [s, *_], _) <- prods, isDelimiter(delabel(s))};
    list[Production] prodsDelimiters = [prod(lex("delimiters"), [\alt(delimiters)], {})];

    // Analyze keywords
    println("[LOG] Analyzing keywords");
    set[Symbol] keywords = {s | /Symbol s := rsc, isKeyword(delabel(s))};
    list[Production] prodsKeywords = [prod(lex("keywords"), [\alt(keywords)], {\tag("category"("keyword.control"))})];

    // Return
    list[ConversionUnit] units
        = [unit(rsc, p) | p <- prodsDelimiters]
        + [unit(rsc, p) | p <- prods - prodsLayouts]
        + [unit(rsc, p, ignoreDelimiterPairs = true) | p <- prods & prodsLayouts]
        + [unit(rsc, p) | p <- prodsKeywords];
    
    return units;
}

private TmGrammar transform(list[ConversionUnit] units) {

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

    return tm[patterns = dup(tm.patterns)];
}

@synopsis{
    Converts a conversion unit to a TextMate rule
}

TmRule toTmRule(ConversionUnit u)
    = toTmRule(u.rsc, u.prod, u.ignoreDelimiterPairs);

private TmRule toTmRule(RscGrammar rsc, p: prod(def, _, _), bool ignoreDelimiterPairs)
    = !ignoreDelimiterPairs && {<begin, end>} := getDelimiterPairs(rsc, delabel(def))
    ? toTmRule(toRegExp(rsc, begin), toRegExp(rsc, end), "<begin>:<end>", [toTmRule(toRegExp(rsc, p), "<p>")])
    : toTmRule(toRegExp(rsc, p), "<p>");

private TmRule toTmRule(regExp(string, categories), str name)
    = match(ungroup(string), captures = toCaptures(categories), name = name);
private TmRule toTmRule(nil(), str name)
    = match("", name = name);

private TmRule toTmRule(RegExp begin, RegExp end, str name, list[TmRule] patterns)
    = beginEnd(begin.string, end.string, name = name, patterns = patterns);