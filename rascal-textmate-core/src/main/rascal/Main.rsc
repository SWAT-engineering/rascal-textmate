module Main

import Grammar;
import IO;
import lang::json::IO;
import lang::textmate::Convert;
import lang::textmate::Grammar;

int main(type[&T <: Tree] tree, str name, loc f) {
    RscGrammar rscGrammar = Grammar::grammar(tree);
    TmGrammar tmGrammar = toTmGrammar(rscGrammar, name);
    
    writeJSON(f, tmGrammar, indent=2);
    // println(asJSON(tmGrammar, indent=2));   
    return 0;
}