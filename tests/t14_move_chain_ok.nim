import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A sequential ownership transfer chain (a → b → c) is valid.
# Each step moves ownership forward. Only the final owner can use the value.
# Intermediate variables become Moved and must not be accessed.

type
  RefO = ref object
    x: int

proc main() =
  var a = RefO()
  var b = a         # a → b: a is Moved, b is Alive
  var c = b         # b → c: b is Moved, c is Alive
  echo c.x          # OK: c is the current owner
  # echo b.x        # would be Error: b was moved to c
  # echo a.x        # would be Error: a was moved to b

main()
