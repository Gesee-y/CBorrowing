import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Borrowing a field then attempting to move the parent struct.
# A borrow on `c.item` logically locks `c` as well — you cannot move c
# while one of its fields is borrowed, because the borrow would become dangling.

type
  Inner = ref object
    x: int
  Container = ref object
    item: Inner
    other: Inner

proc main() =
  var c = Container(item: Inner(), other: Inner())
  let b = c.item           # immutable borrow of c.item
  var moved = c            # Error: c.item is borrowed by b (still alive), so c
                           #        cannot be moved as a whole
  echo b.x                 # last use of b — borrow expires here

main()
