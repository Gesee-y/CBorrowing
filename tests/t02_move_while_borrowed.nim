import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Moving a variable while an immutable borrow (let) is still alive.
# A let-binding creates an alias. Moving the source while the alias is live
# is illegal — the borrow must expire first.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  let borrowed = p    # borrowed is a live immutable alias of p
  var moved = p       # Error: cannot move p, 'borrowed' alias is still alive
  echo borrowed.x     # last use of borrowed (alias expires here)

main()
