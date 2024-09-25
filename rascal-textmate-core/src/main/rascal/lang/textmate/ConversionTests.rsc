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
import lang::textmate::ConversionConstants;
import lang::textmate::ConversionUnit;
import lang::textmate::Grammar;

bool doAnalyzeTest(RscGrammar rsc, list[ConversionUnit] expect, str name = "", bool printActual = false) {
    list[ConversionUnit] actual = analyze(rsc, name);

    if (printActual) {
        str syntheticProductionNameVars(str s)
            = replaceAll(replaceAll(s,                 
                "\"<DELIMITERS_PRODUCTION_NAME>\"", "DELIMITERS_PRODUCTION_NAME"),
                "\"<KEYWORDS_PRODUCTION_NAME>\"",   "KEYWORDS_PRODUCTION_NAME");
        
        str tagEscape(str s)
            = /<before:.*[^\\]>\btag\b<after:.*>/ := s 
            ? tagEscape("<before>\\tag<after>")
            : s;
        
        str toStr(Production p)
            = tagEscape(syntheticProductionNameVars("<p>"));

        println();
        for (i <- [0..size(actual)]) {
            ConversionUnit u = actual[i];
            println("    unit(rsc, <toStr(u.prod)>, <u.recursive>, <u.multiLine>, <u.outerDelimiters>, <u.innerDelimiters>)<i < size(actual) - 1 ? "," : "">");
        }
        println();
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
    TmGrammar tm = transform(units, name);
    
    loc lProject = |project://rascal-textmate-core|;
    loc lGrammar = lProject + "/target/generated-test-grammars/<name>.tmLanguage.json";
    toJSON(tm, l = resolveLocation(lGrammar));

    // Test structural properties of the TextMate grammar
    
    Repository repo = tm.repository;
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
    assert actual.beginEnd == expect.beginEnd : "Actual number of top-level begin/end patterns in repository: <actual.beginEnd>. Expected: <expect.beginEnd>.";
    assert actual.include == expect.include : "Actual number of top-level include patterns in repository: <actual.include>. Expected: <expect.include>.";

    // Test behavioral properties of the TextMate grammar
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

        // TODO: The following function serves as a workaround for a race
        // in (the Java-part of) the implementation of `execWithCode`. A fix is
        // already available but not yet released. When it is, this function
        // should be removed (and `execWithCode` called directly). See also:
        // https://github.com/usethesource/rascal/commit/1ce9e59dfd7098327bbaf55a985c2a643ff52861
        tuple[str, int] execWithCodeUntilSuccess() {
            try {
                return execWithCode(lExec, args = args);
            } catch e: {
                println("[LOG] Retrying after unexpected exception: <e>");
                return execWithCodeUntilSuccess();
            }
        }
        
        if (<output, exitCode> := execWithCodeUntilSuccess() && exitCode != 0) {
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