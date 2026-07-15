import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A `ref object` that contains a pure `object` field.
# The ref itself is non-copyable (move semantics), but its object FIELD
# can be read/copied freely because the field type is copyable.
# Reading a copyable field from a ref does NOT count as a move of the ref.

type
  Vec2 = object
    x, y: float
  Entity = ref object
    pos: Vec2     # copyable object field inside a non-copyable ref
    id: int       # primitive, also copyable

proc main() =
  var e = Entity(pos: Vec2(x: 3.0, y: 4.0), id: 7)

  var pos_copy = e.pos    # copy of e.pos (Vec2 is copyable) — e stays Alive
  var id_copy = e.id      # copy of e.id (int is copyable)  — e stays Alive

  echo pos_copy.x         # OK: independent value copy
  echo id_copy            # OK: independent value copy
  echo e.pos.x            # OK: e is still Alive, pos was copied not moved
  echo e.id               # OK: e is still Alive

main()
