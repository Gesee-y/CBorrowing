import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: When two borrows are simultaneously alive, the source cannot be used.
# The source is locked for as long as ANY of its aliases is still live.
# The source becomes free only after ALL borrows have expired (NLL).

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  let b1 = p          # first borrow of p
  let b2 = p          # second borrow of p — both b1 and b2 are alive below
  echo p.x            # Error: p is still borrowed by b1 and b2
  echo b1.x           # last use of b1 — b1 expires (but b2 still alive)
  echo b2.x           # last use of b2 — b2 expires

main()
