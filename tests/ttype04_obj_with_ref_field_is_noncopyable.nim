import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: An `object` that contains a `ref` field becomes non-copyable.
# Copying it would silently alias the ref field, bypassing borrow tracking.
# Therefore the borrow checker must treat it like a ref — assignment is a MOVE.

type
  Inner = ref object
    x: int
  Wrapper = object    # pure object, BUT has a ref field → non-copyable
    item: Inner
    count: int        # primitive field (copyable on its own)

proc main() =
  var w = Wrapper(item: Inner(), count: 5)
  var moved = w         # should be a MOVE (Wrapper is non-copyable due to Inner)
  echo moved.item.x     # OK: moved owns the value
  echo w.item.x         # Error: w was moved to `moved`

main()
