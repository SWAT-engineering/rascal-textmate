module lang::textmate::Convert

import Grammar;
import Map;
import ParseTree;
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
    | keywordRules();

TmGrammar toTmGrammar(
        RscGrammar rscGrammar, ScopeName name,
        list[Mode] modes = [multiLineRules(), singleLineRules(), keywordRules()]) {

    list[TmGrammar] tmGrammars
        = [lang::textmate::Grammar::grammar((), name, [])]
        + [toTmGrammar(rscGrammar, name, m) | m <- modes];

    return (tmGrammars[0] | merge(it, g) | g <- tmGrammars[1..]);
}

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, multiLineRules()) {
    // TODO
    return lang::textmate::Grammar::grammar((), name, []);
}

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, singleLineRules()) {    
    map[Symbol, Production] rules = rscGrammar.rules;

    // Auxiliary functions
    set[Production] keepNonEmptyProductions(set[Production] productions)
        = {p | p: \prod(def, _, _) <- productions, !tryParse(rules, def, "")};
    set[Production] keepCategoryProductions(set[Production] productions)
        = {p | p: \prod(_, _, {\tag("category"(_)), *_}) <- productions};
    
    set[Production] productions = {p | /p: \prod(_, _, _) <- range(rules)};
    map[Production, RegExp] regExps = toRegExps(productions);
    
    productions = keepSingleLineProductions(productions);
    productions = keepNonEmptyProductions(productions);
    productions = keepCategoryProductions(productions);

    Counter c = counter();
    Repository repository = ();
    list[Rule] patterns = [];

    for (p: \prod(def, _, _) <- productions, p in regExps) {
        str matchName = "<c.next()>/<def>";
        repository += (matchName: toTmRule(matchName, regExps[p]));
        patterns += [include("#<matchName>")];

        // Check if production can be scoped for higher accuracy
        Symbol s = label(_, symbol) := def ? symbol : def;
        scopes = {<begin, end> | /\prod(_, [*_, begin: lit(_), /s, end: lit(_), *_], _) := rules};
        if ({<begin, end>} := scopes) {
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

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, keywordRules()) {

    // Auxiliary function
    set[Symbol] getKeywordSymbols() {
        set[Symbol] symbols = {};
        visit (rscGrammar) {
            case s:   lit(/^\w+$/): symbols += s;
            case s: cilit(/^\w+$/): symbols += s;
        }
        return symbols;
    }

    Symbol def = ParseTree::keywords("");
    list[Symbol] symbols = [\alt(getKeywordSymbols())];
    set[Attr] attributes = {\tag("category"("keyword.control"))};
    
    Production p = \prod(def, symbols, attributes);
    RegExp re = prefix("\\b", suffix("\\b", toRegExp((), p))).val;
    
    Repository repository = ("_/keywords": toTmRule("_/keywords", re));
    list[Rule] patterns = [include("#_/keywords")];
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