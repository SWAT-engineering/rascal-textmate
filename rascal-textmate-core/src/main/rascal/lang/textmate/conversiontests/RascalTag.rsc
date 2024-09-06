module lang::textmate::conversiontests::RascalTag

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::rascal::\syntax::Rascal`

syntax Tag
	= @Folded @category="Comment" \default  : "@" Name name TagString contents
	| @Folded @category="Comment" empty     : "@" Name name 
	| @Folded @category="Comment" expression: "@" Name name "=" Expression expression !>> "@"
    ;

lexical Name
	=  ([A-Z a-z _] !<< [A-Z _ a-z] [0-9 A-Z _ a-z]* !>> [0-9 A-Z _ a-z]) /* \ RascalKeywords */
	| [\\] [A-Z _ a-z] [\- 0-9 A-Z _ a-z]* !>> [\- 0-9 A-Z _ a-z] 
	;

lexical TagString
	= "\\" !<< "{" ( ![{}] | ("\\" [{}]) | TagString)* contents "\\" !<< "}";

syntax Expression
    = nonEmptyBlock: "{" Statement+ statements "}";

syntax Statement
    = emptyStatement: ";";

lexical LAYOUT
	= [\u0009-\u000D \u0020 \u0085 \u00A0 \u1680 \u180E \u2000-\u200A \u2028 \u2029 \u202F \u205F \u3000];

layout LAYOUTLIST
	= LAYOUT* !>> [\u0009-\u000D \u0020 \u0085 \u00A0 \u1680 \u180E \u2000-\u200A \u2028 \u2029 \u202F \u205F \u3000] /* !>> "//" !>> "/*" */;

Grammar rsc = preprocess(grammar(#Tag));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("="),lit("\\"),lit(";"),lit("{")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(label("default",sort("Tag")),[lit("@"),layouts("LAYOUTLIST"),label("name",lex("Name")),layouts("LAYOUTLIST"),label("contents",lex("TagString"))],{\tag("Folded"()),\tag("category"("Comment"))}), true, true, <nothing(),nothing()>, <just(lit("@")),just(lit("}"))>),
    unit(rsc, prod(label("expression",sort("Tag")),[lit("@"),layouts("LAYOUTLIST"),label("name",lex("Name")),layouts("LAYOUTLIST"),lit("="),layouts("LAYOUTLIST"),conditional(label("expression",sort("Expression")),{\not-follow(lit("@"))})],{\tag("Folded"()),\tag("category"("Comment"))}), false, true, <nothing(),nothing()>, <just(lit("@")),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <2, 1, 0>, name = "RascalTag");
