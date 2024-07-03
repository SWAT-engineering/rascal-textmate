module lang::rascal::grammar::analyze::Dependencies

// This module does not import:
//   - `analysis::graphs::Graph`, because it works for *reflective* edge
//     relations, but not non-reflective ones (as needed here);
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
    // Filters productions that satisfy predicate `p` (and their dependencies)
    // from the underlying dependency graph
    Dependencies(Predicate p) filterProds,

    // Removes productions that satisfy predicate `p` (and their dependencies),
    // from the underlying dependency graph, optionally including (for removal)
    // all ancestors of those productions (and their dependencies)
    Dependencies(Predicate p, bool removeAncestors) removeProds,

    // Gets the productions from the underlying dependency graph
    list[Production]() getProds
);

@synopsis{
    Implements the `Dependencies` interface
}

Dependencies deps(Graph g) {
    Dependencies filterProds(Predicate p)
        = deps(filterNodes(g, getNodes(g, p)));
    Dependencies removeProds(Predicate p, bool removeAncestors)
        = deps(removeNodes(g, getNodes(g, p, getAncestors = removeAncestors)));
    list[Production] getProds()
        = toList(g.nodes);
    
    return deps(filterProds, removeProds, getProds);
}

@synopsis{
    Converts grammar `g` to a dependency graph for its productions
}

// TODO: If these aliases were to be parameterized, then they (and the functions
// that rely on them) could be moved to a separate, generic module.
alias Graph = tuple[Nodes nodes, Edges edges];
alias Nodes = set[Node];
alias Node  = Production;
alias Edges = rel[Node, Node];
alias Index = map[Node, set[Node]];

Graph toGraph(Grammar g)
    = <toNodes(g), toEdges(g)>;

private Nodes toNodes(Grammar g)
    = {n | /n: prod(_, _, _) := g};
private Nodes toNodes(Grammar g, Symbol s)
    = {n | /n: prod(_, _, _) := g.rules[delabel(s)] ? []};

private Edges toEdges(Grammar g)
    = {<from, to> | from: prod(_, /Symbol s, _) <- toNodes(g), to <- toNodes(g, s)}; 

@synopsis{
    Gets the nodes of dependency graph `g` that satisfy predicate `p`,
    optionally including all ancestors/descendants of those nodes
}

// Predicates are used to select nodes in the dependency graph, based on their
// own properties, their ancestors, and their descendants
alias Predicate = bool(
    Node  n, 
    Nodes ancestors /* of `n` in the dependency graph */,  
    Nodes descendants /* of `n` in the dependency graph */);

Nodes getNodes(Graph g, Predicate p,
        bool getAncestors = false, bool getDescendants = false) {
    
    // Compute ancestors/descendants of nodes
    Edges closure = g.edges+;
    Index ancestors = (n: {} | n <- g.nodes) + index(invert(closure));
    Index descendants = (n: {} | n <- g.nodes) + index(closure);

    // Select nodes
    Nodes nodes = {n | n <- g.nodes, p(n, ancestors[n], descendants[n])};
    nodes += ({} | it + ancestors[n] | getAncestors, n <- nodes);
    nodes += ({} | it + descendants[n] | getDescendants, n <- nodes);
    return nodes;
}

@synopsis{
    Filters/removes nodes (and connected edges) from dependency graph `g`
}

Graph filterNodes(Graph g, Nodes nodes)
    = <g.nodes & nodes, carrierR(g.edges, nodes)>;

Graph removeNodes(Graph g, Nodes nodes)
    = <g.nodes - nodes, carrierX(g.edges, nodes)>;