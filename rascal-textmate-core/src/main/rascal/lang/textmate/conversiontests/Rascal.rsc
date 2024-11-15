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
module lang::textmate::conversiontests::Rascal

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

import lang::rascal::\syntax::Rascal;
Grammar rsc = preprocess(grammar(#Module));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit(","),lit(")"),lit("("),lit("%"),lit("\<==\>"),lit("\<\<="),lit("!="),lit("\>="),lit("://"),lit("&="),lit("\<-"),lit("-="),lit("*="),lit("+="),lit("..."),lit("/="),lit("!:="),lit("$"),lit("!\<\<"),lit("=\>"),lit("!\>\>"),lit("||"),lit("\>\>"),lit("::"),lit("&&"),lit(":="),lit("#"),lit("?="),lit("\<:"),lit("==\>"),lit("^"),lit(";"),lit("{")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(label("stderrOutput",lex("Output")),[conditional(lit("⚠"),{\begin-of-line()}),\iter-star(\char-class([range(1,9),range(11,12),range(14,1114111)])),lit("\n")],{\tag("category"("string"))}), false, false, <nothing(),nothing()>, <just(lit("⚠")),just(lit("\n"))>),
    unit(rsc, prod(label("stdoutOutput",lex("Output")),[conditional(lit("≫"),{\begin-of-line()}),\iter-star(\char-class([range(1,9),range(11,12),range(14,1114111)])),lit("\n")],{\tag("category"("string"))}), false, false, <nothing(),nothing()>, <just(lit("≫")),just(lit("\n"))>),
    unit(rsc, prod(label("resultOutput",lex("Output")),[lit("⇨"),\iter-star(\char-class([range(1,9),range(11,12),range(14,1114111)])),lit("\n")],{\tag("category"("string"))}), false, false, <nothing(),nothing()>, <just(lit("⇨")),just(lit("\n"))>),
    unit(rsc, prod(label("bq",lex("ConcretePart")),[lit("\\`")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\`")),just(lit("\\`"))>),       
    unit(rsc, prod(label("bs",lex("ConcretePart")),[lit("\\\\")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\\")),just(lit("\\\\"))>),    
    unit(rsc, prod(label("gt",lex("ConcretePart")),[lit("\\\>")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\>")),just(lit("\\\>"))>),    
    unit(rsc, prod(label("hole",lex("ConcretePart")),[label("hole",sort("ConcreteHole"))],{\tag("category"("variable"))}), true, true, <just(lit("`")),just(lit("`"))>, <just(lit("\<")),just(lit("\>"))>),
    unit(rsc, prod(label("lt",lex("ConcretePart")),[lit("\\\<")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\<")),just(lit("\\\<"))>),    
    unit(rsc, prod(label("text",lex("ConcretePart")),[conditional(iter(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)])),{\not-follow(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)]))})],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Char"),[\char-class([range(1,31),range(33,33),range(35,38),range(40,44),range(46,59),range(61,61),range(63,90),range(94,1114111)])],{\tag("category"("string"))}), false, true, <just(lit("[")),just(lit("]"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Char"),[lex("UnicodeEscape")],{\tag("category"("string"))}), false, false, <just(lit("[")),just(lit("]"))>, <just(lit("\\")),nothing()>),
    unit(rsc, prod(lex("Char"),[lit("\\"),\char-class([range(32,32),range(34,34),range(39,39),range(45,45),range(60,60),range(62,62),range(91,93),range(98,98),range(102,102),range(110,110),range(114,114),range(116,116)])],{\tag("category"("string"))}), false, false, <just(lit("[")),just(lit("]"))>, <just(lit("\\")),nothing()>),
    unit(rsc, prod(label("default",sort("Tag")),[lit("@"),layouts("LAYOUTLIST"),label("name",lex("Name")),layouts("LAYOUTLIST"),label("contents",lex("TagString"))],{\tag("Folded"()),\tag("category"("comment"))}), true, true, <nothing(),nothing()>, <just(lit("@")),just(lit("}"))>),
    unit(rsc, prod(label("expression",sort("Tag")),[lit("@"),layouts("LAYOUTLIST"),label("name",lex("Name")),layouts("LAYOUTLIST"),lit("="),layouts("LAYOUTLIST"),conditional(label("expression",sort("Expression")),{\not-follow(lit("@"))})],{\tag("Folded"()),\tag("category"("comment"))}), true, true, <nothing(),nothing()>, <just(lit("@")),nothing()>),
    unit(rsc, prod(lex("MidStringChars"),[lit("\>"),\iter-star(lex("StringCharacter")),lit("\<")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\>")),just(lit("\<"))>),
    unit(rsc, prod(lex("PostStringChars"),[lit("\>"),\iter-star(lex("StringCharacter")),lit("\"")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\>")),just(lit("\""))>),
    unit(rsc, prod(lex("Comment"),[lit("//"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\not-follow(\char-class([range(9,9),range(13,13),range(32,32),range(160,160),range(5760,5760),range(8192,8202),range(8239,8239),range(8287,8287),range(12288,12288)])),\end-of-line()})],{\tag("category"("comment"))}), false, false, <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(lex("Comment"),[lit("/*"),\iter-star(alt({\char-class([range(1,41),range(43,1114111)]),conditional(lit("*"),{\not-follow(lit("/"))})})),lit("*/")],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>),
    unit(rsc, prod(lex("CaseInsensitiveStringConstant"),[lit("\'"),label("chars",\iter-star(lex("StringCharacter"))),lit("\'")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\'")),just(lit("\'"))>),
    unit(rsc, prod(lex("PreStringChars"),[lit("\""),\iter-star(lex("StringCharacter")),lit("\<")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\<"))>),
    unit(rsc, prod(lex("StringConstant"),[lit("\""),label("chars",\iter-star(lex("StringCharacter"))),lit("\"")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("lexical"),lit("loc"),lit("test"),lit("lrel"),lit("throws"),lit("clear"),lit("top-down-break"),lit("module"),lit("any"),lit("int"),lit("quit"),lit("bottom-up-break"),lit("o"),lit("anno"),lit("true"),lit("public"),lit("keyword"),lit("for"),lit("tuple"),lit("bracket"),lit("bag"),lit("it"),lit("visit"),lit("do"),lit("data"),lit("layout"),lit("bool"),lit("edit"),lit("join"),lit("is"),lit("import"),lit("view"),lit("in"),lit("rat"),lit("modules"),lit("continue"),lit("left"),lit("num"),lit("assert"),lit("throw"),lit("one"),lit("help"),lit("default"),lit("all"),lit("global"),lit("syntax"),lit("false"),lit("finally"),lit("private"),lit("mod"),lit("java"),lit("node"),lit("start"),lit("set"),lit("if"),lit("bottom-up"),lit("right"),lit("variable"),lit("map"),lit("10"),lit("on"),lit("break"),lit("dynamic"),lit("solve"),lit("fail"),lit("unimport"),lit("outermost"),lit("real"),lit("list"),lit("insert"),lit("innermost"),lit("declarations"),lit("else"),lit("rel"),lit("function"),lit("notin"),lit("filter"),lit("datetime"),lit("catch"),lit("try"),lit("renaming"),lit("tag"),lit("has"),lit("top-down"),lit("Z"),lit("when"),lit("type"),lit("append"),lit("extend"),lit("non-assoc"),lit("assoc"),lit("switch"),lit("void"),lit("history"),lit("T"),lit("while"),lit("str"),lit("value"),lit("undeclare"),lit("case"),lit("alias"),lit("return"),lit("0")})],{\tag("category"("keyword.control"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "Rascal");
test bool transformTest() = doTransformTest(units, <20, 4, 0>, name = "Rascal");
