import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Three-level chain — ref → object → ref.
# The outer ref is move-checked. The middle object layer is transparent (value).
# The inner ref (field of the middle object) is also move-checked independently.
# Path: outer → middle (obj, copy) → inner (ref, move).

type
  Leaf = ref object
    data: int
  Middle = object       # pure object layer in the chain
    leaf: Leaf          # ref inside the object → Middle is non-copyable
    tag: int
  Container = ref object
    mid: Middle         # non-copyable object field inside a ref

proc main() =
  var c = Container(mid: Middle(leaf: Leaf(data: 99), tag: 7))

  # Access the copyable int field through the chain: c.mid.tag (int — copy)
  var tag_copy = c.mid.tag      # copy int through two levels — c stays Alive

  # Move the inner ref through the chain: c.mid.leaf (ref — move)
  var leaf = c.mid.leaf         # move c.mid.leaf — c.mid.leaf is now Moved

  echo tag_copy                 # OK: independent int copy
  echo leaf.data                # OK: leaf owns the Leaf ref
  echo c.mid.tag                # OK: c.mid.tag is still copyable and accessible
  echo c.mid.leaf.data          # Error: c.mid.leaf was moved to `leaf`

main()
