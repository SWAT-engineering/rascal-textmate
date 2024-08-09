module lang::textmate::conversiontests::Emoji

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

lexical Unit
    = @category="constant.language" [🌊];

lexical Boolean
    = @category="constant.language" [🙂]
    | @category="constant.language" [🙁];

Grammar rsc = grammar(#Boolean);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Boolean"),[\char-class([range(128577,128577)])],{\tag("category"("constant.language"))}), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Boolean"),[\char-class([range(128578,128578)])],{\tag("category"("constant.language"))}), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("Unit"),[\char-class([range(127754,127754)])],{\tag("category"("constant.language"))}), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 0, 0>, name = "Emoji");
