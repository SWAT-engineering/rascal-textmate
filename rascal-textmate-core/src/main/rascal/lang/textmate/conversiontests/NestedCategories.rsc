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
module lang::textmate::conversiontests::NestedCategories

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

start syntax Start
    = A01 | A02 | A03 | A04 | A05 | A06 | A07 | A08 | A09 | A10 | A11 | A12;

lexical A01 = @category="a" B01 [\ ] C01;
lexical B01 = @category="b" D01 [\ ] "bar01";
lexical C01 = @category="c" D01 [\ ] "baz01";
lexical D01 = @category="d" "foo01";

lexical A02 = @category="a" B02 [\ ] C02;
lexical B02 = @category="b" D02 [\ ] "bar02";
lexical C02 = @category="c" D02 [\ ] "baz02";
lexical D02 =               "foo02";

lexical A03 = @category="a" B03 [\ ] C03;
lexical B03 = @category="b" D03 [\ ] "bar03";
lexical C03 =               D03 [\ ] "baz03";
lexical D03 = @category="d" "foo03";

lexical A04 = @category="a" B04 [\ ] C04;
lexical B04 = @category="b" D04 [\ ] "bar04";
lexical C04 =               D04 [\ ] "baz04";
lexical D04 =               "foo04";

lexical A05 = @category="a" B05 [\ ] C05;
lexical B05 =               D05 [\ ] "bar05";
lexical C05 =               D05 [\ ] "baz05";
lexical D05 = @category="d" "foo05";

lexical A06 = @category="a" B06 [\ ] C06;
lexical B06 =               D06 [\ ] "bar06";
lexical C06 =               D06 [\ ] "baz06";
lexical D06 =               "foo06";

lexical A07 =               B07 [\ ] C07;
lexical B07 = @category="b" D07 [\ ] "bar07";
lexical C07 = @category="c" D07 [\ ] "baz07";
lexical D07 = @category="d" "foo07";

lexical A08 =               B08 [\ ] C08;
lexical B08 = @category="b" D08 [\ ] "bar08";
lexical C08 = @category="c" D08 [\ ] "baz08";
lexical D08 =               "foo08";

lexical A09 =               B09 [\ ] C09;
lexical B09 = @category="b" D09 [\ ] "bar09";
lexical C09 =               D09 [\ ] "baz09";
lexical D09 = @category="d" "foo09"; // Design decision: D09 should be converted
                                     // to a TextMate rule, because it's
                                     // reachable via C09, which doesn't have a
                                     // category

lexical A10 =               B10 [\ ] C10;
lexical B10 = @category="b" D10 [\ ] "bar10";
lexical C10 =               D10 [\ ] "baz10";
lexical D10 =               "foo10";

lexical A11 =               B11 [\ ] C11;
lexical B11 =               D11 [\ ] "bar11";
lexical C11 =               D11 [\ ] "baz11";
lexical D11 = @category="d" "foo11";

lexical A12 =               B12 [\ ] C12;
lexical B12 =               D12 [\ ] "bar12";
lexical C12 =               D12 [\ ] "baz12";
lexical D12 =               "foo12";

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex("C07"),[lex("D07"),lit(" "),lit("baz07")],{\tag("category"("c"))}), false, false, <just(lit(" ")),nothing()>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("C08"),[lex("D08"),lit(" "),lit("baz08")],{\tag("category"("c"))}), false, false, <just(lit(" ")),nothing()>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("A01"),[lex("B01"),lit(" "),lex("C01")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("A02"),[lex("B02"),lit(" "),lex("C02")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("A03"),[lex("B03"),lit(" "),lex("C03")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("A04"),[lex("B04"),lit(" "),lex("C04")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("A05"),[lex("B05"),lit(" "),lex("C05")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("A06"),[lex("B06"),lit(" "),lex("C06")],{\tag("category"("a"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex("B07"),[lex("D07"),lit(" "),lit("bar07")],{\tag("category"("b"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("B08"),[lex("D08"),lit(" "),lit("bar08")],{\tag("category"("b"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("B09"),[lex("D09"),lit(" "),lit("bar09")],{\tag("category"("b"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("B10"),[lex("D10"),lit(" "),lit("bar10")],{\tag("category"("b"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),        
    unit(rsc, prod(lex("D09"),[lit("foo09")],{\tag("category"("d"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("D11"),[lit("foo11")],{\tag("category"("d"))}), false, false, <nothing(),just(lit(" "))>, <nothing(),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("foo07"),lit("foo06"),lit("foo09"),lit("foo08"),lit("foo03"),lit("foo02"),lit("foo05"),lit("foo04"),lit("foo10"),lit("baz09"),lit("foo11"),lit("baz06"),lit("baz05"),lit("baz08"),lit("baz07"),lit("baz02"),lit("baz04"),lit("baz03"),lit("bar06"),lit("bar05"),lit("bar02"),lit("bar04"),lit("bar03"),lit("bar11"),lit("bar10"),lit("foo12"),lit("foo01"),lit("baz12"),lit("baz01"),lit("bar09"),lit("baz11"),lit("bar08"),lit("baz10"),lit("bar07"),lit("bar12"),lit("bar01")})],{\tag("category"("keyword.control"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest() = doAnalyzeTest(rsc, units, name = "NestedCategories");
test bool transformTest() = doTransformTest(units, <15, 0, 0>, name = "NestedCategories");
