import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A non-copyable object (object with ref field) subject to borrow rules.
# A `let` binding on it creates an alias. Moving the source while the alias
# is alive must be an error — same rule as for ref types.

type
  Inner = ref object
    x: int
  Box = object       # non-copyable: has a ref field
    item: Inner
    label: int

proc main() =
  var b = Box(item: Inner(), label: 1)
  let borrowed = b      # borrowed is an alias of b (Box is non-copyable → no copy)
  var moved = b         # Error: b is borrowed by `borrowed` which is still alive
  echo borrowed.item.x  # last use of borrowed — borrow expires
  echo borrowed.label

main()
