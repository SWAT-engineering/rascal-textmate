module lang::textmate::conversiontests::RascalStringConstant

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

lexical StringConstant
    = @category="Constant" "\"" StringCharacter* chars "\"" ;

lexical StringCharacter
    = "\\" [\" \' \< \> \\ b f n r t] 
    | UnicodeEscape 
    | ![\" \' \< \> \\]
    | [\n][\ \t \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000]* [\']
    ;

lexical UnicodeEscape
    = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
    | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f]
    | ascii: "\\" [a] [0-7] [0-9A-Fa-f]
    ;

Grammar rsc = preprocess(grammar(#StringConstant));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("\n"),lit("\'"),lit("\\")})],{}), false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("StringConstant"),[lit("\""),label("chars",\iter-star(lex("StringCharacter"))),lit("\"")],{\tag("category"("Constant"))}), true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("10"),lit("0")})],{\tag("category"("keyword.control"))}), false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 1, 0>, name = "RascalStringConstant");
