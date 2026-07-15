import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: In the same procedure, object types copy freely while ref types move.
# This establishes the fundamental split in semantics between the two kinds.

type
  Val = object
    n: int
  Ref = ref object
    n: int

proc main() =
  var v = Val(n: 10)
  var r = Ref(n: 20)

  var cv = v      # copy of v — v remains Alive (value semantics)
  var mr = r      # move of r — r is now Moved (ref semantics)

  echo v.n        # OK: v was copied, still valid
  echo cv.n       # OK: independent copy
  echo mr.n       # OK: mr is the owner of what was r
  echo r.n        # Error: r was moved to mr

main()
