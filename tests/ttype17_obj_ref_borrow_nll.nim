import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: NLL applied to a non-copyable object type.
# The borrow checker must correctly compute the last-use point for a `let`
# alias of a non-copyable object and free the source after that point.
# This mirrors t05_borrow_nll_ok but for an object-with-ref type.

type
  Handle = ref object
    fd: int
  Task = object          # non-copyable: has a ref field
    handle: Handle
    priority: int

proc main() =
  var task = Task(handle: Handle(fd: 5), priority: 1)

  let view = task          # alias of task (Task is non-copyable → no copy)
  echo view.handle.fd      # last use of view — view expires HERE (NLL)
  echo view.priority       # wait, this is AFTER the above — actually this IS the last use

  # After view's last use, task is free again
  var moved = task         # OK: view has expired (NLL), task can be moved now
  echo moved.handle.fd     # OK: moved owns the task

main()
