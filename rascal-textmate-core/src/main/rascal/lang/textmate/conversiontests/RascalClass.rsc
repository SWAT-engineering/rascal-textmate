module lang::textmate::conversiontests::RascalClass

import Grammar;
import ParseTree;
import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

// Based on `lang::rascal::\syntax::Rascal`

syntax Class
    = simpleCharclass: "[" Range* ranges "]" 
    | complement: "!" Class charClass 
    > left difference: Class lhs "-" Class rhs 
    > left intersection: Class lhs "&&" Class rhs 
    > left union: Class lhs "||" Class rhs 
    | bracket \bracket: "(" Class charClass ")";

syntax Range
    = fromTo: Char start "-" Char end 
    | character: Char character;

lexical Char
    = @category="Constant" "\\" [\  \" \' \- \< \> \[ \\ \] b f n r t] 
    | @category="Constant" ![\  \" \' \- \< \> \[ \\ \]] 
    | @category="Constant" UnicodeEscape;

lexical UnicodeEscape
    = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
    | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] // 24 bits 
    | ascii: "\\" [a] [0-7] [0-9A-Fa-f];

Grammar rsc = grammar(#Class);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Char"),[lit("\\"),\char-class([range(32,32),range(34,34),range(39,39),range(45,45),range(60,60),range(62,62),range(91,93),range(98,98),range(102,102),range(110,110),range(114,114),range(116,116)])],{\tag("category"("Constant"))})),
    unit(rsc, prod(lex("Char"),[lex("UnicodeEscape")],{\tag("category"("Constant"))})),
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(")"),lit("("),lit("!"),lit("]"),lit("\\"),lit("["),lit("||"),lit("&&")})],{})),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("10"),lit("0")})],{\tag("category"("keyword.control"))}))
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <2, 1, 0>);
