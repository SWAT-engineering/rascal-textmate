module lang::rascal::Util

import Exception;
import Grammar;
import ParseTree;

Symbol expand(\iter-seps(symbol, separators))
    = \seq([symbol, \iter-star(\seq(separators + symbol))]);
Symbol expand(\iter-star-seps(symbol, separators))
    = \opt(expand(\iter-seps(symbol, separators)));

&T subst(&T t, list[Symbol] from, list[Symbol] to)
    = subst(t, toMapUnique(zip2(from, to))) when size(from) == size(to);
&T subst(&T t, map[Symbol, Symbol] m)
    = visit (t) { case Symbol s => m[s] when s in m };

bool tryParse(map[Symbol, Production] rules, Symbol s, str input) {
    if (isNonTerminalType(s) && \parameterized-sort(_, _) !:= s && \parameterized-lex(_, _) !:= s) {
        if (value v := type(s, rules), type[Tree] t := v) {
            try { parse(t, input, allowAmbiguity=true); return true; }
            catch ParseError(_): return false;
        }
    }
    return false;
}