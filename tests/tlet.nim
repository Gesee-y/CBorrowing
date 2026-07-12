import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  let p = RefO()
  p.x = 1
  echo p.x

main()
