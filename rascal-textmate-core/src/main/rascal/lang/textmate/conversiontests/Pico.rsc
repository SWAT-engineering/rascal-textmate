module lang::textmate::conversiontests::Pico

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

import lang::pico::\syntax::Main;
Grammar rsc = grammar(#Program);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%%"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\end-of-line()})],{\tag("category"("Comment"))}), <nothing(),nothing()>, <just(lit("%%")),nothing()>),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%"),iter(\char-class([range(1,36),range(38,1114111)])),lit("%")],{\tag("category"("Comment"))}), <nothing(),nothing()>, <just(lit("%")),just(lit("%"))>),
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(","),lit(")"),lit("("),lit("+"),lit("%"),lit(":="),lit("\""),lit(";"),lit(":"),lit("nil-type"),lit("||"),lit("%%")})],{}), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("do"),lit("declare"),lit("fi"),lit("else"),lit("end"),lit("od"),lit("begin"),lit("natural"),lit("then"),lit("if"),lit("while"),lit("string")})],{\tag("category"("keyword.control"))}), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <4, 0, 0>, name = "Pico");