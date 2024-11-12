@license{
BSD 2-Clause License

Copyright (c) 2024, Swat.engineering

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}
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