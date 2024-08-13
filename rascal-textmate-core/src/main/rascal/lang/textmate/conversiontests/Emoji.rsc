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

Grammar rsc = preprocess(grammar(#Boolean));

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Boolean"),[lit("🙂")],{\tag("category"("constant.language"))}), singleLine(), <nothing(),nothing()>, <just(lit("🙂")),just(lit("🙂"))>),
    unit(rsc, prod(lex("Boolean"),[lit("🙁")],{\tag("category"("constant.language"))}), singleLine(), <nothing(),nothing()>, <just(lit("🙁")),just(lit("🙁"))>),
    unit(rsc, prod(lex("Unit"),[lit("🌊")],{\tag("category"("constant.language"))}), singleLine(), <nothing(),nothing()>, <just(lit("🌊")),just(lit("🌊"))>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <3, 0, 0>, name = "Emoji");
