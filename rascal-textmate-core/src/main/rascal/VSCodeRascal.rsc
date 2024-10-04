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
        // Temporarily hot-patch Rascal's own grammar as discussed here:
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