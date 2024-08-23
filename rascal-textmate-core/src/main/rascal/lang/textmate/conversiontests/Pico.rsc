module lang::textmate::conversiontests::Pico

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

import lang::pico::\syntax::Main;
Grammar rsc = preprocess(grammar(#Program));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(","),lit(")"),lit("("),lit("+"),lit("||"),lit(":="),lit("\""),lit(";"),lit("nil-type")})],{}), false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%%"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\end-of-line()})],{\tag("category"("Comment"))}), false, <nothing(),nothing()>, <just(lit("%%")),nothing()>),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%"),iter(\char-class([range(1,36),range(38,1114111)])),lit("%")],{\tag("category"("Comment"))}), true, <nothing(),nothing()>, <just(lit("%")),just(lit("%"))>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("do"),lit("declare"),lit("fi"),lit("else"),lit("end"),lit("od"),lit("begin"),lit("natural"),lit("then"),lit("if"),lit("while"),lit("string")})],{\tag("category"("keyword.control"))}), false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <4, 1, 0>, name = "Pico");