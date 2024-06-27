module lang::textmate::Grammar

import List;
import Set;

// Based on VS Code:
// https://github.com/microsoft/vscode-textmate/blob/main/src/rawGrammar.ts 

alias ScopeName = str;
alias RegExpString = str;
alias Repository = map[str, Rule];
alias Captures = map[str, map[str, ScopeName]];

data Grammar = grammar(
    // Not supported by VS Code:
    // str foldingStartMarker = "",
    // str foldingStopMarker = "",

    // Supported by VS Code (mandatory):
    Repository repository,
    ScopeName scopeName,
    list[Rule] patterns,

    // Supported by VS Code (optional):
    map[str, Rule] injections = (),
    str injectionSelector = "",
    list[str] fileTypes = [],
    str name = "",
    str firstLineMatch = "");

data Rule
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
        list[Rule] patterns = [],
        Repository repository = ())

    | include(
        str include,
        Repository repository = ());

@synopsis{
    Creates an empty grammar named `scopeName`
}

Grammar empty(ScopeName scopeName)
    = grammar((), scopeName, []);

@synopsis{
    Adds a rule to the repository and patterns of grammar `g`
}

Grammar addRule(Grammar g, Rule r)
    = g [repository = g.repository + (r.name: r)]
        [patterns = g.patterns + include("#<r.name>")];

@synopsis{
    Converts list of strings `names` to a map of captures
}

Captures toCaptures(list[str] names)
    = ("<n + 1>": ("name": names[n]) | n <- [0..size(names)]);