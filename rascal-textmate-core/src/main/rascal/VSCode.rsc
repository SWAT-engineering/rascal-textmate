module VSCode

import Grammar;
import lang::json::IO;
import lang::rascal::\syntax::Rascal;
import lang::textmate::Conversion;
import lang::textmate::Grammar;

int main() {
    str scopeName = "source.rascalmpl.injection";
    loc f = |project://vscode-extension/syntaxes/rascal.tmLanguage.json|;
    RscGrammar rsc = getRscGrammar();
    TmGrammar tm = toTmGrammar(rsc, scopeName)[injectionSelector="R:source.rascalmpl"];
    writeJSON(f, tm, indent=2);
    return 0;
}

RscGrammar getRscGrammar() =
    visit (Grammar::grammar(#Module)) {
        // The following mapping is based on:
        //   - https://github.com/usethesource/rascal/blob/83023f60a6eb9df7a19ccc7a4194b513ac7b7157/src/org/rascalmpl/values/parsetrees/TreeAdapter.java#L44-L59
        //   - https://github.com/usethesource/rascal-language-servers/blob/752fea3ea09101e5b22ee426b11c5e36db880225/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java#L121-L142
        // With updates based on:
        //   - https://github.com/eclipse-lsp4j/lsp4j/blob/f235e91fbe2e45f62e185bbb9f6d21bed48eb2b9/org.eclipse.lsp4j/src/main/java/org/eclipse/lsp4j/Protocol.xtend#L5639-L5695
        //   - https://github.com/usethesource/rascal-language-servers/blob/88be4a326128da8c81d581c2b918b4927f2185be/rascal-lsp/src/main/java/org/rascalmpl/vscode/lsp/util/SemanticTokenizer.java#L134-L152
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
    };