module lang::textmate::conversiontests::RascalComment

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

// Based on `lang::rascal::\syntax::Rascal`

lexical Comment
    = @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
    | @category="Comment" "//" ![\n]* !>> [\ \t\r \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000] $
    ;

Grammar rsc = grammar(#Comment);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Comment"),[lit("//"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\not-follow(\char-class([range(9,9),range(13,13),range(32,32),range(160,160),range(5760,5760),range(8192,8202),range(8239,8239),range(8287,8287),range(12288,12288)])),\end-of-line()})],{\tag("category"("Comment"))}), <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(lex("Comment"),[lit("/*"),\iter-star(alt({conditional(\char-class([range(42,42)]),{\not-follow(\char-class([range(47,47)]))}),\char-class([range(1,41),range(43,1114111)])})),lit("*/")],{\tag("category"("Comment"))}), <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>),
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("*/"),lit("//"),lit("/*")})],{}), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 0, 0>, name = "RascalComment");
