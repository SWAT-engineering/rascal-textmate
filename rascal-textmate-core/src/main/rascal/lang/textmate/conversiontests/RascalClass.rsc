module lang::textmate::conversiontests::RascalClass

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

// Based on `lang::rascal::\syntax::Rascal`

syntax Class
    = simpleCharclass: "[" Range* ranges "]" 
    | complement: "!" Class charClass 
    > left difference: Class lhs "-" Class rhs 
    > left intersection: Class lhs "&&" Class rhs 
    > left union: Class lhs "||" Class rhs 
    | bracket \bracket: "(" Class charClass ")"
    ;

syntax Range
    = fromTo: Char start "-" Char end 
    | character: Char character
    ;

lexical Char
    = @category="Constant" "\\" [\  \" \' \- \< \> \[ \\ \] b f n r t] 
    | @category="Constant" ![\  \" \' \- \< \> \[ \\ \]] 
    | @category="Constant" UnicodeEscape
    ;

lexical UnicodeEscape
    = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
    | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f]
    | ascii: "\\" [a] [0-7] [0-9A-Fa-f]
    ;

Grammar rsc = preprocess(grammar(#Class));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(")"),lit("("),lit("!"),lit("||"),lit("&&")})],{}), singleLine(), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Char"),[\char-class([range(1,31),range(33,33),range(35,38),range(40,44),range(46,59),range(61,61),range(63,90),range(94,1114111)])],{\tag("category"("Constant"))}), multiLine(), <just(lit("[")),just(lit("]"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Char"),[lex("UnicodeEscape")],{\tag("category"("Constant"))}), singleLine(), <just(lit("[")),just(lit("]"))>, <just(lit("\\")),nothing()>),
    unit(rsc, prod(lex("Char"),[lit("\\"),\char-class([range(32,32),range(34,34),range(39,39),range(45,45),range(60,60),range(62,62),range(91,93),range(98,98),range(102,102),range(110,110),range(114,114),range(116,116)])],{\tag("category"("Constant"))}), singleLine(), <just(lit("[")),just(lit("]"))>, <just(lit("\\")),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("10"),lit("0")})],{\tag("category"("keyword.control"))}), singleLine(), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <5, 1, 0>);
