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
module lang::textmate::conversiontests::RascalStringLiteral

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

start syntax Start = StringLiteral;

syntax StringLiteral
    = template: PreStringChars pre StringTemplate template StringTail tail 
    | interpolated: PreStringChars pre Expression expression StringTail tail 
    | nonInterpolated: StringConstant constant;

lexical PreStringChars
    = @category="Constant" [\"] StringCharacter* [\<];

lexical MidStringChars
    = @category="Constant" [\>] StringCharacter* [\<];

lexical PostStringChars
    = @category="Constant" [\>] StringCharacter* [\"];

lexical StringConstant
    = @category="Constant" "\"" StringCharacter* chars "\"" ;

syntax StringTemplate
    = ifThen    : "if"    "(" {Expression ","}+ conditions ")" "{" Statement* preStats StringMiddle body Statement* postStats "}" 
    | ifThenElse: "if"    "(" {Expression ","}+ conditions ")" "{" Statement* preStatsThen StringMiddle thenString Statement* postStatsThen "}" "else" "{" Statement* preStatsElse StringMiddle elseString Statement* postStatsElse "}" 
    | \for      : "for"   "(" {Expression ","}+ generators ")" "{" Statement* preStats StringMiddle body Statement* postStats "}" 
    | doWhile   : "do"    "{" Statement* preStats StringMiddle body Statement* postStats "}" "while" "(" Expression condition ")" 
    | \while    : "while" "(" Expression condition ")" "{" Statement* preStats StringMiddle body Statement* postStats "}";

syntax StringMiddle
    = mid: MidStringChars mid 
    | template: MidStringChars mid StringTemplate template StringMiddle tail 
    | interpolated: MidStringChars mid Expression expression StringMiddle tail;

syntax StringTail
    = midInterpolated: MidStringChars mid Expression expression StringTail tail 
    | post: PostStringChars post 
    | midTemplate: MidStringChars mid StringTemplate template StringTail tail;

lexical StringCharacter
    = "\\" [\" \' \< \> \\ b f n r t] 
    | UnicodeEscape 
    | ![\" \' \< \> \\]
    | [\n][\ \t \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000]* [\'];

lexical UnicodeEscape
    = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
    | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f]
    | ascii: "\\" [a] [0-7] [0-9A-Fa-f];

syntax Statement
    = emptyStatement: ";";

syntax Expression
    = nonEmptyBlock: "{" Statement+ statements "}"
	> non-assoc ( greaterThanOrEq: Expression lhs "\>=" Expression rhs  
		        | lessThanOrEq   : Expression lhs "\<=" Expression rhs 
		        | lessThan       : Expression lhs "\<" !>> "-" Expression rhs 
		        | greaterThan    : Expression lhs "\>" Expression rhs );

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(","),lit(")"),lit("("),lit("\n"),lit("\'"),lit("\<="),lit("}"),lit("\\"),lit("\>="),lit(";"),lit("{")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("MidStringChars"),[lit("\>"),\iter-star(lex("StringCharacter")),lit("\<")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\>")),just(lit("\<"))>),
    unit(rsc, prod(lex("PostStringChars"),[lit("\>"),\iter-star(lex("StringCharacter")),lit("\"")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\>")),just(lit("\""))>),
    unit(rsc, prod(lex("PreStringChars"),[lit("\""),\iter-star(lex("StringCharacter")),lit("\<")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\<"))>),
    unit(rsc, prod(lex("StringConstant"),[lit("\""),label("chars",\iter-star(lex("StringCharacter"))),lit("\"")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("for"),lit("do"),lit("if"),lit("10"),lit("else"),lit("while"),lit("0")})],{\tag("category"("keyword.control"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "RascalStringLiteral");
test bool transformTest() = doTransformTest(units, <6, 0, 0>, name = "RascalStringLiteral");
