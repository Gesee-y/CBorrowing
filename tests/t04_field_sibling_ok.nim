import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Moving one field of a struct must NOT affect independent sibling fields.
# Partial moves are tracked per-path. Moving `t.a` leaves `t.b` and `t.c` alive.

type
  RefO = ref object
    x: int
  Triple = ref object
    a: RefO
    b: RefO
    c: RefO

proc main() =
  var t = Triple(a: RefO(), b: RefO(), c: RefO())
  var movedA = t.a     # move t.a — only t.a is now Moved
  echo t.b.x           # OK: t.b is an independent path from t.a
  echo t.c.x           # OK: t.c is an independent path from t.a
  echo movedA.x        # OK: movedA owns the value

main()
