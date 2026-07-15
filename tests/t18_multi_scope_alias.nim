import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: An alias (let) created in an outer scope keeps the source locked even
# when code inside a nested block tries to move the source.
# The borrow's lifetime (NLL) extends to the outer scope, outliving the inner block.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  let outer_borrow = p    # borrow created in outer scope
  block inner:
    var n = p             # Error: p is borrowed by outer_borrow which is still alive
                          # (outer_borrow's last use is AFTER this block)
  echo outer_borrow.x     # last use of outer_borrow — borrow expires here

main()
