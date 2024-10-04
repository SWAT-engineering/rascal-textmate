@synopsis{
    Types and functions to convert Rascal grammars to TextMate grammars
}

module lang::textmate::Conversion

import Grammar;
import ParseTree;
import String;
import util::Maybe;
import util::Monitor;

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
import util::ListUtil;
import util::MapUtil;

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

TmGrammar toTmGrammar(RscGrammar rsc, str name, NameGeneration nameGeneration = long())
    = transform(analyze(preprocess(rsc), name), name, nameGeneration = nameGeneration);

@synopsis{
    Preprocess Rascal grammar `rsc` to make it suitable for analysis and
    transformation
}

RscGrammar preprocess(RscGrammar rsc) {
    // Replace occurrences of singleton ranges with just the corresponding
    // literal. This makes it easier to identify delimiters.
    rsc = visit (rsc) {
        case \char-class([range(char, char)]) => d
            when d := \lit("<stringChar(char)>"), isDelimiter(d)
    }

    // Replace current semantic token types with TextMate scopes based on:
    //   - https://github.com/microsoft/vscode/blob/9f3a7b5bc8a2758584b33d0385b227f25ae8d3fb/src/vs/platform/theme/common/tokenClassificationRegistry.ts#L543-L571
    rsc = visit (rsc) {
        case \tag("category"("comment"))       => \tag("category"("comment"))
        case \tag("category"("string"))        => \tag("category"("string"))
        case \tag("category"("keyword"))       => \tag("category"("keyword.control"))
        case \tag("category"("number"))        => \tag("category"("constant.numeric"))
        case \tag("category"("regexp"))        => \tag("category"("constant.regexp"))
        case \tag("category"("operator"))      => \tag("category"("keyword.operator"))
        case \tag("category"("namespace"))     => \tag("category"("entity.name.namespace"))
        case \tag("category"("type"))          => \tag("category"("support.type")) // Alternative: support.type
        case \tag("category"("struct"))        => \tag("category"("entity.name.type.struct"))
        case \tag("category"("class"))         => \tag("category"("entity.name.type.class")) // Alternative: support.class
        case \tag("category"("interface"))     => \tag("category"("entity.name.type.interface"))
        case \tag("category"("enum"))          => \tag("category"("entity.name.type.enum"))
        case \tag("category"("typeParameter")) => \tag("category"("entity.name.type.parameter"))
        case \tag("category"("function"))      => \tag("category"("entity.name.function")) // Alternative: support.function
        case \tag("category"("method"))        => \tag("category"("entity.name.function.member")) // Alternative: support.function
        case \tag("category"("macro"))         => \tag("category"("entity.name.function.preprocessor"))
        case \tag("category"("variable"))      => \tag("category"("variable.other.readwrite")) // Alternative: entity.name.variable
        case \tag("category"("parameter"))     => \tag("category"("variable.parameter"))
        case \tag("category"("property"))      => \tag("category"("variable.other.property"))
        case \tag("category"("enumMember"))    => \tag("category"("variable.other.enummember"))
        case \tag("category"("event"))         => \tag("category"("variable.other.event"))
        case \tag("category"("decorator"))     => \tag("category"("entity.name.decorator")) // Alternative: entity.name.function
        // Note: Categories types `member` and `label` are deprecated/undefined
        // and therefore excluded from this mapping
    }

    // Replace legacy semantic token types with TextMate scopes based on:
    //   - https://github.com/usethesource/rascal/blob/83023f60a6eb9df7a19ccc7a4194b513ac7b7157/src/org/rascalmpl/values/parsetrees/TreeAdapter.java#L44-L59
    //   - https://github.com/usethesource/rascal-language-servers/blob/752fea3ea09101e5b22ee426b11c5e36db880225/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java#L121-L142
    // With updates based on:
    //   - https://github.com/eclipse-lsp4j/lsp4j/blob/f235e91fbe2e45f62e185bbb9f6d21bed48eb2b9/org.eclipse.lsp4j/src/main/java/org/eclipse/lsp4j/Protocol.xtend#L5639-L5695
    //   - https://github.com/usethesource/rascal-language-servers/blob/88be4a326128da8c81d581c2b918b4927f2185be/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java#L134-L152
    rsc = visit (rsc) {
        case \tag("category"("Normal"))           => \tag("category"("source"))
        case \tag("category"("Type"))             => \tag("category"("type"))     // Updated (before: storage.type)
        case \tag("category"("Identifier"))       => \tag("category"("variable"))
        case \tag("category"("Variable"))         => \tag("category"("variable"))
        case \tag("category"("Constant"))         => \tag("category"("string"))   // Updated (before: constant)
        case \tag("category"("Comment"))          => \tag("category"("comment"))
        case \tag("category"("Todo"))             => \tag("category"("comment"))
        case \tag("category"("Quote"))            => \tag("category"("string"))   // Updated (before: meta.string)
        case \tag("category"("MetaAmbiguity"))    => \tag("category"("invalid"))
        case \tag("category"("MetaVariable"))     => \tag("category"("variable"))
        case \tag("category"("MetaKeyword"))      => \tag("category"("keyword"))  // Updated (before: keyword.other)
        case \tag("category"("MetaSkipped"))      => \tag("category"("string"))
        case \tag("category"("NonterminalLabel")) => \tag("category"("variable")) // Updated (before: variable.parameter)
        case \tag("category"("Result"))           => \tag("category"("string"))   // Updated (before: text)
        case \tag("category"("StdOut"))           => \tag("category"("string"))   // Updated (before: text)
        case \tag("category"("StdErr"))           => \tag("category"("string"))   // Updated (before: text)
    }

    return rsc;
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

list[ConversionUnit] analyze(RscGrammar rsc, str name) {
    str jobLabel = "Analyzing<name == "" ? "" : " (<name>)">";
    jobStart(jobLabel, work = 4);

    // Define auxiliary predicates
    bool isCyclic(Production p, set[Production] ancestors, _)
        = p in ancestors;
    bool isNonEmpty(prod(def, _, _), _, _)
        = !tryParse(rsc, delabel(def), "");
    bool hasCategory(prod(_, _, attributes), _, _)
        = /\tag("category"(_)) := attributes;

    // Analyze dependencies among productions
    jobStep(jobLabel, "Analyzing productions");
    Graph[Production] graph = toGraph(rsc);
    list[Production] prods             = deps(graph).retainProds(isNonEmpty).retainProds(hasCategory).getProds();
    list[Production] prodsNonRecursive = prods & deps(graph).removeProds(isCyclic, true).getProds();
    list[Production] prodsRecursive    = prods - prodsNonRecursive;

    // Analyze delimiters
    jobStep(jobLabel, "Analyzing delimiters");
    set[Symbol] delimiters
        = removeStrictPrefixes({s | /Symbol s := rsc, isDelimiter(delabel(s))})
        - {s | p <- prods, /just(s) := getOuterDelimiterPair(rsc, p)}
        - {s | p <- prods, /just(s) := getInnerDelimiterPair(rsc, p, getOnlyFirst = true)};
    list[Production] prodsDelimiters = [prod(lex(DELIMITERS_PRODUCTION_NAME), [\alt(delimiters)], {})];

    // Analyze keywords
    jobStep(jobLabel, "Analyzing keywords");
    set[Symbol] keywords = {s | /Symbol s := rsc, isKeyword(delabel(s))};
    list[Production] prodsKeywords = [prod(lex(KEYWORDS_PRODUCTION_NAME), [\alt(keywords)], {\tag("category"("keyword.control"))})];

    // Prepare units
    jobStep(jobLabel, "Preparing units");

    bool isRecursive(Production p)
        = p in prodsRecursive;
    bool isEmptyProd(prod(_, [\alt(alternatives)], _))
        = alternatives == {};
    
    set[ConversionUnit] units = {};
    units += {unit(rsc, p, isRecursive(p), hasNewline(rsc, p), getOuterDelimiterPair(rsc, p), getInnerDelimiterPair(rsc, p, getOnlyFirst = true)) | p <- prods};
    units += {unit(rsc, p, false, false, <nothing(), nothing()>, <nothing(), nothing()>) | p <- prodsDelimiters + prodsKeywords, !isEmptyProd(p)};
    list[ConversionUnit] ret = sort([*removeStrictPrefixes(units)]);

    // Return
    jobEnd(jobLabel);
    return ret;
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

TmGrammar transform(list[ConversionUnit] units, str name, NameGeneration nameGeneration = long()) {
    str jobLabel = "Transforming<name == "" ? "" : " (<name>)">";
    jobStart(jobLabel, work = 2);

    // Transform productions to rules
    jobStep(jobLabel, "Transforming productions to rules");
    units = addNames(units, nameGeneration);
    units = addInnerRules(units);
    units = addOuterRules(units);

    // Transform rules to grammar
    jobStep(jobLabel, "Transforming rules to grammar");
    set[TmRule] innerRules = {*u.innerRules | u <- units};
    set[TmRule] outerRules = {*u.outerRules | u <- units};
    Repository repository = ("<r.name>": r | TmRule r <- innerRules + outerRules);
    list[TmRule] patterns = dupLast([include("#<r.name>") | u <- units, r <- getTopLevelRules(u)]);
    TmGrammar tm = lang::textmate::Grammar::grammar(repository, "", patterns);

    // Return
    jobEnd(jobLabel);
    return tm[scopeName = name];
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
        for (u <- group, !u.recursive) {

            // Add the guard (i.e., look-behind condition to match layout) only
            // when the units in the group don't begin with a delimiter. Why is
            // is this? We *don't* want `32` to be highlighted as a number in
            // `int aer32 = 34`. However, we *do* want `>bar"` to be highlighted
            // as a string in `"foo<x==5>bar"`. As a heuristic, if the token
            // starts with a delimiter (e.g., `>`), then it should be allowed
            // for its occurrence to not be preceded by layout.
            bool guard = nothing() := u.innerDelimiters.begin;
            TmRule r = toTmRule(toRegExp(u.rsc, u.prod, guard = guard))
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
                
                // Create a set of pointers to the first (resp. last) occurrence 
                // of `pivot` in each unit, when `pivot` is a `begin` delimiter
                // (resp. an `end` delimiter) of the group. If `pivot` occurs
                // elsewhere in the grammar as well, then skip the conversion
                // of these multi-line units to a begin/end pattern. This is to
                // avoid tokenization mistakes in which the other occurrences of
                // `pivot` in the input are mistakenly interpreted as the
                // beginning or ending of a unit in the group.
                
                Symbol pivot = key.val;
                
                set[Pointer] pointers = {};
                pointers += pivot in begins ? {*find(rsc, u.prod, pivot, dir = forward()) [-1..] | u <- group} : {};
                pointers += pivot in ends   ? {*find(rsc, u.prod, pivot, dir = backward())[-1..] | u <- group} : {};

                if (any(/p: prod(_, [*before, pivot, *_], _) := rsc.rules, <p, size(before)> notin pointers)) {
                    continue;
                }

                // Compute a set of segments that need to be consumed between
                // the `begin` delimiter and the `end` delimiters. Each of these
                // segments will be converted to a match pattern.
                set[Segment] segs = {*getSegments(rsc, u.prod) | u <- group};
                segs = {removeBeginEnd(seg, begins, ends) | seg <- segs};

                TmRule r = toTmRule(
                    toRegExp(rsc, [begin], {t}),
                    toRegExp(rsc, [\alt(ends)], {t}),
                    [toTmRule(toRegExp(rsc, [s], {t})) | s <- toTerminals(segs)])
                    [name = "/inner/multi/<intercalate(",", [u.name | u <- group])>"];
                
                rules = insertIn(rules, (u: r | u <- group));
            }

            // Complex case: some unit doesn't have an `end` inner delimiter.
            // This requires (substantial) extra care, as there is no obvious
            // marker to close the begin/end pattern with.
            else {
                Decomposition decomposition = decompose([*group]);

                // TODO: The following condition can be true (even though there
                // has to be a `begin` delimiter) because `decompose` doesn't
                // expand non-terminals. Consider if it should, to maybe improve
                // accuracy.
                if ([] == decomposition.prefix) {
                    continue;
                }

                RegExp reBegin = toRegExp(rsc, decomposition.prefix, {t});
                RegExp reEnd   = regExp("(?=.)", []);

                patterns = for (suffix <- decomposition.suffixes) {
                    if (just(Symbol begin) := getInnerDelimiterPair(rsc, suffix[0], getOnlyFirst = true).begin) {
                        if (just(Symbol end) := getInnerDelimiterPair(rsc, suffix[-1], getOnlyFirst = true).end) {
                            // If the suffix has has both a `begin` delimiter
                            // and an `end` delimiter, then generate a
                            // begin/end pattern to highlight these delimiters
                            // and all content in between.
                            
                            set[Segment] segs = getSegments(rsc, suffix);
                            segs = {removeBeginEnd(seg, {begin}, {end}) | seg <- segs};

                            append toTmRule(
                                toRegExp(rsc, [begin], {t}),
                                toRegExp(rsc, [end], {t}),
                                [toTmRule(toRegExp(rsc, [s], {t})) | s <- toTerminals(segs)]);
                        }
                        
                        else {
                            // If the suffix has a `begin` delimiter, but not
                            // an `end` delimiter, then generate a match pattern
                            // just to highlight that `begin` delimiter. Ignore
                            // the remainder of the suffix (because it's
                            // recursive, so no regular expression can be
                            // generated for it).
                            append toTmRule(toRegExp(rsc, [begin], {t}));
                        }
                    }

                    else {
                        // If the suffix doesn't have a `begin` delimiter, then
                        // ignore it (because it's recursive, so no regular
                        // expression can be generated for it).
                        ;
                    }
                }

                TmRule r = toTmRule(reBegin, reEnd, patterns);
                r = r[name = "/inner/multi/<intercalate(",", [u.name | u <- group])>"];
                r = r[applyEndPatternLast = true];

                rules = insertIn(rules, (u: r | u <- group));

                // TODO: The current approach produces "partially"
                // newline-sensitive rules, in the sense that newlines are
                // accepted between the prefix and the suffixes, but not between
                // symbols in the prefix. This approach could be improved to
                // produce "totally" newline-sensitive rules (at the cost of
                // much more complicated rule generation and generated rules) by
                // adopting an approach in which the rules for each symbol in
                // the prefix looks something like the following three:
                //
                // ```
                // "foo": {
                //   "name": "foo",
                //   "begin": "(\\@)",
                //   "end": "(?!\\G)|(?:(?!$)(?![a-z]+))",
                //   "patterns": [{ "include": "#foo.$" }, { "match": "[a-z]+" }],
                //   "contentName": "comment",
                //   "beginCaptures": { "1": { "name": "comment" } }
                // },
                // "foo.$": {
                //   "begin": "$",
                //   "end": "(?<=^.+)|(?:(?!$)(?![a-z]+))",
                //   "name": "foo.$",
                //   "patterns": [ { "include": "#foo.^" }]
                // },
                // "foo.^": {
                //   "begin": "^",
                //   "end": "(?!\\G)|(?:(?!$)(?![a-z]+))",
                //   "name": "foo.^",
                //   "patterns": [{ "include": "#foo.$" }, { "match": "[a-z]+" }]
                // }
                // ```
                //
                // Note: This alternative approach would likely render the
                // present distinction between the "simple case" and the
                // "complex case" unneeded, so in that sense, rule generation
                // would actually become simpler.
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

private list[Symbol] toTerminals(set[Segment] segs) {
    list[Symbol] terminals = [\seq(seg.symbols) | seg <- segs];
    terminals = [s | s <- terminals, [] != s.symbols];
    terminals = [destar(s) | s <- terminals]; // The tokenization engine always tries to apply rules repeatedly
    terminals = dup(terminals);
    terminals = sortByMinimumLength(terminals); // Small symbols first
    terminals = reverse(terminals); // Large symbols first
    terminals = terminals + \char-class([range(1,0x10FFFF)]); // Any char (as a fallback)
    return terminals;
}

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