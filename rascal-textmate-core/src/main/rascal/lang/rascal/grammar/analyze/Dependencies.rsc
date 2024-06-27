module lang::rascal::grammar::analyze::Dependencies

import Grammar;
import ParseTree;
import Relation;

import lang::rascal::grammar::Util;

// This module does not reuse:
//   - `analysis::graphs::Graph`, because it works for *reflective* edge
//     relations, but not non-reflective ones (as needed here);
//   - `analysis::grammars::Dependency`, because it analyzes dependencies
//     between symbols instead of individual productions.

alias Graph = tuple[Nodes nodes, Edges edges];
alias Nodes = set[Production];
alias Edges = rel[Production, Production];
alias Index = map[Production, set[Production]];

@synopsis{
    Converts grammar `g` to a dependency graph for its productions
}

Graph toGraph(Grammar g)
    = <toNodes(g), toEdges(g)>;

private Nodes toNodes(Grammar g)
    = {n | /n: prod(_, _, _) := g};
private Nodes toNodes(Grammar g, Symbol s)
    = {n | /n: prod(_, _, _) := g.rules[delabel(s)] ? []};

private Edges toEdges(Grammar g)
    = { <from, to> | from: prod(_, /Symbol s, _) <- toNodes(g), to <- toNodes(g, s)}; 

@synopsis{
    Gets the nodes of graph `g` that satisfy predicate `p`, optionally including
    all ancestors/descendants of those nodes
}

alias Predicate = bool(Production n, set[Production] ancestors, set[Production] descendants);

Nodes getNodes(Graph g, Predicate p, bool getAncestors=false, bool getDescendants=false) {
    Edges closure = g.edges+;
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
Graph filterNodes(Graph g, Predicate p, bool filterAncestors = false, bool filterDescendants = false)
    = filterNodes(g, getNodes(g, p, getAncestors = filterAncestors, getDescendants = filterDescendants));

Graph removeNodes(Graph g, Nodes nodes)
    = <g.nodes - nodes, carrierX(g.edges, nodes)>;
Graph removeNodes(Graph g, Predicate p, bool removeAncestors = false, bool removeDescendants = false)
    = removeNodes(g, getNodes(g, p, getAncestors = removeAncestors, getDescendants = removeDescendants));