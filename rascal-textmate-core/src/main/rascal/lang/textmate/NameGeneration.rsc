@synoposis{
    Types and functions to generate names for TextMate rules
}

module lang::textmate::NameGeneration

import Grammar;
import ParseTree;
import String;
import lang::rascal::format::Grammar;

data NameGeneration              // Given a production `p` of the form `prod(label(l, sort(s)), _, _)`... 
    = short()                    // ...the generated name is of the form `<s>.<l>`
    | long(bool pretty = false); // ...the generated name is of the form `<p>` (optionally pretty-printed)

alias NameGenerator = str(Production);

@synoposis{
    Creates a name generator for list of productions `prods`, using a particular
    name generation scheme.
}

NameGenerator newNameGenerator(list[Production] prods, short()) {

    // Define auxiliary functions to compute names for symbols
    str toName(sort(name)) = toLowerCase(name);
    str toName(lex(name)) = toLowerCase(name);
    str toName(label(name, symbol)) = "<toName(symbol)>.<name>";

    // Define auxiliary function to count the number of occurrences of a name
    int count(str name) = (0 | it + 1 | p <- prods, toName(p.def) == name);

    // Determine which names should be suffixed with an index (i.e., this is the
    // case when multiple productions would otherwise get the same name)
    set[str] names = {toName(p.def) | p <- prods};
    map[str, int] nextIndex = (name: 0 | name <- names, count(name) > 1);

    // Return the generator
    return str(Production p) {
        str name = toName(p.def);
        if (name in nextIndex) { // Suffix an index if needed
            nextIndex += (name: nextIndex[name] + 1);
            name += ".<nextIndex[name]>";
        }
        return name;
    };
}

NameGenerator newNameGenerator(list[Production] _, long(pretty = pretty)) {
    return str(Production p) {
        return pretty ? "<prod2rascal(p)>" : "<p>";
    };
}
