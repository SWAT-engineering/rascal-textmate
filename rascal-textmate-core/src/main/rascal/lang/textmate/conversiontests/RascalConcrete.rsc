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
module lang::textmate::conversiontests::RascalConcrete

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

start syntax Start = Concrete;

lexical Concrete 
    = typed: /* "(" LAYOUTLIST l1 Sym symbol LAYOUTLIST l2 ")" LAYOUTLIST l3 */ "`" ConcretePart* parts "`";

lexical ConcretePart
    = @category="MetaSkipped" text   : ![`\<\>\\\n]+ !>> ![`\<\>\\\n]
    | newline: "\n" [\ \t \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000]* "\'"
    | @category="MetaVariable" hole : ConcreteHole hole
    | @category="MetaSkipped" lt: "\\\<"
    | @category="MetaSkipped" gt: "\\\>"
    | @category="MetaSkipped" bq: "\\`"
    | @category="MetaSkipped" bs: "\\\\"
    ;
  
syntax ConcreteHole 
    = \one: "\<" /* Sym symbol Name name */ "\>";

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("\n"),lit("\'")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),     
    unit(rsc, prod(label("bq",lex("ConcretePart")),[lit("\\`")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\`")),just(lit("\\`"))>),
    unit(rsc, prod(label("bs",lex("ConcretePart")),[lit("\\\\")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\\")),just(lit("\\\\"))>),
    unit(rsc, prod(label("gt",lex("ConcretePart")),[lit("\\\>")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\>")),just(lit("\\\>"))>),
    unit(rsc, prod(label("hole",lex("ConcretePart")),[label("hole",sort("ConcreteHole"))],{\tag("category"("variable"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\<")),just(lit("\>"))>),
    unit(rsc, prod(label("lt",lex("ConcretePart")),[lit("\\\<")],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <just(lit("\\\<")),just(lit("\\\<"))>),
    unit(rsc, prod(label("text",lex("ConcretePart")),[conditional(iter(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)])),{\not-follow(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)]))})],{\tag("category"("string"))}), false, false, <just(lit("`")),just(lit("`"))>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "RascalConcrete");
test bool transformTest() = doTransformTest(units, <7, 1, 0>, name = "RascalConcrete");
