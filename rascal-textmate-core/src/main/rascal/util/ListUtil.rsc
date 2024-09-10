module util::ListUtil

import List;
import util::Benchmark;
import IO;

@synopsis{
    Representation of a traversal direction along a list
}

data Direction   // Traverse lists...
    = forward()  //   - ...from left to right;
    | backward() //   - ...from right to left.
    ;

@synopsis{
    Reorder a list according to the specified direction
}

list[&T] reorder(list[&T] l, forward())  = l;
list[&T] reorder(list[&T] l, backward()) = reverse(l);

@synopsis{
    Removes multiple occurrences of elements in a list. The last occurrence
    remains (cf. `List::dup`).
}

list[&T] dupLast(list[&T] l) = reverse(dup(reverse(l))); // TODO: Optimize/avoid `reverse`-ing?

@synopsis{
    Checks if list `l1` is a strict prefix of list `l2`
}

bool isStrictPrefix(list[&T] l1, list[&T] l2)
    = size(l1) < size(l2) && l1 == l2[..size(l2)];