module lang::rascal::grammar::analyze::Dependencies

// This module does not import:
//   - `analysis::graphs::Graph`, because it works for *reflexive* binary
//     relations, but not non-reflexive ones (as needed here);
//   - `analysis::grammars::Dependency`, because it analyzes dependencies
//     between symbols instead of productions.

import Grammar;
import ParseTree;
import Relation;
import Set;

import lang::rascal::grammar::Util;

@synoposis{
    Interface to manipulate dependency graphs for productions
}

data Dependencies = deps(
    // Filters productions that satisfy a predicate (and their dependencies)
    // from the underlying dependency graph
    Dependencies(Predicate[Production]) filterProds,

    // Removes productions that satisfy a predicate (and their dependencies),
    // from the underlying dependency graph, optionally including (for removal)
    // all ancestors of those productions (and their dependencies)
    Dependencies(Predicate[Production], bool) removeProds,

    // Gets the productions from the underlying dependency graph
    list[Production]() getProds
);

@synopsis{
    Implements the `Dependencies` interface
}

Dependencies deps(Graph[Production] g) {
    Dependencies filterProds(Predicate[Production] p)
        = deps(filterNodes(g, getNodes(g, p)));
    Dependencies removeProds(Predicate[Production] p, bool removeAncestors)
        = deps(removeNodes(g, getNodes(g, p, getAncestors = removeAncestors)));
    list[Production] getProds()
        = toList(g.nodes);
    
    return deps(filterProds, removeProds, getProds);
}

@synopsis{
    Converts grammar `g` to a dependency graph for its productions
}

Graph[Production] toGraph(Grammar g)
    = <toNodes(g), toEdges(g)>;

private set[Production] toNodes(Grammar g)
    = {n | /n: prod(_, _, _) := g};
private set[Production] toNodes(Grammar g, Symbol s)
    = {n | /n: prod(_, _, _) := g.rules[delabel(s)] ? []};

private rel[Production, Production] toEdges(Grammar g)
    = {<from, to> | from: prod(_, /Symbol s, _) <- toNodes(g), to <- toNodes(g, s)}; 

// TODO: The remaining code in this file could be moved to a separate, generic
// module.

@synopsis{
    Graphs are used to represent (possibly non-reflexive) binary relations
}

alias Graph[&Node] = tuple[
    set[&Node] nodes,
    rel[&Node, &Node] edges];

@synopsis {
    Predicates are used to select nodes in a graph based on their own
    properties, their ancestors, and their descendants
}

alias Predicate[&Node] = bool(
    &Node n, 
    set[&Node] ancestors /* of `n` in the graph */,  
    set[&Node] descendants /* of `n` in the graph */);

@synopsis{
    Gets the nodes of graph `g` that satisfy predicate `p`, optionally including
    all ancestors/descendants of those nodes
}

set[&Node] getNodes(Graph[&Node] g, Predicate[&Node] p,
        bool getAncestors = false, bool getDescendants = false) {
    
    // Compute ancestors/descendants of nodes
    rel[&Node, &Node] closure = g.edges+;
    map[&Node, set[&Node]] ancestors = index(invert(closure));
    map[&Node, set[&Node]] descendants = index(closure);

    // Select nodes
    nodes = {n | n <- g.nodes, p(n, ancestors[n] ? {}, descendants[n] ? {})};
    nodes += ({} | it + (ancestors[n] ? {}) | getAncestors, n <- nodes);
    nodes += ({} | it + (descendants[n] ? {}) | getDescendants, n <- nodes);
    return nodes;
}

@synopsis{
    Filters/removes nodes (and connected edges) from graph `g`
}

Graph[&Node] filterNodes(Graph[&Node] g, set[&Node] nodes)
    = <g.nodes & nodes, carrierR(g.edges, nodes)>;

Graph[&Node] removeNodes(Graph[&Node] g, set[&Node] nodes)
    = <g.nodes - nodes, carrierX(g.edges, nodes)>;