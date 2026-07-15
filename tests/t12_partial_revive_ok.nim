import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Field-level revive — after moving a specific field, assigning a new
# value to that exact field revives it. The revived field is accessible again,
# and sibling fields (never moved) remain unaffected throughout.
# This is more granular than trevive.nim which revives the whole variable.

type
  RefO = ref object
    x: int
  Pair = ref object
    left: RefO
    right: RefO

proc main() =
  var p = Pair(left: RefO(), right: RefO())
  var l = p.left          # move p.left — p.left is now Moved
  echo p.right.x          # OK: p.right was never moved
  p.left = RefO()         # revive p.left — p.left is Alive again
  echo p.left.x           # OK: p.left was revived
  echo p.right.x          # OK: p.right still alive

main()
