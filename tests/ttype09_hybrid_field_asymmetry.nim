import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A ref struct with BOTH object fields AND ref fields.
# The two kinds of fields obey different rules simultaneously:
#   - Object field access = copy → parent ref stays Alive
#   - Ref field assignment = move → that sub-path becomes Moved
# This is the core asymmetry of the mixed-type system.

type
  Meta = object
    version: int       # copyable
  Resource = ref object
    id: int            # copyable
  Handle = ref object
    meta: Meta         # copyable field
    res: Resource      # non-copyable field

proc main() =
  var h = Handle(meta: Meta(version: 3), res: Resource(id: 42))

  var m = h.meta        # copy h.meta (Meta is object → value copy, h stays Alive)
  var r = h.res         # MOVE h.res  (Resource is ref → move, h.res is Moved)

  echo m.version        # OK: independent copy of meta
  echo r.id             # OK: r owns the resource
  echo h.meta.version   # OK: h.meta was copied, h itself is still Alive (h.res moved)
  echo h.res.id         # Error: h.res was moved to r

main()
