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
import lang::textmate::Grammar;
import lang::textmate::NameGeneration;

alias RscGrammar = Grammar;

data ConversionUnit = unit(
    RscGrammar rsc,
    Production prod,
    DelimiterPair outerDelimiters,
    DelimiterPair innerDelimiters);

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
    // bool isSingleLine(Production p, _, _)
    //     = !hasNewline(rsc, p);
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;

    // Analyze dependencies among productions
    println("[LOG] Analyzing dependencies among productions");
    Dependencies dependencies = deps(toGraph(rsc));
    list[Production] prods = dependencies
        .removeProds(isCyclic, true) // `true` means "also remove ancestors"
        // .filterProds(isSingleLine)
        .filterProds(isNonEmpty)
        .filterProds(hasCategory)
        .getProds();

    // Analyze delimiters
    println("[LOG] Analyzing delimiters");
    set[Symbol] delimiters = {s | /Symbol s := rsc, isDelimiter(delabel(s))};
    list[Production] prodsDelimiters = [prod(lex(DELIMITERS_PRODUCTION_NAME), [\alt(delimiters)], {})];

    // Analyze keywords
    println("[LOG] Analyzing keywords");
    set[Symbol] keywords = {s | /Symbol s := rsc, isKeyword(delabel(s))};
    list[Production] prodsKeywords = [prod(lex(KEYWORDS_PRODUCTION_NAME), [\alt(keywords)], {\tag("category"("keyword.control"))})];

    // Return
    bool isEmptyProd(prod(_, [\alt(alternatives)], _)) = alternatives == {};
    list[ConversionUnit] units
        = [unit(rsc, p, getOuterDelimiterPair(rsc, p), getInnerDelimiterPair(rsc, p, getOnlyFirst = true)) | p <- prods]
        + [unit(rsc, p, <nothing(), nothing()>, <nothing(), nothing()>) | p <- prodsDelimiters, !isEmptyProd(p)]
        + [unit(rsc, p, <nothing(), nothing()>, <nothing(), nothing()>) | p <- prodsKeywords, !isEmptyProd(p)];

    return sort(units, less);
}

private bool less(ConversionUnit u1, ConversionUnit u2) {

    Maybe[Symbol] getKey(ConversionUnit u)
        = <just(begin), _> := u.outerDelimiters ? just(begin)
        : <just(begin), _> := u.innerDelimiters ? just(begin)
        : nothing();
    
    Maybe[Symbol] key1 = getKey(u1);
    Maybe[Symbol] key2 = getKey(u2);

    if (just(begin1) := key1 && just(begin2) := key2) {
        if (begin2.string < begin1.string) {
            // If `begin2` is a prefix of `begin1`, then the rule for `u1` should be
            // tried *before* the rule for `u2` (i.e., `u1` is less than `u2` for
            // sorting purposes)
            return true;
        } else if (begin1.string < begin2.string) {
            // Symmetrical case
            return false;
        } else {
            // Otherwise, sort arbitrarily by name and stringified production
            return toName(u1.prod.def) + "<u1.prod>" < toName(u2.prod.def) + "<u2.prod>";
        }
    } else if (nothing() != key1 && nothing() == key2) {
        // If `u1` has a `begin` delimiter, but `u2` hasn't, then `u1` is less
        // than `u2` for sorting purposes (arbitrarily)
        return true;
    } else if (nothing() == key1 && nothing() != key2) {
        // Symmetrical case
        return false;
    } else {
        // Otherwise, sort arbitrarily by name and stringified production
        return toName(u1.prod.def) + "<u1.prod>" < toName(u2.prod.def) + "<u2.prod>";
    }
}

public str DELIMITERS_PRODUCTION_NAME = "~delimiters";
public str KEYWORDS_PRODUCTION_NAME   = "~keywords";

private bool isSynthetic(Symbol s)
    = lex(name) := s && name in {DELIMITERS_PRODUCTION_NAME, KEYWORDS_PRODUCTION_NAME};

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
    NameGenerator g = newNameGenerator([u.prod | u <- units], nameGeneration);
    list[TmRule] rules = [toTmRule(u, g) | u <- units];

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
    for (name <- tm.repository, tm.repository[name] is beginEnd) {
        // Inject top-level patterns into begin/end patterns
        TmRule r = tm.repository[name]; 
        tm.repository += (name: r[patterns = r.patterns + tm.patterns - include("#<name>")]);
    }

    // Return
    return tm[patterns = tm.patterns];
}

@synopsis{
    Converts a conversion unit to a TextMate rule
}

TmRule toTmRule(ConversionUnit u, NameGenerator g)
    = toTmRule(u.rsc, u.prod, g(u.prod));

private TmRule toTmRule(RscGrammar rsc, p: prod(def, _, _), str name)
    = !isSynthetic(def) && <just(begin), just(end)> := getOuterDelimiterPair(rsc, p)
    ? toTmRule(toRegExp(rsc, begin), toRegExp(rsc, end), "<begin.string><end.string>", [toTmRule(toRegExp(rsc, p), name)])
    : toTmRule(toRegExp(rsc, p), name);

private TmRule toTmRule(RegExp re, str name)
    = match(re.string, captures = toCaptures(re.categories), name = name);

private TmRule toTmRule(RegExp begin, RegExp end, str name, list[TmRule] patterns)
    = beginEnd(begin.string, end.string, name = name, patterns = patterns);