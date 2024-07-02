// # Walkthrough
//
// This module consists of a walkthrough to explain the main ideas behind the
// conversion algorithm (from Rascal to TextMate).
//
// The walkthrough is split into five parts. The initial part demonstrates basic
// conversion. The subsequent four parts present complications and demonstrate
// extensions of the conversion algorithm to address them.
//
// The toy language considered, is a simple data language consisting of:
//   - base: maps, numbers, strings;
//   - extension 1: layout (including comments);
//   - extension 2: regular expressions;
//   - extension 3: locations;
//   - extension 4: booleans.
//
// Working familiarity with TextMate is assumed. To summarize:
//
//   - Syntax:
//       - Each TextMate grammar consists of a list of rules.
//       - Each rule is either *match* (consisting of one regular expression) or
//         *begin/end* (consisting of two regular expressions and a list of
//         nested rules).
//
//   - Semantics: A tokenization engine reads a document (line by line, top to
//     bottom, left to right), iteratively trying to match text by applying the
//     rules in the list (front to back).
//
// Further reading:
//   - https://macromates.com/manual/en/language_grammars
//   - https://www.apeth.com/nonblog/stories/textmatebundle.html
//   - https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide

module lang::textmate::conversiontests::Walkthrough

import Grammar;
import ParseTree;
import lang::textmate::Conversion;
import lang::textmate::ConversionTests;

import lang::rascal::grammar::analyze::Delimiters;

// ## Basics
//
// The base fragment of the grammar looks as follows:

lexical Alnum = [a-z A-Z 0-9];
lexical Digit = [0-9];
lexical Blank = [\ \t];
lexical Space = [\ \t\n];

start syntax Value
    = Map
    | Number
    | String
    | RegExp
    | Location
    | Boolean;

syntax Map = "{" {(Key ":" Value) ","}* "}";

lexical Key    = Alnum+ !>> [a-z A-Z 0-9];
lexical Number = @category="constant.numeric" Digit+ !>> [0-9];
lexical String = @category="string.quoted.double" "\"" Alnum* "\"";

// Basically, the conversion algorithm converts each non-terminal in the input
// grammar (Rascal) that is *suitable for conversion* to a rule in the output
// grammar (TextMate). For instance, non-terminal `Number` is converted to the
// following match rule (in JSON):
//
// ```
// {
//   "match": "([\\u0030-\\u0039]+?(?![\\u0030-\\u0039]))",
//   "name": "prod(lex(\"Number\"),[conditional(iter(lex(\"Digit\")),{\\not-follow(\\char-class([range(48,57)]))})],{tag(\"category\"(\"constant.numeric\"))})", 
//   "captures": {
//     "1": {
//       "name": "constant.numeric"
//     }
//   }
// }
// ```
//
// Here:
//
//   - `match` is the regular expression -- in Oniguruma format, using code
//     units instead of alphanumericals -- that corresponds with the
//     non-terminal;
//   - `name` is the name of the match rule (i.e., by convention, the conversion
//     algorithm uses part of the internal Rascal representation of the
//     non-terminal as the name);
//   - `captures.1.name` is the category.
//
// In general, a non-terminal is "suitable for conversion" when it satisfies
// each of the following conditions:
//
//  1. It is non-recursive. (Recursive non-terminals are prohibitively hard to
//     faithfully convert; tail-recursive non-terminals could be workable, but
//     they are not yet supported.)
//
//  2. It does not match newlines. (TextMate grammars with rules that can match
//     newlines are dysfunctional.)
//
//  3. It does not match the empty word. (TextMate grammars with rules that can
//     match the empty word are dysfunctional.)
//
//  4. It has a `@category` tag on at least one of it productions.
//
// For instance, non-terminals `Number` and `String` are suitable for
// conversion, but non-terminals `Value` (violation of conditions 1 and 4),
// `Map` (violation of condition 1), and `Key` (violation of condition 4) are
// not suitable.



// ## Extension 1: Conversion of productions instead of non-terminals
//
// The first extension (layout) of the grammar looks like this:

lexical Comment
    = @category="comment.line.double-slash" line:  "//" (Alnum | Blank)* $
    | @category="comment.block"             block: "/*" (Alnum | Space)* "*/";

