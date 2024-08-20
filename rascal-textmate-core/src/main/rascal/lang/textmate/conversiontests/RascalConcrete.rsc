module lang::textmate::conversiontests::RascalConcrete

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

// Based on `lang::rascal::\syntax::Rascal`

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
    = \one: "\<" [\n] /* Sym symbol Name name */ "\>";

Grammar rsc = grammar(#Concrete);

list[ConversionUnit] units = [
    unit(rsc, prod(label("bq",lex("ConcretePart")),[lit("\\`")],{\tag("category"("MetaSkipped"))}), <just(lit("`")),just(lit("`"))>, <just(lit("\\`")),just(lit("\\`"))>),
    unit(rsc, prod(label("bs",lex("ConcretePart")),[lit("\\\\")],{\tag("category"("MetaSkipped"))}), <just(lit("`")),just(lit("`"))>, <just(lit("\\\\")),just(lit("\\\\"))>),
    unit(rsc, prod(label("gt",lex("ConcretePart")),[lit("\\\>")],{\tag("category"("MetaSkipped"))}), <just(lit("`")),just(lit("`"))>, <just(lit("\\\>")),just(lit("\\\>"))>),
    unit(rsc, prod(label("hole",lex("ConcretePart")),[label("hole",sort("ConcreteHole"))],{\tag("category"("MetaVariable"))}), <just(lit("`")),just(lit("`"))>, <just(lit("\<")),just(lit("\>"))>),
    unit(rsc, prod(label("lt",lex("ConcretePart")),[lit("\\\<")],{\tag("category"("MetaSkipped"))}), <just(lit("`")),just(lit("`"))>, <just(lit("\\\<")),just(lit("\\\<"))>),
    unit(rsc, prod(label("text",lex("ConcretePart")),[conditional(iter(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)])),{\not-follow(\char-class([range(1,9),range(11,59),range(61,61),range(63,91),range(93,95),range(97,1114111)]))})],{\tag("category"("MetaSkipped"))}), <just(lit("`")),just(lit("`"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("\n"),lit("\\`"),lit("\'"),lit("\\\>"),lit("\<"),lit("\>"),lit("\\\\"),lit("\\\<"),lit("`")})],{}), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <1, 1, 0>);
