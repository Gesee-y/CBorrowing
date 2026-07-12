import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  let p = RefO()
  var n = p
  n.x = 1
  echo n.x

main()
