module lang::textmate::Convert

import Grammar;
import ParseTree;
import util::Maybe;

import lang::oniguruma::Convert;
import lang::oniguruma::RegExp;
import lang::rascal::SingleLine;
import lang::textmate::Grammar;

alias TmGrammar = lang::textmate::Grammar::Grammar;
alias RscGrammar = Grammar::Grammar;

RegExpString simplify(RegExpString old) =
    /^\(\?:<new:.*>\)$/ := old ? new : old;

Rule toRule(str name, regExp(string, groups)) =
    match(simplify(string), name=name, captures = ("<n + 1>": ("name": groups[n]) | n <- [0..size(groups)]));

data Mode
    = singleLineSymbols()
    | keywordSymbols();

TmGrammar toTextMate(RscGrammar rscGrammar, ScopeName name, list[Mode] modes = [singleLineSymbols(), keywordSymbols()]) {
    TmGrammar tmGrammar0 = lang::textmate::Grammar::grammar((), name, []);
    list[TmGrammar] tmGrammars = [toTextMate(rscGrammar, name, m) | m <- modes];
    return (tmGrammar0 | merge(it, g) | g <- tmGrammars);
}

alias RegExps = map[Symbol, Maybe[RegExp]];

TmGrammar toTextMate(RscGrammar rscGrammar, ScopeName name, singleLineSymbols()) {    
    
    RegExps keepNonEmptySymbols(RegExps res)
        = res; // TODO;
    RegExps keepCategorySymbols(RegExps res) // TODO: ignore "" categories
        = (s: res[s] | s <- res, just(regExp(_, [_, *_])) := res[s]);

    set[Symbol] singleLineSymbols = getSingleLineSymbols(rscGrammar.rules);
    map[Symbol, Production] rules = (s: rscGrammar.rules[s] | s <- rscGrammar.rules, s in singleLineSymbols); 
    
    RegExps regExps = toRegExps(rules);    
    regExps = keepNonEmptySymbols(regExps);
    regExps = keepCategorySymbols(regExps);

    return lang::textmate::Grammar::grammar(
        ("<s>": toRule("<s>", regExps[s].val) | s <- regExps),
        name,
        [include("#<s>") | s <- regExps]);
}

TmGrammar toTextMate(RscGrammar rscGrammar, ScopeName name, keywordSymbols()) {

    set[Symbol] getKeywordSymbols() {
        set[Symbol] symbols = {};
        visit (rscGrammar) {
            case s: lit(string):
                symbols += /^\w+$/ := string ? {s} : {};
            case s: cilit(string):
                symbols += /^\w+$/ := string ? {s} : {};
        }
        return symbols;
    }

    Symbol def = ParseTree::keywords("");
    list[Symbol] symbols = [\alt(getKeywordSymbols())];
    set[Attr] attributes = {\tag("category"("keyword.control"))};
    Production p = \prod(def, symbols, attributes);

    return lang::textmate::Grammar::grammar(
        ("keywords": toRule("keywords", re) | just(re) := toRegExp((), \choice(def, {p}))),
        name,
        [include("#keywords")]);
}