module lang::textmate::conversiontests::RascalComment

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

lexical Comment
    = @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
    | @category="Comment" "//" ![\n]* !>> [\ \t\r \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000] $
    ;

Grammar rsc = preprocess(grammar(#Comment));

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Comment"),[lit("//"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\not-follow(\char-class([range(9,9),range(13,13),range(32,32),range(160,160),range(5760,5760),range(8192,8202),range(8239,8239),range(8287,8287),range(12288,12288)])),\end-of-line()})],{\tag("category"("Comment"))}), false, <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(lex("Comment"),[lit("/*"),\iter-star(alt({\char-class([range(1,41),range(43,1114111)]),conditional(lit("*"),{\not-follow(lit("/"))})})),lit("*/")],{\tag("category"("Comment"))}), true, <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <2, 1, 0>, name = "RascalComment");
