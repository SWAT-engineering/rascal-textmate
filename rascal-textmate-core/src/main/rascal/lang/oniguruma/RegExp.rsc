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
@synopsis{
    Types and functions to represent regular expressions in the
    the Oniguruma format (required by the TextMate tokenizer)
}

@description{
    Further reading:
     1. https://macromates.com/manual/en/regular_expressions
     2. https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions
    
    Note: A significant difference with [1] is that hexadecimal characters need
    to be represented as `\x{0HHHHHHH}` instead of as `\x{7HHHHHHH}`.
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