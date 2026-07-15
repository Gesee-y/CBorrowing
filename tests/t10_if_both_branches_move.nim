import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Definite move through all branches of a conditional.
# When every branch moves the variable, the move is unconditional and the
# variable is definitely dead after the if/else, regardless of path taken.
# This is stronger than t09: here the move is certain, not just possible.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var cond = true

  if cond:
    var n = p       # p moved in true branch
  else:
    var m = p       # p also moved in false branch

  echo p.x          # Error: p is definitely moved — all branches moved it

main()
