import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: The `copyable` annotation explicitly overrides the default non-copyable
# inference for objects with ref fields. When a type is annotated {.copyable.},
# assignment must be treated as a copy even if the type contains ref fields.
# The borrow checker must respect this opt-in annotation.

type
  Inner = ref object
    x: int
  SharedConfig = object   # has a ref field, BUT explicitly marked copyable
    handle: Inner
    version: int

proc main() =
  copyable(SharedConfig)     # explicit opt-in: SharedConfig is copyable

  var cfg = SharedConfig(handle: Inner(), version: 1)
  var copy1 = cfg            # copy (not move): copyable annotation takes effect
  var copy2 = cfg            # another copy — still OK

  echo cfg.version           # OK: cfg is still Alive (was copied, not moved)
  echo copy1.version         # OK
  echo copy2.handle.x        # OK: all three share the same Inner (intentional aliasing)
  echo cfg.handle.x          # OK: cfg was copied, copyable annotation preserves this

main()
