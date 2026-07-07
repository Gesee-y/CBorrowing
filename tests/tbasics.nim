import ../src/borrowing
import std/syncio

enableBorrowChecker()


type
  RefO = ref object
    x: int

proc main() =
  var x = RefO()
  x.x += 1

main()
