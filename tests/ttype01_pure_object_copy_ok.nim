import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Pure `object` types use value semantics.
# Copying an object creates a fully independent value — no move, no borrow.
# The borrow checker must NOT apply to pure object types.

type
  Point = object
    x, y: int

proc main() =
  var p = Point(x: 1, y: 2)
  var q = p        # copy — value semantics, p is NOT moved
  q.x = 99
  echo p.x         # OK: p is independent, still equals 1
  echo q.x         # OK: q is independent, equals 99
  var r = p        # another copy — still OK
  echo r.x

main()
