/// Query operators
enum Op {
  // match operators
  and,
  or,
  not,
  //
  lt,
  gt,
  lte,
  gte,
  ne,
  //
  inList,
  notInList,
  // update operators
  set,
  unset,
  max,
  min,
  increment,
  multiply,
  rename
}
