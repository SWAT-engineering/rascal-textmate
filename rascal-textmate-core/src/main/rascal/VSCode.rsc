module VSCode

import Grammar;
import IO;
import lang::json::IO;
import lang::rascal::\syntax::Rascal;
import lang::textmate::Convert;
import lang::textmate::Grammar;

int main() {
    str name = "source.rascalmpl.injection";
    loc f = |project://vscode-extension/syntaxes/rascal.tmLanguage.json|;
    
    RscGrammar rscGrammar = Grammar::grammar(#Module);
    TmGrammar tmGrammar = toTmGrammar(rscGrammar, name)[injectionSelector="L:source.rascalmpl"];

    writeJSON(f, tmGrammar, indent=2);
    // println(asJSON(tmGrammar, indent=2));
    return 0;
}