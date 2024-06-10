module lang::textmate::Grammar

import Map;
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

Grammar merge(Grammar g1, Grammar g2) {
    if (isEmpty(domain(g1.repository) & domain(g2.repository)) && g1.scopeName == g2.scopeName) {
        return grammar(g1.repository + g2.repository, g1.scopeName, g1.patterns + g2.patterns);
    } else {
        throw "Cannot merge grammars <g1> and <g2>";
    }
}