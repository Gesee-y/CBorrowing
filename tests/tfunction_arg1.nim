import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main(p: RefO) =
  var n = p
  echo p.x

var p = RefO()
main(p)