layout Layout = (Comment | Space)* !>> "//" !>> [\ \t\n];

// Non-terminal `Comment` is *not* suitable for conversion, as it violates
// condition 2: production `block` potentially matches newlines. However,
// production `line` is actually totally fine and can easily be converted to a
// match rule in TextMate. Thus, converting input grammars in Rascal at the
// granularity of non-terminals is too coarse.
// 
// To solve this issue, the conversion algorithm operates at the granularity of
// individual productions (specifically, `prod` constructors) instead of
// non-terminals. For instance, production `line` of non-terminal `Comment` is
// individually converted to the following match rule:
//
// ```
// {
//   "match": "((?:\\u002F\\u002F)(?:(?:(?:[\\u0009-\\u0009]|[\\u0020-\\u0020])|(?:[\\u0030-\\u0039]|[\\u0041-\\u005A]|[\\u0061-\\u007A]))*?(?:$)))",
//   "name": "prod(label(\"line\",lex(\"Comment\")),[lit(\"//\"),conditional(\\iter-star(alt({lex(\"Blank\"),lex(\"Alnum\")})),{\\end-of-line()})],{tag(\"category\"(\"comment.line.double-slash\"))})",
//   "captures": {
//     "1": {
//     "name": "comment.line.double-slash"
//     }
//   }
// }
// ```



// ## Extension 2: Context-aware conversion
//
// The second extension (regular expressions; illustrative fragment) looks as
// follows:

syntax RegExp = "/" RegExpBody "/";

lexical RegExpBody
    = @category="markup.italic" alnum: Alnum+ !>> [a-z A-Z 0-9]
    | RegExpBody "?"
    | RegExpBody "+"
    | RegExpBody "|" RegExpBody;

// Production `alnum` of non-terminal `RegExpBody` is suitable for conversion.
// However, except for the `@category` tag, it has exactly the same definition
// as the production of non-terminal `Key` (above). Thus, if the conversion
// algorithm were to naively convert `alnum` to a match rule, keys in maps would
// be tokenized accidentally as regular expressions (and mistakenly typeset in
// italics).
//
// To solve this issue, the conversion algorithm first heuristically checks for
// each suitable-for-conversion production if it is *enclosed by delimiters*
// (i.e., it should be applied only in particular contexts). If so, instead of
// converting the production to a top-level match rule, it is converted to a
// top-level begin/end rule (for the enclosing delimiters) with a nested match
// rule (for the production itself). As a result, the nested match rule will be
// used for tokenization only between matches of the enclosing delimiters. For
// instance, production `alnum` is enclosed by an opening `/` and a closing `/`,
// so it is converted into the following top-level begin/end rule and nested
// match rule:
//
// ```
// {
//   "begin": "(?:\\u002F)",
//   "end": "(?:\\u002F)",
//   "patterns": [
//     {
//       "match": "((?:[\\u0030-\\u0039]|[\\u0041-\\u005A]|[\\u0061-\\u007A])+?(?!(?:[\\u0030-\\u0039]|[\\u0041-\\u005A]|[\\u0061-\\u007A])))",
//       "name": "prod(label(\"alnum\",lex(\"RegExpBody\")),[conditional(iter(lex(\"Alnum\")),{\\not-follow(\\char-class([range(48,57),range(65,90),range(97,122)]))})],{tag(\"category\"(\"markup.italic\"))})",
//       "captures": {
//         "1": {
//           "name": "markup.italic"
//         }
//       }
//     }
//   ]
// }
// ```
//
// Note: If N suitable-for-conversion productions are always enclosed by the
// same delimiters, then the conversion algorithm converts them into one
// top-level begin/end rule with N nested match rules (one for each production).



// ## Extension 3: Delimiter conversion
//
// The third extension (locations; illustrative fragment) looks as follows:

syntax  Location = "|" Segment "://" {Segment "/"}+ "|";
lexical Segment  = Alnum+ !>> [a-z A-Z 0-9];

