module lang::textmate::conversiontests::PicoWithCategories

import Grammar;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;

// Based on `lang::pico::\syntax::Main`

start syntax Program 
    = program: "begin" Declarations decls {Statement ";"}* body "end";

syntax Declarations 
    = "declare" {IdType ","}* decls ";";  
 
syntax IdType = idtype: Id id ":" Type t;

syntax Statement 
    = assign: Id var ":=" Expression val 
    | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "else" {Statement ";"}* elsePart "fi"
    | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "fi"
    | loop: "while" Expression cond "do" {Statement ";"}* body "od"
    ;
     
syntax Type 
    = @category="storage.type" natural: "natural" 
    | @category="storage.type" string : "string" 
    | @category="storage.type" nil    : "nil-type"
    ;

syntax Expression 
    = @category="variable.other" id: Id name
    | @category="string.quoted.double" strcon: String string
    | @category="constant.numeric" natcon: Natural natcon
    | bracket "(" Expression e ")"
    > left concat: Expression lhs "||" Expression rhs
    > left ( add: Expression lhs "+" Expression rhs
           | min: Expression lhs "-" Expression rhs)
    ;
           
lexical Id = ([a-z][a-z0-9]*) !>> [a-z0-9] \ Keyword;
lexical Natural = [0-9]+ !>> [0-9];
lexical String = "\"" Char* "\"";

lexical Char
    = ![\\\"]
    | "\\" [\\\"];

keyword Keyword
    = "begin"
    | "end"
    | "declare"
    | "if"
    | "then"
    | "else"
    | "fi"
    | "while"
    | "do"
    | "od"
    ;

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];

lexical WhitespaceAndComment 
    = [\ \t\n\r]
    | @category="comment.block" "%" ![%]+ "%"
    | @category="comment.line" "%%" ![\n]* $
    ;

Grammar rsc = preprocess(grammar(#Program));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit("-"),lit(","),lit(")"),lit("("),lit("+"),lit("||"),lit(":="),lit("\\")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(label("natural",sort("Type")),[lit("natural")],{\tag("category"("storage.type"))}), false, false, <just(lit(":")),just(lit(";"))>, <nothing(),nothing()>),
    unit(rsc, prod(label("nil",sort("Type")),[lit("nil-type")],{\tag("category"("storage.type"))}), false, false, <just(lit(":")),just(lit(";"))>, <nothing(),nothing()>),
    unit(rsc, prod(label("string",sort("Type")),[lit("string")],{\tag("category"("storage.type"))}), false, false, <just(lit(":")),just(lit(";"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%%"),conditional(\iter-star(\char-class([range(1,9),range(11,1114111)])),{\end-of-line()})],{\tag("category"("comment.line"))}), false, false, <nothing(),nothing()>, <just(lit("%%")),nothing()>),
    unit(rsc, prod(lex("WhitespaceAndComment"),[lit("%"),iter(\char-class([range(1,36),range(38,1114111)])),lit("%")],{\tag("category"("comment.block"))}), false, true, <nothing(),nothing()>, <just(lit("%")),just(lit("%"))>),
    unit(rsc, prod(label("strcon",sort("Expression")),[label("string",lex("String"))],{\tag("category"("string.quoted.double"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(label("id",sort("Expression")),[label("name",lex("Id"))],{\tag("category"("variable.other"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(label("natcon",sort("Expression")),[label("natcon",lex("Natural"))],{\tag("category"("constant.numeric"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("do"),lit("declare"),lit("fi"),lit("else"),lit("end"),lit("od"),lit("nil-type"),lit("begin"),lit("natural"),lit("then"),lit("if"),lit("while"),lit("string")})],{\tag("category"("keyword.control"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "PicoWithCategories");
test bool transformTest() = doTransformTest(units, <10, 3, 0>, name = "PicoWithCategories");