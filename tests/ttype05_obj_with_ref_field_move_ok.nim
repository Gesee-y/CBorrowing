import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Correct ownership transfer for a non-copyable object (object with ref field).
# Moving it is fine — the owner variable is used after, the source is not.
# Mirrors tbasic but for a non-copyable object rather than a raw ref.

type
  Inner = ref object
    x: int
  Wrapper = object
    item: Inner
    id: int

proc main() =
  var w = Wrapper(item: Inner(), id: 1)
  var owner = w          # move: w → owner (Wrapper is non-copyable)
  echo owner.item.x      # OK: owner holds the ref
  echo owner.id          # OK: primitive field, accessible through owner
  # w is Moved — any access to w here would be an error

main()
