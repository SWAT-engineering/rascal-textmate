// # Walkthrough
//
// This module consists of a walkthrough to explain the main ideas behind the
// conversion algorithm, from Rascal grammars to TextMate grammars.
//
// The walkthrough is split into five parts. The initial part explains basic
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
// Working familiarity with TextMate grammar is assumed. To summarize:
//
//   - Syntax:
//       - Each TextMate grammar consists of a list of TextMate rules (ordered).
//       - Each TextMate rule is either a *match pattern* (consisting of one
//         regular expression) or a *begin/end pattern* (consisting of two
//         regular expressions and a list of nested TextMate rules).
//
//   - Semantics: A tokenization engine reads a document (line by line, top to
//     bottom, left to right), while iteratively trying to apply TextMate rules
//     by matching text against the regular expressions.
//
// Further reading:
//   - https://macromates.com/manual/en/language_grammars
//   - https://www.apeth.com/nonblog/stories/textmatebundle.html
//   - https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide

module lang::textmate::conversiontests::Walkthrough

import Grammar;
import ParseTree;
import util::Maybe;

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
    | Boolean
    ;

syntax Map = "{" {(Key ":" Value) ","}* "}";

lexical Key    = Alnum+ !>> [a-z A-Z 0-9];
lexical Number = @category="constant.numeric" Digit+ !>> [0-9];
lexical String = @category="string.quoted.double" "\"" Alnum* "\"";

// Basically, the conversion algorithm converts each Rascal non-terminal that is
// *suitable for conversion* to a TextMate rule. For instance, `Number` is
// converted to the following match pattern (in JSON):
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
// Note: The regular expression (`match` property) is written in Oniguruma
// format (following the TextMate grammar specification), using code units
// instead of alphanumericals.
//
// Note: The name (`name` property) could be anything, but to simplify
// debugging, the conversion algorithm uses (part of) the internal
// representation of the Rascal non-terminal as the name.
//
// In general, a Rascal non-terminal is "suitable for conversion" when it
// satisfies each of the following conditions:
//
//  1. It is non-recursive. (Recursion is prohibitively hard to faithfully
//     convert; tail-recursion could be workable, but currently out of scope.)
//
//  2. It does not match newlines. (TextMate rules that involve matching against
//     newlines are problematic because the tokenization engine operates line by
//     line.)
//
//  3. It does not match the empty word. (TextMate rules that involve matching
//     against the empty word are problematic because they match at every
//     position.)
//
//  4. It has a `@category` tag.
//
// For instance, `Number` and `String` are suitable for conversion, but `Value`
// (violation of conditions 1 and 4), `Map` (violation of condition 1), and
// `Key` (violation of condition 4) are not suitable.



// ## Extension 1: Conversion of productions instead of non-terminals
//
// The first extension (layout) of the grammar looks like this:

lexical Comment
    = @category="comment.line.double-slash" line:  "//" (Alnum | Blank)* $
    | @category="comment.block"             block: "/*" (Alnum | Space)* "*/"
    ;

layout Layout = (Comment | Space)* !>> "//" !>> [\ \t\n];

// `Comment` is *not* suitable for conversion, as it violates condition 2: the
// corresponding TextMate rule would involve matching against newlines. However,
// the matching against newlines is needed only for production `block`; not for
// production `line`. Thus, conversion at the granularity of Rascal
// non-terminals is actually too coarse.
// 
// To solve this issue, the conversion algorithm works at the granularity of
// individual productions (specifically, `prod` constructors). For instance,
// production `line` of `Comment` is individually converted to the following
// match pattern, independently of production `block` (which is ignored):
//
// ```
// {
//   "match": "((?:\\u002F\\u002F)(?:(?:(?:[\\u0009-\\u0009]|[\\u0020-\\u0020])|(?:[\\u0030-\\u0039]|[\\u0041-\\u005A]|[\\u0061-\\u007A]))*?(?:$)))",
//   "name": "prod(label(\"line\",lex(\"Comment\")),[lit(\"//\"),conditional(\\iter-star(alt({lex(\"Blank\"),lex(\"Alnum\")})),{\\end-of-line()})],{tag(\"category\"(\"comment.line.double-slash\"))})",
//   "captures": {
//     "1": {
//       "name": "comment.line.double-slash"
//     }
//   }
// }
// ```



// ## Extension 2: Delimiter-sensitive conversion
//
// The second extension (regular expressions; illustrative fragment) looks as
// follows:

syntax RegExp = "/" RegExpBody "/";

lexical RegExpBody
    = @category="markup.italic" alnum: Alnum+ !>> [a-z A-Z 0-9]
    | RegExpBody "?"
    | RegExpBody "+"
    | RegExpBody "|" RegExpBody
    ;

