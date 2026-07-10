import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  var x = RefO()
  var y = x
  y = x
  let z = y
  echo x.x

main()
