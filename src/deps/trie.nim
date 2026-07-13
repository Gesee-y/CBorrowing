# ########################################################################################################## #
# ############################################## TRIE IMPLEMENTATION ####################################### #
# ########################################################################################################## #

type
  TNode[T] = object
    data: T
    children: Table[string, int]

  Trie[T] = object
    nodes: seq[TNode[T]]
    roots: TNode[T]

proc newTrie[T](): Trie[T] =
  result = Trie[T]()
  result.nodes.add(default(TNode[T]))

proc addNode[T](t: Trie[T], data: seq[string]) =
  if data.len <= 0: return

  var root = 0
  for d in data:
    if d in t.nodes[root].children:
      root = t.nodes[root].children.getOrDefault(d)
    else:
      let n = t.nodes.len
      t.nodes.add(TNode[T](name: d))
      t.nodes[root].children[d] = n
      root = n

proc fetchNode[T](t: Trie[T], data: seq[string]): int =
  if data.len <= 0: return -1

  result = 0
  for d in data:
    result = t.nodes[result].children.getOrQuit(d)

proc getAllSuffix[T](t: Trie[T], node: TNode[T], stack: var seq[int]): int =
  for v in node.children.values:
    stack.add(v)
    t.getAllSuffixSuffix(t.nodes[v], stack)

iterator iterateSuffix[T](t: Trie[T], node: TNode[T]): int =
  for v in t.getAllSuffix(node):
    yield v

iterator iterateSuffix[T](t: Trie[T], data: seq[string]): int =
  let node = t.fetchNode(data)
  for v in t.iterateSuffix(node):
    yield v
