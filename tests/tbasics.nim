import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int
  Pair = ref object
    left: RefO
    right: RefO

proc main() =
  var p = Pair(left: RefO(), right: RefO())
  var left = p.left
  echo p.right.x
  echo left.x
  echo p.left.x
  echo 1

main()
