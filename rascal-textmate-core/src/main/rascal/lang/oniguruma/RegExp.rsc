module lang::oniguruma::RegExp

import Grammar;
import List;
import ParseTree;
import Set;
import String;
import util::Maybe;

data RegExp = regExp(str string, list[str] categories);

Maybe[RegExp] prefix(str s, just(RegExp re)) = just(re[string="<s><re.string>"]);
Maybe[RegExp] prefix(str _, nothing())       = nothing();
Maybe[RegExp] suffix(str s, just(RegExp re)) = just(re[string="<re.string><s>"]);
Maybe[RegExp] suffix(str _, nothing())       = nothing();

Maybe[RegExp] infix(str _, [Maybe[RegExp] maybe])      = maybe;
Maybe[RegExp] infix(str s, list[Maybe[RegExp]] maybes) = group(\join([m | m <- maybes], s));

@synopsis{
    Wraps a regular expression in a group. The group is captured iff `category`
    is set.
}

Maybe[RegExp] group(just(RegExp re), str category = "")
    = just(re[string = "(<ungroup(re.string)>)"][categories = [category] + re.categories]) when category?;
Maybe[RegExp] group(just(RegExp re), str category = "")
    = just(re[string = "(?:<re.string>)"]);
Maybe[RegExp] group(nothing(), str category = "")
    = nothing();

str ungroup(str old)
    = /^\(\?:<new:.*>\)$/ := old ? new : old;

@synopsis{
    Joins a list of `Maybe[RegExp]` values into a single `Maybe[RegExp]` value.
    Returns `nothing()` when the list is empty or contains `nothing()`.
}

Maybe[RegExp] \join(list[Maybe[RegExp]] maybes, str sep) {
    if (isEmpty(maybes) || any(nothing() <- maybes)) {
        return nothing();
    } else {
        list[RegExp] res = [re | just(re) <- maybes];
        return just(regExp(intercalate(sep, [re.string | re <- res]), ([] | it + re.categories | re <- res)));
    }
}