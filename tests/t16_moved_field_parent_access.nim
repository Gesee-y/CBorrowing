import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Accessing the parent variable as a whole after one of its fields was moved.
# Moving `p.left` makes `p` a partial/incomplete object. Reading or moving `p` as
# a whole should be an error, since it would include the already-moved `p.left`.

type
  RefO = ref object
    x: int
  Pair = ref object
    left: RefO
    right: RefO

proc main() =
  var p = Pair(left: RefO(), right: RefO())
  var l = p.left           # move p.left — p is now partial
  var whole = p            # Error: p is a partial object (p.left was moved out)
  echo l.x

main()
