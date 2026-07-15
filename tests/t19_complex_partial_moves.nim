import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Complex interleaving of partial moves, sibling access, and field revives
# across multiple struct levels. Tests that the path tracking correctly handles
# multiple simultaneous partial-move states on different subtrees.

type
  Leaf = ref object
    v: int
  Branch = ref object
    l: Leaf
    r: Leaf
  Tree = ref object
    left: Branch
    right: Branch

proc main() =
  var t = Tree(
    left:  Branch(l: Leaf(), r: Leaf()),
    right: Branch(l: Leaf(), r: Leaf())
  )

  var ll = t.left.l          # move t.left.l
  echo t.left.r.v            # OK: t.left.r is sibling of t.left.l
  echo t.right.l.v           # OK: t.right subtree untouched

  t.left.l = Leaf()          # revive t.left.l
  echo t.left.l.v            # OK: t.left.l was revived

  var rl = t.right.l         # move t.right.l
  echo t.right.r.v           # OK: t.right.r is independent
  echo t.left.l.v            # OK: t.left.l is still alive (was revived)
  echo t.right.l.v           # Error: t.right.l was moved and not revived

main()
