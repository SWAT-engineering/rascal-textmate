@license{
BSD 2-Clause License

Copyright (c) 2024, Swat.engineering

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}
@synopsis{
    Types and functions to analyze dependencies among productions
}

@description{
    This module does not import:
      - `analysis::graphs::Graph`, because it works for *reflexive* binary
        relations, but not non-reflexive ones (as needed here);
      - `analysis::grammars::Dependency`, because it analyzes dependencies
        between symbols instead of productions.
}

module lang::rascal::grammar::analyze::Dependencies

import Grammar;
import ParseTree;
import Relation;
import Set;

import lang::rascal::grammar::Util;

@synoposis{
    Representation of an interface with functions to manipulate/query dependency
    graphs among productions
}

data Dependencies = deps(
    // Retains productions that satisfy a predicate (and their dependencies)
    // from the underlying dependency graph
    Dependencies(Predicate[Production]) retainProds,

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
    Dependencies retainProds(Predicate[Production] p)
        = deps(retainNodes(g, getNodes(g, p)));
    Dependencies removeProds(Predicate[Production] p, bool removeAncestors)
        = deps(removeNodes(g, getNodes(g, p, getAncestors = removeAncestors)));
    list[Production] getProds()
        = toList(g.nodes);
    
    return deps(retainProds, removeProds, getProds);
}

@synopsis{
    Converts grammar `g` to a dependency graph among its productions
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
    Representation of graphs to manipulate/query (possibly non-reflexive) binary
    relations
}

alias Graph[&Node] = tuple[
    set[&Node] nodes,
    rel[&Node, &Node] edges];

@synopsis {
    Representation of predicates to select nodes in a graph based on their own
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
    rel[&Node, &Node] descendants = g.edges+;
    rel[&Node, &Node] ancestors = invert(descendants);

    // Select nodes
    nodes = {n | n <- g.nodes, p(n, ancestors[n] ? {}, descendants[n] ? {})};
    nodes += ({} | it + (ancestors[n] ? {}) | getAncestors, n <- nodes);
    nodes += ({} | it + (descendants[n] ? {}) | getDescendants, n <- nodes);
    return nodes;
}

@synopsis{
    Retains nodes (and connected edges) from graph `g`
}

Graph[&Node] retainNodes(Graph[&Node] g, set[&Node] nodes)
    = <g.nodes & nodes, carrierR(g.edges, nodes)>;

@synopsis{
    Removes nodes (and connected edges) from graph `g`
}

Graph[&Node] removeNodes(Graph[&Node] g, set[&Node] nodes)
    = <g.nodes - nodes, carrierX(g.edges, nodes)>;