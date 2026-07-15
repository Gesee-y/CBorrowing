import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Moving a variable inside a loop body.
# On the first iteration, p is moved into n. On subsequent iterations,
# p is already in a Moved state, so attempting to move it again is an error.
# The variable lifetime cannot be extended to "per-iteration" — p is a
# single variable declared outside the loop.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  for i in 0..2:
    var n = p        # First iteration: OK (move). Subsequent: Error (already Moved).
    echo n.x

main()
