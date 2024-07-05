@synopsis{
    Functions to simplify testing of module `lang::testmate::Conversion`
}

module lang::textmate::ConversionTests

import Grammar;
import List;
import Map;
import ParseTree;

import lang::textmate::Conversion;
import lang::textmate::Grammar;

bool doAnalyzeTest(RscGrammar rsc, list[ConversionUnit] expect) {
    list[ConversionUnit] actual = analyze(rsc);

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

bool doTransformTest(list[ConversionUnit] units, RepositoryStats expect) {
    TmGrammar tm = transform(units);
    Repository repo = tm.repository;
    list[TmRule] pats = tm.patterns;
    
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
    return true;
}

alias RepositoryStats = tuple[int match, int beginEnd, int include];

int sum(RepositoryStats stats)
    = stats.match + stats.beginEnd + stats.include;