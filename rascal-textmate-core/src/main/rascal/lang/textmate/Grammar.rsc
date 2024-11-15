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
    Types and functions to represent TextMate grammars
}

@description{
    ADTs and names are based on VS Code:
    https://github.com/microsoft/vscode-textmate/blob/main/src/rawGrammar.ts
}

module lang::textmate::Grammar

import List;
import Set;
import lang::json::IO;

alias ScopeName = str;
alias RegExpString = str;
alias Repository = map[str, TmRule];
alias Captures = map[str, map[str, ScopeName]];

@synopsis{
    Representation of a TextMate grammar
}

data TmGrammar = grammar(
    // Not supported by VS Code:
    // str foldingStartMarker = "",
    // str foldingStopMarker = "",

    // Supported by VS Code (mandatory):
    Repository repository,
    ScopeName scopeName,
    list[TmRule] patterns,

    // Supported by VS Code (optional):
    map[str, TmRule] injections = (),
    str injectionSelector = "",
    list[str] fileTypes = [],
    str name = "",
    str firstLineMatch = "");

@synopsis{
    Representation of a TextMate rule in a TextMate grammar
}

data TmRule
    = match(
        RegExpString match,
        ScopeName name = "",
        Captures captures = (),
        Repository repository = ())

    | beginEnd(
        RegExpString begin,
        RegExpString end,
        ScopeName name = "",
        ScopeName contentName = "",
        Captures beginCaptures = (),
        Captures endCaptures = (),
        list[TmRule] patterns = [],
        Repository repository = (),
        bool applyEndPatternLast = false)

    | include(
        str include,
        Repository repository = ())
    ;

@synopsis{
    Converts a TextMate grammar to JSON, optionally with custom indentation size
    `indent` (default: `2`), and optionally by also writing the output to
     location `l`
}

str toJSON(TmGrammar g, int indent = 2, loc l = |unknown:///|) {
    if (l?) {
        writeJSON(l, g, indent = indent);
    }
    return asJSON(g, indent = indent);
}

@synopsis{
    Converts list of strings `names` (typically categories) to a map of captures
}

Captures toCaptures(list[str] names)
    = ("<n + 1>": ("name": names[n]) | n <- [0..size(names)], "" != names[n]);