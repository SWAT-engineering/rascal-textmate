module lang::textmate::conversiontests::Pico

import Grammar;
import ParseTree;
import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

import lang::pico::\syntax::Main;
Grammar rsc = grammar(#Program);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("delimiters"),[alt({lit("-"),lit(","),lit("+"),lit("||"),lit(":="),lit("\""),lit(";"),lit("nil-type")})],{})),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%%"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\end-of-line()})],{\tag("category"("Comment"))}), ignoreDelimiterPairs = true),
    unit(rsc, prod(lex("keywords"),[alt({lit("do"),lit("declare"),lit("fi"),lit("else"),lit("end"),lit("od"),lit("begin"),lit("natural"),lit("then"),lit("if"),lit("while"),lit("string")})],{\tag("category"("keyword.control"))}))
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 0, 0>);