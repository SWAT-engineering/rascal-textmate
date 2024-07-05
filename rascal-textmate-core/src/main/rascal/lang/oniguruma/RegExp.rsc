@synopsis{
    Types and functions to represent regular expressions in the .NET version of
    the Oniguruma format for regular expressions, as required by the VS Code
    TextMate-based tokenizer (main difference: hexadecimal characters are
    represented as `\uHHHH` instead of as `\x{HHHH}`)
}

@description{
    Further reading:
      - https://macromates.com/manual/en/regular_expressions
      - https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions
}

module lang::oniguruma::RegExp

import Grammar;
import List;
import ParseTree;
import Set;
import String;

@synopsis{
    Representation of a regular expression, including the categories assigned to
    each group (from left to right)
}

data RegExp = regExp(str string, list[str] categories);

@synopsis{
    Adds prefix `s` to a regular expression (categories unaffected)
}

RegExp prefix(str s, regExp(string, categories))
    = regExp("<s><string>", categories);

@synopsis{
    Adds suffix `s` to a regular expression (categories unaffected)
}

RegExp suffix(str s, regExp(string, categories))
    = regExp("<string><s>", categories);

@synopsis{
    Add infix `s` between regular expressions `regExps` (categories unaffected)
}

RegExp infix(str s, list[RegExp] regExps) {
    re = regExp(
        intercalate(s, [string | regExp(string, _) <- regExps]), 
        [*categories | regExp(_, categories) <- regExps]);
        
    return size(regExps) > 1 ? group(re) : re;
}

@synopsis{
    Wraps a regular expression in a group, optionally captured when `category`
    is set.
}

RegExp group(RegExp re, str category = "")
    = category?
    ? re[string = "(<ungroup(re.string)>)"][categories = [category] + re.categories]
    : re[string = "(?:<re.string>)"];

private str ungroup(str old)
    = /^\(\?:<new:.*>\)$/ := old ? new : old;