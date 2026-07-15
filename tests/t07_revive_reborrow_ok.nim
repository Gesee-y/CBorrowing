import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Full ownership lifecycle — move → revive → borrow → use → free.
# After a variable is revived (reassigned), it regains full Alive status
# and can be borrowed again as if it were freshly created.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var n = p            # p moved to n
  p = RefO()           # p revived with a new value (p is Alive again)
  let borrow = p       # borrow p — valid since p is alive
  echo borrow.x        # last use of borrow — borrow expires
  echo p.x             # OK: borrow has expired, p is free again

main()
