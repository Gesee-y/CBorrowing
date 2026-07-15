import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Accessing a deeply nested field path after an intermediate path segment
# has been moved must be an error. If `o.mid` is moved, then `o.mid.inner.value`
# is inaccessible regardless of depth — the moved node poisons all sub-paths.

type
  Inner = ref object
    value: int
  Middle = ref object
    inner: Inner
    other: Inner
  Outer = ref object
    mid: Middle
    side: Inner

proc main() =
  var o = Outer(
    mid: Middle(inner: Inner(), other: Inner()),
    side: Inner()
  )
  var m = o.mid              # move o.mid
  echo o.side.value          # OK: o.side is a sibling of o.mid
  echo o.mid.inner.value     # Error: o.mid was moved; any sub-path of o.mid is invalid
  echo o.mid.other.value     # Error: same — o.mid.other is under the moved prefix

main()
