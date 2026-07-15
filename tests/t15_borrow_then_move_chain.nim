import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Borrowing a variable, then attempting a move chain through an intermediate.
# This chains t14 with aliasing: `a` is borrowed by `b`, then something attempts
# to move `a` into `c`. The borrow on `a` (via `b`) must block the move.

type
  RefO = ref object
    x: int

proc main() =
  var a = RefO()
  let b = a          # b borrows a (b is alive until its last use below)
  var c = a          # Error: cannot move a — b is still a live alias of a
  echo b.x           # last use of b — b expires here
  echo c.x

main()
