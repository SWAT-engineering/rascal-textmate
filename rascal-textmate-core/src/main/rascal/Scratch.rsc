module Scratch

import Grammar;
import IO;
import lang::json::IO;
import lang::textmate::Convert;
import lang::textmate::Grammar;

keyword Keyword = "if" | "then" | "else";

lexical Boolean
    = @category="comment" x: "true"
    | @category="comment" "false"
    ;


// lexical FooBar
//     = @category="comment" x: "foo"
//     | @category="comment" "bar"
//     ;

lexical BooleanWithout = Boolean!x;

lexical Variable = @category="comment" Id;
lexical Id = [a-z]*;

// lexical String = @category="string" [\"] [a-z A-Z 0-9 _]* content [\"];

// lexical Identifier = [a-z] !<< [a-z A-Z 0-9 _]+ !>> [a-z A-Z 0-9 _] \ Keyword;

// // lexical Declaration = Variable [\ ]* ":" [\ ]* Type;

// lexical Type = @category="storage.type" Identifier;
// lexical Variable = @category="variable" Identifier;

// lexical Quoted[&T] = "\'" &T "\'";
// lexical Quoted2[&T, &U] = "\'" &T [\ ] &U "\'";
// lexical QuotedBoolean = Quoted[Boolean];
// lexical QuotedBooleanBoolean = Quoted2[Boolean, Identifier];

// lexical Value
//     = Boolean
//     | String
//     ;

// syntax List = {Identifier ([\ ]* "," [\ ]*)}*;

// lexical Comment1
// 	= @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" ;

// lexical Comment2
//     = @category="comment" "//" ![\n]* $;

// lexical Comment
// 	= @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
// 	| @category="Comment" "//" ![\n]* !>> [\ \t\r \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000] $ // the restriction helps with parsing speed
// 	;


int main() {
    str name = "source.rascalmpl.injection";
    loc f = |project://vscode-extension/syntaxes/rascal.tmLanguage.json|;
    
    RscGrammar rscGrammar = Grammar::grammar(#Boolean);
    TmGrammar tmGrammar = toTmGrammar(rscGrammar, name)[injectionSelector="L:source.rascalmpl"];

    writeJSON(f, tmGrammar, indent=2);
    // println(asJSON(tmGrammar, indent=2));
    return 0;
}