import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A move performed inside an inner block persists after the block ends.
# Move state is not scoped — the variable stays Moved in the outer scope
# because the block's lifetime is contained, not the move's effect.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  block inner:
    var n = p     # p is moved inside the inner block
    echo n.x      # valid use through n while inside the block
  echo p.x        # Error: p was moved inside the block and was never revived

main()
