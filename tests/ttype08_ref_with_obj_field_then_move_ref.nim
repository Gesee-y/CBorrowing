import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Copy a copyable field OUT of a ref, then move the ref itself.
# The previously copied field value is fully independent — the ref move
# cannot invalidate an already-copied value type.

type
  Config = object
    width, height: int
  Window = ref object
    cfg: Config    # copyable
    title: string  # also copyable (string is value-semantics in nim)

proc main() =
  var win = Window(cfg: Config(width: 800, height: 600))

  var saved_cfg = win.cfg    # copy Config out (value type) — win stays Alive
  var moved_win = win        # NOW move the ref — win is Moved

  echo saved_cfg.width       # OK: saved_cfg is an independent copy, unaffected by move
  echo saved_cfg.height      # OK
  echo moved_win.cfg.width   # OK: moved_win owns the window
  echo win.cfg.width         # Error: win was moved to moved_win

main()
