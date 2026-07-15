import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: An object with multiple ref fields can have its ref fields
# independently moved. Moving one ref field does NOT affect sibling ref fields
# or copyable fields. The parent object becomes partial (like ttype16 but for
# objects wrapping refs instead of ref wrapping refs).

type
  Node = ref object
    v: int
  BiLink = object      # non-copyable: has two ref fields
    prev: Node
    next: Node
    weight: float      # copyable field

proc main() =
  var link = BiLink(prev: Node(v: 1), next: Node(v: 2), weight: 0.5)

  var p = link.prev       # move link.prev  (ref field → move)
  var w = link.weight     # copy link.weight (float field → copy, link stays partial-alive)

  echo p.v                # OK: p owns prev
  echo w                  # OK: independent copy of weight
  echo link.next.v        # OK: link.next is a sibling of link.prev, unaffected
  echo link.weight        # OK: weight was copied, not moved
  echo link.prev.v        # Error: link.prev was moved to p

main()
