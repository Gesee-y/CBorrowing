import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Primitive types (int, float, bool, char) are always Copyable.
# They must never trigger borrow-check errors regardless of how many times
# they are assigned or read.

proc main() =
  var a: int = 42
  var b: float = 3.14
  var c: bool = true
  var d: char = 'z'

  var a2 = a       # copy
  var a3 = a       # another copy
  var b2 = b
  var c2 = c
  var d2 = d

  echo a            # OK: still valid after multiple copies
  echo a2
  echo a3
  echo b2
  echo c2
  echo d2

  let la = a        # let-binding of a primitive — borrow checker should
  echo a            # NOT treat this as a lock on `a`, primitives are copyable
  echo la

main()
