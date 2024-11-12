@license{
BSD 2-Clause License

Copyright (c) 2024, Swat.engineering

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}
module lang::textmate::conversiontests::Emoji

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

start syntax Start
    = Unit
    | Boolean
    ;

lexical Unit
    = @category="constant.language" [🌊];

lexical Boolean
    = @category="constant.language" [🙂]
    | @category="constant.language" [🙁]
    ;

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Boolean"),[lit("🙂")],{\tag("category"("constant.language"))}), false, false, <nothing(),nothing()>, <just(lit("🙂")),just(lit("🙂"))>),
    unit(rsc, prod(lex("Boolean"),[lit("🙁")],{\tag("category"("constant.language"))}), false, false, <nothing(),nothing()>, <just(lit("🙁")),just(lit("🙁"))>),
    unit(rsc, prod(lex("Unit"),[lit("🌊")],{\tag("category"("constant.language"))}), false, false, <nothing(),nothing()>, <just(lit("🌊")),just(lit("🌊"))>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "Emoji");
test bool transformTest() = doTransformTest(units, <3, 0, 0>, name = "Emoji");
