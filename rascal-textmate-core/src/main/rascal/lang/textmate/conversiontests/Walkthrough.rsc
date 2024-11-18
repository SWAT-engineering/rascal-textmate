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
@description{
This module consists of a walkthrough to explain the main ideas behind the
conversion algorithm, from Rascal grammars to TextMate grammars. The walkthrough
is not intended to be comprehensive, meaning that not all corner cases are
discussed and explained. The aim of the walkthrough is to convey just the
general approach.

The walkthrough consists of the following sections:
  - Preface
  - Basic conversion: single-line, non-recursive
  - Advanced conversion: multi-line, non-recursive
  - Advanced conversion: single/multi-line, recursive
  - Advanced conversion: context detection

Throughout, a simple data language is used to demonstrate the main ideas. It is
defined incrementally, by need.

Working familiarity with TextMate grammar is assumed. To summarize:

  - Syntax:
      - Each TextMate grammar consists of a list of TextMate rules (ordered).
      - Each TextMate rule is either a *match pattern* (consisting of one
        regular expression) or a *begin/end pattern* (consisting of two
        regular expressions and a list of nested TextMate rules).

  - Semantics: A TextMate tokenizer reads a document (line by line, top to
    bottom, left to right), while iteratively trying to apply TextMate rules by
    matching text against the regular expressions.

Further reading:
  - https://macromates.com/manual/en/language_grammars
  - https://www.apeth.com/nonblog/stories/textmatebundle.html
  - https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide
}

module lang::textmate::conversiontests::Walkthrough

import Grammar;
import IO;
import ParseTree;
import util::Maybe;

import lang::textmate::Conversion;
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionTests;
import lang::textmate::ConversionUnit;
import lang::textmate::NameGeneration;
import lang::textmate::Grammar;

import lang::rascal::grammar::analyze::Delimiters;

// ----------
// ## Preface
//
// The following lexicals will be used as terminals (in addition to literals):

lexical Alnum = [0-9 A-Z a-z] ;
lexical Digit = [0-9] ;
lexical Blank = [\ \t] ;
lexical Space = [\ \t\n] ;
lexical Print = [0-9 A-Z a-z \ \t\n];

// -----------------------------------------------
// ## Basic conversion: single-line, non-recursive
//
// ### User-defined productions
//
// Basically, the conversion algorithm analyzes the Rascal grammar to find each
// user-defined Rascal production that is *suitable for conversion* to a
// TextMate rule. Roughly, a production is said to have that property when:
//   - it has a category;
//   - it cannot produce the empty word.
//
// For instance:

lexical Identifier = Alnum+ !>> [0-9 A-Z a-z] ;
lexical Chars      = @category="string" Print* ;
lexical Number     = @category="constant.numeric" Digit+ !>> [0-9] ;

// The Rascal productions of `Identifier` (does not have a category) and `Chars`
// (can produce the empty word) are not suitable-for-conversion. In contrast,
// the Rascal production of `Number` is suitable-for-conversion. The following
// TextMate rule is generated:
//
// ```
// {
//   "name":     "/inner/single/number",
//   "match":    "([0-9]+?(?![0-9]))",
//   "captures": { "1": { "name": "constant.numeric" } }
// }
// ```
//
// Note: Property `name` could be anything, but to simplify debugging, the
// conversion algorithm uses a description of the Rascal production.
//
// Note: The `match` property is a regular expression written in *Oniguruma*
// format (as required by the TextMate grammar specification).

// ### Keywords
//
// Sometimes, literals that qualify as *keywords* do not have a corresponding
// category. For instance:

syntax BooleanExpr
    = "true"
    | "false"
    | "if" BooleanExpr "then" BooleanExpr "else" BooleanExpr
    | "(" BooleanExpr ")"
    ;

