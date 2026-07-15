import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: NLL (Non-Lexical Lifetimes) — a borrow's lifetime ends at its LAST USE,
# not at the end of its lexical scope. After the borrow's last use, the original
# variable is free again.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  let borrow = p       # borrow: immutable alias of p
  echo borrow.x        # last use of borrow — borrow lifetime ends HERE (NLL)
  # borrow is no longer alive past this point, so p is free
  var moved = p        # OK: borrow has expired, p can be moved now
  echo moved.x

main()
