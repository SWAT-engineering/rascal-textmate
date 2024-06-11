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
    = singleLineSymbols()
    | keywordSymbols();

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, list[Mode] modes = [singleLineSymbols(), keywordSymbols()]) {
    TmGrammar tmGrammar0 = lang::textmate::Grammar::grammar((), name, []);
    list[TmGrammar] tmGrammars = [toTmGrammar(rscGrammar, name, m) | m <- modes];
    return (tmGrammar0 | merge(it, g) | g <- tmGrammars);
}

alias RegExps = map[Symbol, Maybe[RegExp]];

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, singleLineSymbols()) {    
    map[Symbol, Production] rules = rscGrammar.rules; 

    RegExps keepNonEmptySymbols(RegExps res)
        = (s: res[s] | s <- res, !tryParse(rules, s, ""));
    RegExps keepCategorySymbols(RegExps res)
        = (s: res[s] | s <- res, /\tag("category"(_)) := rules[s]);

    set[Symbol] singleLineSymbols = getSingleLineSymbols(rules);
    map[Symbol, Production] singleLineRules = domainR(rules, singleLineSymbols);
    
    RegExps regExps = toRegExps(singleLineRules);
    regExps = keepNonEmptySymbols(regExps);
    regExps = keepCategorySymbols(regExps);

    return lang::textmate::Grammar::grammar(
        ("<s>": toTmRule("<s>", regExps[s].val) | s <- regExps),
        name,
        [include("#<s>") | s <- regExps]);
}

TmGrammar toTmGrammar(RscGrammar rscGrammar, ScopeName name, keywordSymbols()) {

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
    
    Maybe[RegExp] maybe = prefix("\\b", suffix("\\b", toRegExp((), \choice(def, {p}))));
    return lang::textmate::Grammar::grammar(
        ("keywords": toTmRule("keywords", re) | just(re) := maybe),
        name,
        [include("#keywords") | just(_) := maybe]);
}

TmRule toTmRule(str name, regExp(string, groups)) =
    match(
        ungroup(string),
        name = name,
        captures = ("<n + 1>": ("name": groups[n]) | n <- [0..size(groups)]));