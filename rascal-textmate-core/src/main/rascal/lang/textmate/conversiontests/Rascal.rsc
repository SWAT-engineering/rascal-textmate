module lang::textmate::conversiontests::Rascal

import Grammar;
import ParseTree;
import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

import lang::rascal::\syntax::Rascal;
Grammar rsc = grammar(#Module);

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("bottom-up-break"),lit(")"),lit("≫"),lit("\n"),lit("!:="),lit("\'"),lit("!="),lit("\>="),lit("://"),lit("non-assoc"),lit("&="),lit("\<-"),lit("*="),lit("+="),lit("top-down-break"),lit(","),lit("..."),lit("/="),lit("⇨"),lit("("),lit("*/"),lit("%"),lit("!\<\<"),lit("=\>"),lit("!\>\>"),lit("||"),lit("\>\>"),lit("::"),lit("⚠"),lit("&&"),lit("@"),lit(":="),lit("#"),lit("\<==\>"),lit("\""),lit("\<\<="),lit("}"),lit("?="),lit("\<:"),lit("==\>"),lit("^"),lit("/*"),lit(";"),lit("{"),lit("-="),lit("$T")})],{})),
    unit(rsc, prod(label("gt",lex("ConcretePart")),[lit("\\\>")],{\tag("category"("MetaSkipped"))})),
    unit(rsc, prod(label("text",lex("ConcretePart")),[conditional(iter(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)])),{\not-follow(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)]))})],{\tag("category"("MetaSkipped"))})),
    unit(rsc, prod(lex("Comment"),[lit("//"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\not-follow(\char-class([range(9,9),range(13,13),range(32,32),range(160,160),range(5760,5760),range(8192,8202),range(8239,8239),range(8287,8287),range(12288,12288)])),\end-of-line()})],{\tag("category"("Comment"))})),
    unit(rsc, prod(lex("Char"),[lit("\\"),\char-class([range(32,32),range(34,34),range(39,39),range(45,45),range(60,60),range(62,62),range(91,93),range(98,98),range(102,102),range(110,110),range(114,114),range(116,116)])],{\tag("category"("Constant"))})),
    unit(rsc, prod(label("lt",lex("ConcretePart")),[lit("\\\<")],{\tag("category"("MetaSkipped"))})),
    unit(rsc, prod(label("bq",lex("ConcretePart")),[lit("\\`")],{\tag("category"("MetaSkipped"))})),
    unit(rsc, prod(lex("Char"),[lex("UnicodeEscape")],{\tag("category"("Constant"))})),
    unit(rsc, prod(label("bs",lex("ConcretePart")),[lit("\\\\")],{\tag("category"("MetaSkipped"))})),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("lexical"),lit("loc"),lit("if"),lit("assoc"),lit("test"),lit("lrel"),lit("throws"),lit("clear"),lit("module"),lit("any"),lit("int"),lit("quit"),lit("o"),lit("anno"),lit("true"),lit("public"),lit("keyword"),lit("for"),lit("tuple"),lit("bracket"),lit("bag"),lit("it"),lit("visit"),lit("do"),lit("data"),lit("layout"),lit("bool"),lit("edit"),lit("join"),lit("is"),lit("import"),lit("view"),lit("in"),lit("rat"),lit("modules"),lit("continue"),lit("left"),lit("num"),lit("assert"),lit("throw"),lit("one"),lit("help"),lit("default"),lit("all"),lit("global"),lit("syntax"),lit("false"),lit("finally"),lit("private"),lit("mod"),lit("java"),lit("node"),lit("start"),lit("set"),lit("right"),lit("variable"),lit("map"),lit("10"),lit("on"),lit("break"),lit("dynamic"),lit("solve"),lit("fail"),lit("unimport"),lit("outermost"),lit("real"),lit("list"),lit("insert"),lit("innermost"),lit("declarations"),lit("else"),lit("rel"),lit("function"),lit("notin"),lit("filter"),lit("datetime"),lit("catch"),lit("try"),lit("renaming"),lit("tag"),lit("has"),lit("Z"),lit("when"),lit("type"),lit("append"),lit("extend"),lit("switch"),lit("void"),lit("history"),lit("T"),lit("while"),lit("str"),lit("value"),lit("undeclare"),lit("case"),lit("alias"),lit("return"),lit("0")})],{\tag("category"("keyword.control"))}))
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 2, 0>);
