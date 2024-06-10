module lang::rascal::Util

import ParseTree;

Symbol expand(\iter-seps(symbol, separators))
    = \seq([symbol, \iter-star(\seq(separators + symbol))]);
Symbol expand(\iter-star-seps(symbol, separators))
    = \opt(expand(\iter-seps(symbol, separators)));
