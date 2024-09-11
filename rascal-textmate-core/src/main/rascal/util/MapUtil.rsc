module util::MapUtil

@synopsis{
    Updates the mapping of each key `k` in map of lists `m` to be the union of:
    (1) the existing list `m[k]`, and (2) the new elements-to-be-inserted
    `values[k]`. For instance:
      - m      = ("foo": [1, 2, 3],       "bar": [],    "baz": [1, 2])
      - values = ("foo": [4, 5],          "bar": [123], "qux": [3, 4])
      - return = ("foo": [1, 2, 3, 4, 5], "bar": [123], "baz": [1, 2])
}

map[&K, list[&V]] insertIn(map[&K, list[&V]] m, map[&K, &V] values)
    = (k: m[k] + (k in values ? [values[k]] : []) | k <- m);