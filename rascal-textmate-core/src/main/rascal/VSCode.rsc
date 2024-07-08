@synopsis{
    Main function to generate a new TextMate grammar for use in the special VS
    Code extension
}

module VSCode

import Grammar;
import lang::rascal::\syntax::Rascal;
import lang::textmate::Conversion;
import lang::textmate::Grammar;

int main() {
    str scopeName = "source.rascalmpl.injection";
    RscGrammar rsc = getRscGrammar();
    TmGrammar tm = toTmGrammar(rsc, scopeName)[injectionSelector = "R:source.rascalmpl"];
    toJSON(tm, indent = 2, l = |project://vscode-extension/syntaxes/rascal.tmLanguage.json|);
    return 0;
}

RscGrammar getRscGrammar() =
    visit (Grammar::grammar(#Module)) {
        // The following mapping is based on:
        //   - https://github.com/usethesource/rascal/blob/83023f60a6eb9df7a19ccc7a4194b513ac7b7157/src/org/rascalmpl/values/parsetrees/TreeAdapter.java#L44-L59
        //   - https://github.com/usethesource/rascal-language-servers/blob/752fea3ea09101e5b22ee426b11c5e36db880225/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java#L121-L142
        case \tag("category"("Normal"))           => \tag("category"("source"))
        case \tag("category"("Type"))             => \tag("category"("storage.type"))
        case \tag("category"("Identifier"))       => \tag("category"("variable"))
        case \tag("category"("Variable"))         => \tag("category"("variable"))
        case \tag("category"("Constant"))         => \tag("category"("constant"))
        case \tag("category"("Comment"))          => \tag("category"("comment"))
        case \tag("category"("Todo"))             => \tag("category"("comment"))
        case \tag("category"("Quote"))            => \tag("category"("meta.string"))
        case \tag("category"("MetaAmbiguity"))    => \tag("category"("invalid"))
        case \tag("category"("MetaVariable"))     => \tag("category"("variable"))
        case \tag("category"("MetaKeyword"))      => \tag("category"("keyword.other"))
        case \tag("category"("MetaSkipped"))      => \tag("category"("string"))
        case \tag("category"("NonterminalLabel")) => \tag("category"("variable.parameter"))
        case \tag("category"("Result"))           => \tag("category"("text"))
        case \tag("category"("StdOut"))           => \tag("category"("text"))
        case \tag("category"("StdErr"))           => \tag("category"("text"))
    };