// Production `alnum` of `RegExpBody` is suitable for conversion. However,
// except for the `@category` tag, it has exactly the same definition as the
// production of `Key` (above). Thus, if the conversion algorithm were to
// naively convert `alnum` to a TextMate rule, keys in maps would be tokenized
// accidentally as regular expressions (and mistakenly typeset in italics).
//
// To solve this issue, the conversion algorithm first heuristically checks for
// each suitable-for-conversion production if it is *enclosed by delimiters*. If
// so, instead of converting the production to a top-level match pattern, it is
// converted to a top-level begin/end pattern (for the enclosing delimiters)
// with a nested match pattern (for the production itself). As a result, the
// nested match pattern will be used for tokenization only between matches of
// the enclosing delimiters. For instance, production `alnum` is enclosed by an
// opening `/` and a closing `/`, so it is converted to the following top-level
// begin/end pattern with a nested match pattern:
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
// Note: If N suitable-for-conversion productions are enclosed by the same
// delimiters, then the conversion algorithm converts them into one top-level
// begin/end pattern with N nested match patterns (one for each production).



// ## Extension 3: Delimiter conversion
//
// The third extension (locations; illustrative fragment) looks as follows:

syntax  Location = "|" Segment "://" {Segment "/"}+ "|";
lexical Segment  = Alnum+ !>> [a-z A-Z 0-9];

// The productions of `Location` and `Segment` are *not* suitable for
// conversion, as they violate condition 4. However, accidentally, the TextMate
// rule for production `line` of `Comment` (above) will actually be applicable
// to suffixes of locations (e.g., it matches `//bar/baz` in `|foo://bar/baz|`).
// Thus, suffixes of locations will mistakenly be highlighted as comments.
//
// To solve this issue, the conversion algorithm creates a synthetic production
// of the form `lit1 | lit2 | ...`, where each `lit<i>` is a literal that occurs
// in the Rascal grammar, and:
//   - it does not match `/^\w+$/` (i.e., it is a *delimiter literal*; e.g.,
//     `(`, `://`, and `,` are delimiter literals);
//   - it is not a prefix of any other delimiter literal;
//   - it does not occur at the start of a suitable-for-conversion production;
//   - it does not enclose a suitable-for-conversion production.
// 
// The synthetic production is converted to a TextMate rule (match pattern). The
// previous requirements for each `lit<i>` are intended to ensure that only a
// single TextMate rule is applicable to each delimiter. For instance, the
// synthetic production in the example grammar is converted to the following
// match pattern:
//
// ```
// {
//   "match": "(?:\\u002C)|(?:\\u002B)|(?:\\u002A\\u002F)|(?:\\u007D)|(?:\\u007C)|(?:\\u003F)|(?:\\u003A\\u002F\\u002F)|(?:\\u002F\\u002A)|(?:\\u007B)",
//   "name": "prod(lex(\"delimiters\"),[alt({lit(\",\"),lit(\"+\"),lit(\"*/\"),lit(\"}\"),lit(\"|\"),lit(\"?\"),lit(\"://\"),lit(\"/*\"),lit(\"{\")})],{})"
// }
// ```
//
// Note: The intent of this match pattern is *not* to assign a category. The
// only purpose is to force the tokenization engine to consume
// "highlighting-insignificant" delimiters before they are accidentally
// tokenized and mistakenly highlighted.



// ## Extension 4: Keyword coversion
//
// The fourth extension (booleans) of the grammar looks as follows:

lexical Boolean
    = "true"
    | "false"
    ;

// The productions of `Boolean` are *not* suitable for conversion, as they
// violate condition 4. However, by default, literals like these should be
// highlighted as keywords.
//
// To solve this issue, the conversion algorithm creates a synthetic production
// of the form `lit1 | lit2 | ...`, where each `lit<i>` is a literal that occurs
// in the input grammar, and `lit<i>` matches `/^\w+$/` (i.e., it is a *keyword
// literal*; e.g., `true` and `false`). The synthetic production is converted to
// a TextMate rule (match pattern). For instance, the synthetic production in
// the example grammar is converted to the following match pattern:
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
    unit(rsc, prod(label("line",lex("Comment")),[lit("//"),conditional(\iter-star(alt({lex("Blank"),lex("Alnum")})),{\end-of-line()})],{\tag("category"("comment.line.double-slash"))}), <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(label("block",lex("Comment")),[lit("/*"),\iter-star(alt({lex("Alnum"),lex("Space")})),lit("*/")],{\tag("category"("comment.block"))}), <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>),
    unit(rsc, prod(label("alnum",lex("RegExpBody")),[conditional(iter(lex("Alnum")),{\not-follow(\char-class([range(48,57),range(65,90),range(97,122)]))})],{\tag("category"("markup.italic"))}), <just(lit("/")),just(lit("/"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("String"),[lit("\""),\iter-star(lex("Alnum")),lit("\"")],{\tag("category"("string.quoted.double"))}), <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(lex("Number"),[conditional(iter(lex("Digit")),{\not-follow(\char-class([range(48,57)]))})],{\tag("category"("constant.numeric"))}), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit(","),lit("/"),lit("+"),lit("*/"),lit("//"),lit("\""),lit("}"),lit("|"),lit("?"),lit("/*"),lit("{"),lit("://"),lit(":")})],{}), <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("true"),lit("false")})],{\tag("category"("keyword.control"))}), <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units);
test bool transformTest() = doTransformTest(units, <6, 1, 0>);