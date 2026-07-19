import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int
    y: nil RefO

proc main(p: var RefO) =
  p.y = p
  echo p.x

var p = RefO()
main(p)
