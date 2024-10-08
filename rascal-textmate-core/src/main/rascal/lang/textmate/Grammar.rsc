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