// Despite not having a category, though, these literals should be highlighted.
//
// Thus, the conversion algorithm:
//   - analyzes the Rascal grammar to find each literal that qualifies as a
//     keyword (according to function `isKeyword` in module
//     `lang::rascal::grammar:analyze::Delimiters`);
//   - collects these literals in a synthetic Rascal production of the form
//     `lit1 | lit2 | ...` (suitable-for-conversion by construction);
//   - converts that production to a TextMate rule.
//
// For instance, the literals that qualify as keywords in the Rascal productions
// of `BooleanExpr` are "true", "false", "if", "then", and "else". The following
// TextMate rule is generated:
//
// ```
// {
//   "name":     "/inner/single/$keywords",
//   "match":    "((?:\\btrue\\b)|(?:\\bfalse\\b)|(?:\\belse\\b)|(?:\\bthen\\b)|(?:\\bif\\b))",
//   "captures": { "1": { "name": "keyword.control" } }
// }
// ```
//
// ### Delimiters
//
// Sometimes, literals that qualify as *delimiters* might confuse the TextMate
// tokenizer. For instance:

lexical LineComment = @category="comment" "//" (Alnum | Space)* $ ;
lexical Location    = "|" Alnum+ "://" Alnum+ "|";

// The Rascal production of `Comment` is suitable-for-conversion, while the
// Rascal production of `Location` (does not have a category) is not. However,
// if only the former were to be converted to a TextMate rule, then substring
// "//Desktop" of input string "|home://Desktop|" would be mistakenly tokenized
// as a comment.
//
// Thus, the conversion algorithm:
//   - analyzes the Rascal grammar to find each literal that qualifies as a
//     delimiter (according to function `isDelimiter` in module
//     `lang::rascal::grammar:analyze::Delimiters`);
//   - collects these literals in a synthetic Rascal production of the form
//     `lit1 | lit2 | ...` (suitable-for-conversion by construction);
//   - converts that production to a TextMate rule.
//
// For instance, the literals that qualify as delimiters in the Rascal
// productions of `Comment` and `Location` are "//", "://", and "|". The
// following TextMate rule is generated:
//
// ```
// {
//   "name":     "/inner/single/$delimiters",
//   "match":    "(?:\\/\\/)|(?:\\|)|(?:\\:\\/\\/)",
//   "captures": {}
// }
// ```
//
// Note: The intent of this TextMate rule is *not* to assign a scope. This is
// why the `captures` property is empty. The only purpose of this TextMate rule
// is to force the TextMate tokenizer to consume highlighting-neutral delimiters
// before they are accidentally tokenized and mistakenly highlighted.
//
// Note: To ensure that each delimiter is matched by at most one TextMate rule,
// each delimiter literal needs to fulfil a number of additional requirements to
// be included in the synthetic Rascal production (e.g., it must not be the
// prefix of any other delimiter literal).

// -------------------------------------------------
// ## Advanced conversion: multi-line, non-recursive
//
// ### Approach
//
// To convert user-defined Rascal productions of multi-line strings, more
// advanced machinery than TextMate rules with match patterns of single-line
// strings is needed (i.e., newlines cannot be matched by individual regular
// expressions in a TextMate grammar). That is, TextMate rules with begin/end
// patterns need to be used. The approach is roughly as follows:
//
//   - First, the conversion algorithm analyzes the Rascal grammar to find each
//     user-defined Rascal production that is suitable-for-conversion.
//
//   - Next, the conversion algorithm optimistically converts each of those
//     productions -- *including* those of multi-line strings -- to a TextMate
//     rule with a match pattern of single-line strings. The rationale is that
//     single-line strings are a significant special case of multi-line strings,
//     so this TextMate rule can already be quite effective.
//
//   - Next, the conversion algorithm checks for each of those productions of
//     multi-line strings if it is *delimited*, *semi-delimited*, or
//     *non-delimited*:
//
//       - If it begins and ends with a delimiter, then it is *delimited*. In
//         this case, the production can be converted to a TextMate rule with a
//         begin/end pattern in a relatively simple way.
//
//       - If it begins with a delimiter, but it does not end with a delimiter,
//         then it is *semi-delimited*. In this case, the production can be
//         converted to a TextMate rule with a begin/end pattern in a relatively
//         complex way.
//
//       - If it does not begin with a delimiter, then it is *non-delimited*. In
//         this case, the production cannot be converted to a TextMate rule with
//         a begin/end pattern.
//
// ### Delimited conversion, when the begin-delimiter is unique
//
// For instance:

