module lang::oniguruma::RegExp

import Grammar;
import List;
import ParseTree;
import Set;
import String;

data RegExp = regExp(str string, list[str] categories);

@synopsis{
    Add prefix/suffix `s` to regular expression `re`
}

RegExp prefix(str s, regExp(string, categories))
    = regExp("<s><string>", categories);

RegExp suffix(str s, regExp(string, categories))
    = regExp("<string><s>", categories);

@synopsis{
    Add infix `s` between regular expressions `regExps`
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

str ungroup(str old)
    = /^\(\?:<new:.*>\)$/ := old ? new : old;