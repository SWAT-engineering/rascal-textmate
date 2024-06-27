module lang::oniguruma::RegExp

import Grammar;
import List;
import ParseTree;
import Set;
import String;

data RegExp
    = regExp(str string, list[str] categories)
    | nil();

@synopsis{
    Add prefix/suffix `s` to regular expression `re`
}

RegExp prefix(str s, regExp(string, categories))
    = regExp("<s><string>", categories);
RegExp prefix(str _, nil())
    = nil();

RegExp suffix(str s, regExp(string, categories))
    = regExp("<string><s>", categories);
RegExp suffix(str _, nil())
    = nil();

@synopsis{
    Add infix `s` between regular expressions `regExps`
}

RegExp infix(str _, [])
    = nil();
RegExp infix(str _, [RegExp re])
    = re;
RegExp infix(str s, list[RegExp] regExps)
    = group(\join(s, regExps)) when size(regExps) > 1;

@synopsis{
    Wraps a regular expression in a group, optionally captured when `category`
    is set.
}

RegExp group(re: regExp(_, _), str category = "")
    = re[string = "(<ungroup(re.string)>)"][categories = [category] + re.categories] when category?;
RegExp group(re: regExp(_, _), str category = "")
    = re[string = "(?:<re.string>)"];
RegExp group(nil(), str category = "")
    = nil();

str ungroup(str old)
    = /^\(\?:<new:.*>\)$/ := old ? new : old;

@synopsis{
    Joins a list of regular expressions `regExps` into a regular expression,
    separated by `sep`. Returns `nil()` when the list is empty or
    contains `nil()`.
}

RegExp \join(str sep, list[RegExp] regExps) 
    = isEmpty(regExps) || nil() in regExps
    ? nil()
    : regExp(
        intercalate(sep, [re.string | re <- regExps]),
        ([] | it + re.categories | re <- regExps));