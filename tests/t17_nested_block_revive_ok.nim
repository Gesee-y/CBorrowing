import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A variable moved inside an inner block, then revived in the same block,
# is alive again in the outer scope after the block exits.
# Revive (reassignment) within a block must propagate the Alive state outward.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  block:
    var n = p          # p moved inside block
    p = RefO()         # p revived inside the same block
  echo p.x             # OK: p was revived before the block ended

main()