lexical BlockComment = @category="comment" "/*" Print* "*/" ;

// The Rascal production of `BlockComment` is suitable-for-conversion,
// multi-line (because `Print` can produce a newline), and delimited (by "/*"
// and "*/"). Moreover, the begin-delimiter is unique: there is no other Rascal
// production in the Rascal grammar that begins with "/*". The following
// TextMate rule is generated:
//
// ```
// {
//   "name":          "/inner/multi/blockcomment",
//   "begin":         "(\\/\\*)",
//   "end":           "(\\*\\/)",
//   "beginCaptures": { "1": { "name": "comment" } },
//   "endCaptures":   { "1": { "name": "comment" } },
//   "patterns": [
//     {
//       "match":     "([\\t-\\n\\x{20}0-9A-Za-z])",
//       "captures":  { "1": { "name": "comment" } }
//     },
//     {
//       "match":     "([\\x{01}-\\x{10FFFF}])",
//       "captures":  { "1": { "name": "comment" } }
//     }
//   ]
// }
// ```
//
// Note: The purpose of the nested match patterns is to force the TextMate
// tokenizer to explicitly consume all input between the begin/end delimiters.
// The first nested match pattern is derived from the Rascal production of
// `Print`. The second nested match pattern is a default fallback.
//
// ### Delimited conversion, when the begin-delimiter is *not* unique
//
// For instance:

lexical String
    = StringLeftRight                                           // Without interpolation
    | StringLeft (Identifier StringMid)* Identifier StringRight // With interpolation
    ;

lexical StringLeftRight = @category="string" "\"" Print* "\"" ;
lexical StringLeft      = @category="string" "\"" Print* "\<" ;
lexical StringMid       = @category="string" "\>" Print* "\<" ;
lexical StringRight     = @category="string" "\>" Print* "\"" ;

// The Rascal production of `StringMid` is suitable-for-conversion, multi-line
// (because `Print` can produce a newline), and delimited (by ">" and "<").
// However, the begin-delimiter is not unique: there is another Rascal
// production in the Rascal grammar that begins with ">", namely the one of
// `StringRight`. The following *single* TextMate rule is generated that covers
// *both* Rascal productions:
//
// ```
// {
//   "name":          "/inner/multi/stringmid,stringright",
//   "begin":         "(\\>)",
//   "end":           "((?:\\\")|(?:\\<))",
//   "beginCaptures": { "1": { "name": "string" } },
//   "endCaptures":   { "1": { "name": "string" } },
//   "patterns": [
//     {
//       "match":     "([\\t-\\n\\x{20}0-9A-Za-z])",
//       "captures":  { "1": { "name": "string" } }
//     },
//     {
//       "match":     "([\\x{01}-\\x{10FFFF}])",
//       "captures":  { "1": { "name": "string" } }
//     }
//   ]
// }
// ```
//
// Note: Similarly, the Rascal productions of `StringLeftRight` and `StringLeft`
// are suitable-for-conversion, multi-line, and delimited. Moreover, their begin
// delimiter is "\"", while there is no other Rascal production in the Rascal
// grammar that begins with "\"". However, "\"" *does* occur as a non-begin
// delimiter elsewhere in the Rascal grammar: it is the end-delimiter of the
// Rascal production of `StringLeftRight`. Consequently, "\"" does *not*
// unmistakenly indicate the beginning of `StringLeftRight` or `StringLeft`. To
// avoid multi-line tokenization mistakes, the Rascal productions of
// `StringLeftRight` and `StringLeft` are not converted to a TextMate rule.
//
// ### Semi-delimited conversion
//
// For instance:

