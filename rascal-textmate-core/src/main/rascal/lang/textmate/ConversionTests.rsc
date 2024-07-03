module lang::textmate::ConversionTests

import Grammar;
import IO;
import List;
import Map;
import ParseTree;
// import lang::json::IO;

import lang::textmate::Conversion;
import lang::textmate::Grammar;

bool doAnalyzeTest(RscGrammar rsc, list[ConversionUnit] expected) {
    list[ConversionUnit] actual = analyze(rsc);

    for (u <- actual) {
        if (u notin expected) {
            println("[ERROR] <u.prod>");
            assert false : "actual but not expected";
        }
    }
    
    for (u <- expected) {
        if (u notin actual) {
            println("[ERROR] <u.prod>");
            assert false : "expected but not actual";
        }
    }

    int i = 0;
    for (<u1, u2> <- zip2(actual, expected)) {
        if (u1 != u2) {
            println("[ERROR] at index <i>: <u1.prod> actual, <u2.prod> expected");
            assert false : "same elements, different order";
        }
        i += 1;
    }

    return true;
}

bool doTransformTest(list[ConversionUnit] units, tuple[int match, int beginEnd, int include] expected) {
    TmGrammar tm = transform(units);
    Repository repo = tm.repository;
    list[TmRule] pats = tm.patterns;
    // println(asJSON(repo, indent=2));

    assert size(repo) == expected.match + expected.beginEnd + expected.include;
    assert (0 | it + 1 | s <- repo, repo[s] is match) == expected.match;
    assert (0 | it + 1 | s <- repo, repo[s] is beginEnd) == expected.beginEnd;
    assert (0 | it + 1 | s <- repo, repo[s] is include) == expected.include;
    assert (0 | it + size(repo[s].patterns) | s <- repo, repo[s] is beginEnd) == size(units) - expected.match - expected.include;

    assert size(pats) == size(repo);
    assert (true | it && include(/#.*$/) := r | r <- pats);
    assert (true | it && s in repo | r <- pats, include(/#<s:.*>$/) := r);
    return true;
}