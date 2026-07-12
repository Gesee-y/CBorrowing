import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var n = p
  p = RefO()
  echo p.x

main()