syntax Tag
    = @category="comment" "@" Alnum+ "=" Alnum+
    | @category="comment" "@" Alnum+ "{" Print* "}"
    ;

layout Layout = Space* !>> [\ \t\n];

// The Rascal productions of `Tag` are suitable-for-conversion and multi-line
// (because `Layout` can produce newlines). However, only the second production
// is delimited. This requires special care. The following TextMate rule, with
// several nested patterns, is generated:
//
// ```
// {
//   "name":                "/inner/multi/tag.2,tag.1",
//   "begin":               "((?:\\@)(?:[\\t-\\n\\x{20}]*?(?![\\t-\\n\\x{20}]))(?:[0-9A-Za-z](?:(?:[\\t-\\n\\x{20}]*?(?![\\t-\\n\\x{20}]))[0-9A-Za-z])*?)(?:[\\t-\\n\\x{20}]*?(?![\\t-\\n\\x{20}])))",
//   "end":                 "(?=.)",
//   "beginCaptures":       { "1": { "name": "comment" } },
//   "endCaptures":         {},
//   "applyEndPatternLast": true,
//   "patterns": [
//     {
//       "begin":         "(\\{)",
//       "end":           "(\\})",
//       "beginCaptures": { "1": { "name": "comment" } },
//       "endCaptures":   { "1": { "name": "comment" } },
//       "patterns": [
//         {
//           "match": "([\\t-\\n\\x{20}])",
//           "captures": { "1": { "name": "comment" } }
//         },
//         {
//           "match": "([\\x{01}-\\x{10FFFF}])",
//           "captures": { "1": { "name": "comment" } }
//         }
//       ],
//     },
//     {
//       "match": "(\\=)",
//       "captures": { "1": { "name": "comment" } }
//     }
//   ]
// }
// ```
//
// Note: The begin pattern matches the common *prefix* of the two Rascal
// productions. The two nested patterns correspond to the different *suffixes*.

// ----------------------------------------------------
// ## Advanced conversion: single/multi-line, recursive
//
// Semi-delimited conversion (explained above) has limited support for
// user-defined Rascal productions that are recursive. Other than that,
// recursion is not yet supported.

// -----------------------------------------
// ## Advanced conversion: context detection
//
// Sometimes, highlighting depends on the context in which the tokenization
// input occurs. For instance:

lexical RegExp = "/" RegExpBody "/";

lexical RegExpBody
    = @category="string" alnum: Alnum+ !>> [0-9 A-Z a-z]
    | RegExpBody "?"
    | RegExpBody "+"
    | RegExpBody "|" RegExpBody
    ;

// Rascal production `alnum` of `RegExpBody` is suitable-for-conversion.
// However, except for the `@category` tag, it has exactly the same definition
// as the production of `Identifier` (above). If the conversion algorithm were
// to naively convert `alnum` to a TextMate rule, identifiers would be
// mistakenly highlighted as strings.
//
// Thus, the conversion algorithm first heuristically checks for each Rascal
// production that is suitable-for-conversion if it is *enclosed by delimiters*.
// If so, it is converted to an *outer* TextMate rule with a begin/end pattern
// to match the enclosing delimiters (i.e., context detection) and include
// patterns to toggle *inner* TextMate rules. That is, the inner TextMate rules
// are used for tokenization only between matches of the enclosing delimiters
// (i.e., in the right context).
//
// For instance, production `alnum` is enclosed by an opening `/` and a closing
// `/`. The following outer TextMate rule is generated:
//
// ```
// {
//   "name":          "/outer//",
//   "begin":         "(?:\\/)",
//   "end":           "(?:\\/)",
//   "beginCaptures": {},
//   "endCaptures":   {},
//   "patterns": [
//     { "include": "#/inner/single/$delimiters" },
//     { "include": "#/inner/single/regexpbody.alnum" },
//     { "include": "#/inner/single/$keywords" }
//   ]
// }
// ```
//
// Note: If N Rascal productions are enclosed by the same delimiters, then the
// conversion algorithm converts them into one outer TextMate rule and N inner
// TextMate rules.

