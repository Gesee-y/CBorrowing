import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  let n = p
  echo p.x
  echo n.x

main()
