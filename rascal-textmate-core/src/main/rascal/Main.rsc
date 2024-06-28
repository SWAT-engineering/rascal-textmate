module Main

import Grammar;
import lang::json::IO;
import lang::textmate::Conversion;
import lang::textmate::Grammar;

int main(type[&T <: Tree] tree, str scopeName, loc f) {
    RscGrammar rsc = Grammar::grammar(tree);
    return main(rsc, scopeName, f);
}

int main(RscGrammar rsc, str scopeName, loc f) {
    TmGrammar tm = toTmGrammar(rsc, scopeName);
    writeJSON(f, tm, indent=2);
    return 0;
}