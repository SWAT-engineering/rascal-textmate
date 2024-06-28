module lang::textmate::ConversionTests

import Grammar;
import Map;
import ParseTree;

import lang::textmate::Conversion;
import lang::textmate::Grammar;

bool doAnalyzeTest(RscGrammar rsc, list[ConversionUnit] units) {
    assert analyze(rsc) == units;
    return true;
}

bool doTransformTest(list[ConversionUnit] units, tuple[int match, int beginEnd, int include] sizes) {
    TmGrammar tm = transform(units);
    Repository repo = tm.repository;
    list[TmRule] pats = tm.patterns;

    assert size(repo) == sizes.match + sizes.beginEnd + sizes.include;
    assert (0 | it + 1 | s <- repo, repo[s] is match) == sizes.match;
    assert (0 | it + 1 | s <- repo, repo[s] is beginEnd) == sizes.beginEnd;
    assert (0 | it + 1 | s <- repo, repo[s] is include) == sizes.include;
    assert (0 | it + size(repo[s].patterns) | s <- repo, repo[s] is beginEnd) == size(units) - sizes.match - sizes.include;

    assert size(pats) == size(repo);
    assert (true | it && include(/#.*$/) := r | r <- pats);
    assert (true | it && s in repo | r <- pats, include(/#<s:.*>$/) := r);
    return true;
}