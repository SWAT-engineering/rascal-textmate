module lang::rascal::grammar::analyze::Dependencies

import Grammar;
import ParseTree;
import Relation;
import Set;

import lang::rascal::grammar::Util;

// This module does not reuse:
//   - `analysis::graphs::Graph`, because it works for *reflective* edge
//     relations, but not non-reflective ones (as needed here);
//   - `analysis::grammars::Dependency`, because it analyzes dependencies
//     between symbols instead of productions.

data Dependencies = deps(
    Dependencies(Predicate p, bool filterAncestors, bool filterDescendants) filterProds,
    Dependencies(Predicate p, bool removeAncestors, bool removeDescendants) removeProds,
    list[Production]() getProds);

Dependencies deps(Grammar g) {
    return deps(toGraph(g));
}

Dependencies deps(Graph g) {
    Dependencies filterProds(Predicate p, bool b1, bool b2)
        = deps(filterNodes(g, getNodes(g, p, getAncestors = b1, getDescendants = b2)));
    Dependencies removeProds(Predicate p, bool b1, bool b2)
        = deps(removeNodes(g, getNodes(g, p, getAncestors = b1, getDescendants = b2)));
    list[Production] getProds()
        = toList(g.nodes);
    
    return deps(filterProds, removeProds, getProds);
}

@synopsis{
    Converts grammar `g` to a dependency graph for its productions
}

alias Graph = tuple[Nodes nodes, Edges edges];
alias Nodes = set[Production];
alias Edges = rel[Production, Production];
alias Index = map[Production, set[Production]];

Graph toGraph(Grammar g)
    = <toNodes(g), toEdges(g)>;

private Nodes toNodes(Grammar g)
    = {n | /n: prod(_, _, _) := g};
private Nodes toNodes(Grammar g, Symbol s)
    = {n | /n: prod(_, _, _) := g.rules[delabel(s)] ? []};

private Edges toEdges(Grammar g)
    = {<from, to> | from: prod(_, /Symbol s, _) <- toNodes(g), to <- toNodes(g, s)}; 

@synopsis{
    Gets the nodes of graph `g` that satisfy predicate `p`, optionally including
    all ancestors/descendants of those nodes
}

alias Predicate = bool(Production n, set[Production] ancestors, set[Production] descendants);

Nodes getNodes(Graph g, Predicate p, bool getAncestors=false, bool getDescendants=false) {
    Edges closure = g.edges+; // TODO: Cache `closure`
    Index ancestors = (n: {} | n <- g.nodes) + index(invert(closure));
    Index descendants = (n: {} | n <- g.nodes) + index(closure);

    Nodes nodes = {n | n <- g.nodes, p(n, ancestors[n], descendants[n])};
    nodes += ({} | it + ancestors[n] | getAncestors, n <- nodes);
    nodes += ({} | it + descendants[n] | getDescendants, n <- nodes);
    return nodes;
}

@synopsis{
    Filters/removes nodes (and connected edges) from graph `g`
}

Graph filterNodes(Graph g, Nodes nodes)
    = <g.nodes & nodes, carrierR(g.edges, nodes)>;

Graph removeNodes(Graph g, Nodes nodes)
    = <g.nodes - nodes, carrierX(g.edges, nodes)>;