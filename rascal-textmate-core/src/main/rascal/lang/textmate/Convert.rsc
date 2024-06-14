module lang::textmate::Convert

import Grammar;
import IO;
import ParseTree;
import Set;
import util::Maybe;

import lang::oniguruma::Convert;
import lang::oniguruma::RegExp;
import lang::rascal::SingleLine;
import lang::rascal::Util;
import lang::textmate::Grammar;

alias RscGrammar = Grammar::Grammar;
alias TmGrammar = lang::textmate::Grammar::Grammar;
alias TmRule = lang::textmate::Grammar::Rule;

data Mode
    = multiLineRules()
    | singleLineRules()
    | delimiterRules()
    | keywordRules();

TmGrammar toTmGrammar(
        RscGrammar rscGrammar, ScopeName name,
        list[Mode] modes = [delimiterRules(), multiLineRules(), singleLineRules(), keywordRules()]) {

    list[TmGrammar] tmGrammars
        = [lang::textmate::Grammar::grammar((), name, [])]
        + [toTmGrammar(rscGrammar, name, m) | m <- modes];

    // TODO: Merge rules with overlapping `match`/`begin` patterns
    return (tmGrammars[0] | merge(it, g) | g <- tmGrammars[1..]);
}

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, multiLineRules()) {
    // TODO
    return lang::textmate::Grammar::grammar((), name, []);
}

rel[Symbol, Symbol] getDelimiterPairs(
        Symbol child, set[Production] productions,
        set[Symbol] nonParents = {}) {

    pairs = {pair | p <- productions, just(pair) := getDelimiterPair(child, p)};
    if (isEmpty(pairs)) {
        nonParents += child;
        set[Symbol] parents
            = {delabel(parent) | \prod(parent, [*_, /child, *_], _) <- productions}
            - nonParents;
        
        return ({} | it + getDelimiterPairs(p, productions) | p <- parents);
    } else {
        return pairs;
    }
}

Maybe[tuple[Symbol, Symbol]] getDelimiterPair(Symbol s, \prod(_, [*_, begin, *between, end, *_], _))
    = just(<begin, end>) when
        lit(_) := begin || cilit(_) := begin,
        lit(_) := end || cilit(_) := end,
        [*between1, /s, *between2] := between,
        !any(lit(_) <- between1 + between2);

default Maybe[tuple[Symbol, Symbol]] getDelimiterPair(_, _)
    = nothing();

TmGrammar toTmGrammar(RscGrammar gr, ScopeName name, singleLineRules()) {    

    // Auxiliary functions
    bool isNonEmpty(\prod(def, _, _)) = !tryParse(gr, def, "");
    bool isCategory(\prod(_, _, attributes)) = /\tag("category"(_)) := attributes;
    
    set[Production] productions
        = prods(gr, keep=isNonEmpty)
        & prods(gr, keep=isCategory);
    
    productions = keepSingleLineProductions(gr, only=productions);
    map[Production, RegExp] regExps = toRegExps(gr, only=productions);

    Counter c = counter();
    Repository repository = ();
    list[Rule] patterns = [];
    for (p: \prod(def, _, _) <- productions, p in regExps) {
        str matchName = "<c.next()>/<def>";
        repository += (matchName: toTmRule(matchName, regExps[p]));
        patterns += [include("#<matchName>")];

        // Check if production can be scoped for higher accuracy
        if ({<begin, end>} := getDelimiterPairs(delabel(def), prods(gr))) {
            str beginEndName = "_/<begin>/<end>";

            TmRule rule = beginEnd(
                toRegExp((), begin).val.string,
                toRegExp((), end).val.string,
                patterns
                    = (beginEndName in repository ? repository[beginEndName].patterns : [])
                    + last(patterns));
            
            repository += (beginEndName: rule);
            patterns = prefix(patterns) + [include("#<beginEndName>")];
        }
    }

    return lang::textmate::Grammar::grammar(repository, name, dup(patterns));
}

TmGrammar toTmGrammar(RscGrammar gr, ScopeName name, keywordRules()) {

    // Auxiliary functions
    bool isKeyword(lit(/^\w+$/))     = true;
    bool isKeyword(cilit(/^\w+$/))   = true;
    default bool isKeyword(Symbol _) = false;

    Symbol def = ParseTree::keywords("");
    list[Symbol] symbols = [\alt({s | /Symbol s := gr, isKeyword(s)})];
    set[Attr] attributes = {\tag("category"("keyword.control"))};
    
    Production p = \prod(def, symbols, attributes);
    RegExp re = prefix("\\b", suffix("\\b", toRegExp((), p))).val;
    
    Repository repository = ("_/keywords": toTmRule("_/keywords", re));
    list[Rule] patterns = [include("#_/keywords")];
    return lang::textmate::Grammar::grammar(repository, name, patterns);
}

TmGrammar toTmGrammar(RscGrammar gr, ScopeName name, delimiterRules()) {

    // Auxiliary functions
    bool isDelimiter(lit(string))      = true when /^\w+$/ !:= string;
    bool isDelimiter(cilit(string))    = true when /^\w+$/ !:= string;
    default bool isDelimiter(Symbol _) = false;

    // TODO: Exclude delimiters for which another scope exists
    Symbol def = ParseTree::keywords("");
    list[Symbol] symbols = [\alt({s | /Symbol s := gr, isDelimiter(s)})];
    set[Attr] attributes = {};
    
    Production p = \prod(def, symbols, attributes);
    RegExp re = toRegExp((), p).val;
    
    Repository repository = ("_/delimiters": toTmRule("_/delimiters", re));
    list[Rule] patterns = [include("#_/delimiters")];
    return lang::textmate::Grammar::grammar(repository, name, patterns);
}

TmRule toTmRule(str name, regExp(string, groups)) =
    match(
        ungroup(string),
        name = name,
        captures = ("<n + 1>": ("name": groups[n]) | n <- [0..size(groups)]));

@synopsis{
    A simple counter.
}

data Counter = counter(int() next);

Counter counter() {
    int n = 0;

    int next() {
        n += 1;
        return n;
    }

    return counter(next);
}