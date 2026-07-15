import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Conservative handling of conditional moves.
# If a variable is moved in only one branch of an if/else, the borrow checker
# must conservatively treat it as potentially moved after the conditional.
# We cannot know at compile time which branch executes, so p must be dead after.

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var cond = true

  if cond:
    var n = p       # p moved in the true branch only
  else:
    echo "no move"

  echo p.x          # Error (conservative): p may have been moved in the if-branch

main()
