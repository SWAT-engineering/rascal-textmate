@synopsis{
    Main function to generate a new TextMate grammar for Rascal, to be used in
    the special VS Code extension
}

module VSCodeRascal

import Grammar;
import Main;
extend lang::textmate::conversiontests::Rascal;

int main() = Main::main(getRscGrammar(), "source.rascalmpl", |project://vscode-extension/syntaxes/rascal.tmLanguage.json|);

// Relevant comment regarding grammar precedence in VS Code:
//   - https://github.com/microsoft/vscode-docs/issues/2862#issuecomment-599994967

private Grammar getRscGrammar() {
    Production setCategory(p: prod(_, _, attributes), str category)
        = {\tag("category"(_)), *rest} := attributes
        ? p[attributes = rest + \tag("category"(category))]
        : p[attributes = attributes + \tag("category"(category))];
    
    return visit (rsc) {

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

        // With additional hot-patching as discussed:
        //   - https://github.com/SWAT-engineering/rascal-textmate/pull/6
        case p: prod(label("integer",  sort("Literal")), _, _)   => setCategory(p, "constant.numeric")
        case p: prod(label("real",     sort("Literal")), _, _)   => setCategory(p, "constant.numeric")
        case p: prod(label("rational", sort("Literal")), _, _)   => setCategory(p, "constant.numeric")
        case p: prod(label("location", sort("Literal")), _, _)   => setCategory(p, "markup.underline.link")
        case p: prod(label("regExp",   sort("Literal")), _, _)   => setCategory(p, "constant.regexp")
        case p: prod(lex("StringConstant"), _, _)                => setCategory(p, "string.quoted.double")
        case p: prod(lex("CaseInsensitiveStringConstant"), _, _) => setCategory(p, "string.quoted.single")
        case p: prod(lex("PreStringChars"), _, _)                => setCategory(p, "string.quoted.double")
        case p: prod(lex("MidStringChars"), _, _)                => setCategory(p, "string.quoted.double")
        case p: prod(lex("PostStringChars"), _, _)               => setCategory(p, "string.quoted.double")
    };
}