// The productions of these non-terminals are *not* suitable for conversion, as
// they violate condition 4. However, the match rule for production `line` of
// non-terminal `Comment` (above) is applicable to suffixes of locations (due to
// the presence of `://` in the middle). As a result, suffixes of locations will
// mistakenly be highlighted as comments.
//
// To solve this issue, the conversion algorithm creates a synthetic production
// of the form `lit1 | lit2 | ...`, where each `lit<i>` is a literal that occurs
// in the input grammar, and:
//   - `lit<i>` does not match `/^\w+$/` (i.e., it is a *delimiter literal*;
//     e.g., `(`, `://`, and `,` are delimiter literals);
//   - `lit<i>` does not enclose a suitable-for-conversion production;
//   - `lit<i>` is not a prefix of any other delimiter literal that occurs in
//     the input grammar.
// 
// The synthetic production is converted to a match rule in the output grammar.
// For instance:
//
// ```
// {
//   "match": "(?:\\u002C)|(?:\\u002B)|(?:\\u002A\\u002F)|(?:\\u007D)|(?:\\u007C)|(?:\\u003F)|(?:\\u003A\\u002F\\u002F)|(?:\\u002F\\u002A)|(?:\\u007B)",
//   "name": "prod(lex(\"delimiters\"),[alt({lit(\",\"),lit(\"+\"),lit(\"*/\"),lit(\"}\"),lit(\"|\"),lit(\"?\"),lit(\"://\"),lit(\"/*\"),lit(\"{\")})],{})"
// }
// ```
//
// The point of this match rule is *not* to assign a category. The only purpose
// is to force the tokenizer engine to consume highlighting-insignificant
// delimiters before they are accidentally tokenized wrongly.



// ## Extension 4: Keyword coversion
//
// The fourth extension (booleans) of the grammar looks as follows:

lexical Boolean
    = "true"
    | "false";

// The productions of this non-terminal are *not* suitable for conversion, as
// they violate condition 4. However, by default, literals like these should be
// highlighted.
//
// To solve this issue, the conversion algorithm creates a synthetic production
// of the form `lit1 | lit2 | ...`, where each `lit<i>` is a literal that occurs
// in the input grammar, and `lit<i>` matches `/^\w+$/` (i.e., it is a *keyword
// literal*; e.g., `true` and `false`). This synthetic production is converted
// to a rule in the output TextMate grammar. For instance:
//
// ```
// {
//   "match": "((?:\\b\\u0074\\u0072\\u0075\\u0065\\b)|(?:\\b\\u0066\\u0061\\u006C\\u0073\\u0065\\b))",
//   "name": "prod(lex(\"keywords\"),[alt({lit(\"true\"),lit(\"false\")})],{tag(\"category\"(\"keyword.control\"))})",
//   "captures": {
//     "1": {
//       "name": "keyword.control"
//     }
//   }
// }
// ```



// ## Tests
//
// The following code tests the conversion algorithm on input of the grammar
// defined above.

Grammar rsc = grammar(#Value);

list[ConversionUnit] units = [
    unit(rsc, prod(lex("delimiters"),[alt({lit(","),lit("+"),lit("*/"),lit("}"),lit("|"),lit("?"),lit("://"),lit("/*"),lit("{")})],{})),
    unit(rsc, prod(label("alnum",lex("RegExpBody")),[conditional(iter(lex("Alnum")),{\not-follow(\char-class([range(48,57),range(65,90),range(97,122)]))})],{\tag("category"("markup.italic"))})),
    unit(rsc, prod(lex("String"),[lit("\""),\iter-star(lex("Alnum")),lit("\"")],{\tag("category"("string.quoted.double"))})),
    unit(rsc, prod(lex("Number"),[conditional(iter(lex("Digit")),{\not-follow(\char-class([range(48,57)]))})],{\tag("category"("constant.numeric"))})),
    unit(rsc, prod(label("line",lex("Comment")),[lit("//"),conditional(\iter-star(alt({lex("Blank"),lex("Alnum")})),{\end-of-line()})],{\tag("category"("comment.line.double-slash"))}), ignoreDelimiterPairs = true),
    unit(rsc, prod(lex("keywords"),[alt({lit("true"),lit("false")})],{\tag("category"("keyword.control"))}))
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <5, 1, 0>);