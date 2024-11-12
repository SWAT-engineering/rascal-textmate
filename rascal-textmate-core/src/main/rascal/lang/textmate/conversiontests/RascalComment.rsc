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
module lang::textmate::conversiontests::RascalComment

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

start syntax Start = Comment;

lexical Comment
    = @category="Comment" "/*" (![*] | [*] !>> [/])* "*/" 
    | @category="Comment" "//" ![\n]* !>> [\ \t\r \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000] $
    ;

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex("Comment"),[lit("//"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\not-follow(\char-class([range(9,9),range(13,13),range(32,32),range(160,160),range(5760,5760),range(8192,8202),range(8239,8239),range(8287,8287),range(12288,12288)])),\end-of-line()})],{\tag("category"("comment"))}), false, false, <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(lex("Comment"),[lit("/*"),\iter-star(alt({\char-class([range(1,41),range(43,1114111)]),conditional(lit("*"),{\not-follow(lit("/"))})})),lit("*/")],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "RascalComment");
test bool transformTest() = doTransformTest(units, <2, 1, 0>, name = "RascalComment");
