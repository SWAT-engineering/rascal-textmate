@synopsis{
    Functions to simplify testing of module `lang::testmate::Conversion`
}

module lang::textmate::ConversionTests

import Grammar;
import IO;
import List;
import Map;
import ParseTree;
import String;
import util::ShellExec;
import util::SystemAPI;

import lang::textmate::Conversion;
import lang::textmate::Grammar;

bool doAnalyzeTest(RscGrammar rsc, list[ConversionUnit] expect, bool printActual = false) {
    list[ConversionUnit] actual = analyze(rsc);

    for (printActual, u <- actual) {
        println("unit(rsc, <u.prod>),");
    }

    for (u <- actual) {
        assert u in expect : "Actual but not expected: <u.prod>";
    }

    for (u <- expect) {
        assert u in actual : "Expected but not actual: <u.prod>";
    }

    int i = 0;
    for (<u1, u2> <- zip2(actual, expect)) {
        assert u1 == u2 : "Actual at index <i>: <u1.prod>. Expected: <u2.prod>";
        i += 1;
    }

    return true;
}

bool doTransformTest(list[ConversionUnit] units, RepositoryStats expect, str name = "") {
    TmGrammar tm = transform(units)[scopeName = "<name>"];
    Repository repo = tm.repository;
    list[TmRule] pats = tm.patterns;
    
    // Test structural properties of the TextMate grammar
    
    RepositoryStats actual = <
        (0 | it + 1 | s <- repo, repo[s] is match),
        (0 | it + 1 | s <- repo, repo[s] is beginEnd),
        (0 | it + 1 | s <- repo, repo[s] is include)
    >;

    int expectTopLevel = sum(expect);
    int actualTopLevel = sum(actual);

    assert size(repo) == actualTopLevel : "Repository contains pattern(s) of unexpected kind";
    assert actualTopLevel == expectTopLevel : "Actual repository size: <actualTopLevel>. Expected: <expectTopLevel>.";
    assert actual.match == expect.match : "Actual number of top-level match patterns in repository: <actual.match>. Expected: <expect.match>.";
    assert actual.beginEnd == expect.beginEnd : "Actual number of top-level begin/end patterns in repository: <actual.match>. Expected: <expect.match>.";
    assert actual.include == expect.include : "Actual number of top-level include patterns in repository: <actual.match>. Expected: <expect.match>.";
    
    int expectNested = size(units) - expect.match - expect.include;
    int actualNested = (0 | it + size(repo[s].patterns) | s <- repo, repo[s] is beginEnd);
    assert actualNested == expectNested : "Actual number of nested patterns: <actualNested>. Expected: <expectNested>.";

    assert size(pats) == size(repo) : "Actual patterns list size: <size(pats)>. Expected: <size(repo)>.";
    assert (true | it && r is include | r <- pats) : "Patterns list contains pattern(s) of unexpected kind";
    assert (true | it && s in repo | r <- pats, include(/#<s:.*>$/) := r) : "Patterns list contains pattern(s) outside repository";

    // Test behavioral properties of the TextMate grammar

    loc lProject = |project://rascal-textmate-core|;
    loc lGrammar = lProject + "/target/generated-test-grammars/<name>.tmLanguage.json";
    toJSON(tm, l = resolveLocation(lGrammar));
    
    loc lTest = lProject + "/src/main/rascal/lang/textmate/conversiontests/<name>.test";
    loc lTester = lProject + "/node_modules/vscode-tmgrammar-test";
    if (!exists(lTest)) {
        println("[LOG] No tokenization tests available for `<name>` (`<resolveLocation(lTest).path>` does not exist)");
    } elseif (!exists(lTester)) {
        println("[LOG] No tokenizer available (`<resolveLocation(lTester).path>` does not exist)");
    } else {
        bool windows = startsWith(getSystemProperty("os.name"), "Windows");
        loc lExec = |PATH:///npx<windows ? ".cmd" : "">|;
        list[str] args = [
            "vscode-tmgrammar-test",
            "--grammar",
            resolveLocation(lGrammar).path[(windows ? 1 : 0)..],
            resolveLocation(lTest).path[(windows ? 1 : 0)..]
        ];

        if (<output, exitCode> := execWithCode(lExec, args = args) && exitCode != 0) {
            println(output);
            assert false : "Actual tokenization does not match expected tokenization (see output above for details)";
        }
    }

    return true;
}

alias RepositoryStats = tuple[
    int match,
    int beginEnd,
    int include];

int sum(RepositoryStats stats)
    = stats.match
    + stats.beginEnd
    + stats.include;