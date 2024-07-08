@synopsis{
    Main functions to generate TextMate grammars for Rascal grammars
}

module Main

import Grammar;
import lang::textmate::Conversion;
import lang::textmate::Grammar;

int main(type[&T <: Tree] tree, str scopeName, loc f) {
    RscGrammar rsc = Grammar::grammar(tree);
    return main(rsc, scopeName, f);
}

int main(RscGrammar rsc, str scopeName, loc l) {
    TmGrammar tm = toTmGrammar(rsc, scopeName);
    toJSON(tm, indent = 2, l = l);
    return 0;
}