// ## Tests
//
// The following code tests the conversion algorithm on input of the grammar
// defined above.

start syntax Start
    = Identifier
    | Chars
    | Number
    | BooleanExpr
    | LineComment
    | Location
    | BlockComment
    | String
    | Tag
    | RegExp ;

Grammar rsc = preprocess(grammar(#Start));

list[ConversionUnit] units = [
    unit(rsc, prod(lex(DELIMITERS_PRODUCTION_NAME),[alt({lit(")"),lit("("),lit("+"),lit("="),lit("|"),lit("?"),lit("{"),lit("://")})],{}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(sort("Tag"),[lit("@"),layouts("Layout"),\iter-seps(lex("Alnum"),[layouts("Layout")]),layouts("Layout"),lit("="),layouts("Layout"),\iter-seps(lex("Alnum"),[layouts("Layout")])],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("@")),nothing()>),
    unit(rsc, prod(sort("Tag"),[lit("@"),layouts("Layout"),\iter-seps(lex("Alnum"),[layouts("Layout")]),layouts("Layout"),lit("{"),layouts("Layout"),\iter-star-seps(lex("Print"),[layouts("Layout")]),layouts("Layout"),lit("}")],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("@")),just(lit("}"))>),
    unit(rsc, prod(lex("StringMid"),[lit("\>"),\iter-star(lex("Print")),lit("\<")],{\tag("category"("string"))}), false, true, <just(lit("\<")),just(lit("\>"))>, <just(lit("\>")),just(lit("\<"))>),
    unit(rsc, prod(lex("StringRight"),[lit("\>"),\iter-star(lex("Print")),lit("\"")],{\tag("category"("string"))}), false, true, <just(lit("\<")),nothing()>, <just(lit("\>")),just(lit("\""))>),
    unit(rsc, prod(lex("LineComment"),[lit("//"),conditional(\iter-star(alt({lex("Alnum"),lex("Space")})),{\end-of-line()})],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("//")),nothing()>),
    unit(rsc, prod(lex("BlockComment"),[lit("/*"),\iter-star(lex("Print")),lit("*/")],{\tag("category"("comment"))}), false, true, <nothing(),nothing()>, <just(lit("/*")),just(lit("*/"))>),
    unit(rsc, prod(label("alnum",lex("RegExpBody")),[conditional(iter(lex("Alnum")),{\not-follow(\char-class([range(48,57),range(65,90),range(97,122)]))})],{\tag("category"("string"))}), false, false, <just(lit("/")),just(lit("/"))>, <nothing(),nothing()>),
    unit(rsc, prod(lex("StringLeft"),[lit("\""),\iter-star(lex("Print")),lit("\<")],{\tag("category"("string"))}), false, true, <nothing(),just(lit("\>"))>, <just(lit("\"")),just(lit("\<"))>),
    unit(rsc, prod(lex("StringLeftRight"),[lit("\""),\iter-star(lex("Print")),lit("\"")],{\tag("category"("string"))}), false, true, <nothing(),nothing()>, <just(lit("\"")),just(lit("\""))>),
    unit(rsc, prod(lex("Number"),[conditional(iter(lex("Digit")),{\not-follow(\char-class([range(48,57)]))})],{\tag("category"("constant.numeric"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>),
    unit(rsc, prod(lex(KEYWORDS_PRODUCTION_NAME),[alt({lit("true"),lit("false"),lit("else"),lit("then"),lit("if")})],{\tag("category"("keyword.control"))}), false, false, <nothing(),nothing()>, <nothing(),nothing()>)
];

test bool analyzeTest()   = doAnalyzeTest(rsc, units, name = "Walkthrough");
test bool transformTest() = doTransformTest(units, <12, 6, 0>, name = "Walkthrough");

bool convertAndPrint() {
    println(toJSON(toTmGrammar(grammar(#Start), "Walkthrough", nameGeneration = short())));
    return true;
}
