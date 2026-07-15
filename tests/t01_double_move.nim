import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Moving a variable that has already been moved is an error.
# The second move should detect that p is already in a Moved state.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var n = p      # OK: p moved into n
  var m = p      # Error: p is already Moved, cannot move again
  echo n.x

main()
