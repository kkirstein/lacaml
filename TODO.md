* Improve performance with threads on small data

  Currently all external functions that have at least linear running time
  wrt. some parameter release the OCaml runtime lock.  This coarse-grained
  approach may make Lacaml perform less well with some functions on small
  amounts of data, and also in applications that link with threads, but do
  not really use them at runtime.  This problem is especially pronounced if
  the user has to deal with large numbers of small datasets and can lead to
  quite noticable slowdowns then.

  Solution: allow the user to explicitly request that the OCaml runtime lock
  be kept, and also provide for default heuristics that choose to keep it if
  some value computed from the function parameters does not exceed a certain
  value (e.g. matrix size, etc.).
