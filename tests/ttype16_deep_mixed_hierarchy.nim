import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A complex four-level hierarchy mixing ref and object at alternating levels.
# Level 1: ref (non-copyable, move-checked)
# Level 2: object with mixed fields (some copyable, some not)
# Level 3: ref (non-copyable) and object (copyable)
# Level 4: primitives (always copyable)
# Tests that the correct semantics propagate through every level of the chain.

type
  Stats = object          # pure object — copyable at this level
    hits: int
    misses: int
  Cache = ref object      # ref — non-copyable
    size: int
  Slot = object           # object with mixed fields — non-copyable overall
    stats: Stats          # copyable sub-object
    cache: Cache          # non-copyable ref field → makes Slot non-copyable
    index: int            # primitive — copyable
  Store = ref object      # outer ref — non-copyable
    primary: Slot         # non-copyable object field
    tag: int              # primitive — copyable

proc main() =
  var s = Store(
    primary: Slot(
      stats: Stats(hits: 10, misses: 2),
      cache: Cache(size: 256),
      index: 0
    ),
    tag: 99
  )

  # Level 1→2: copy the primitive field of the ref
  var t = s.tag                      # copy int — s stays Alive
  echo t                             # OK

  # Level 1→2→3: copy a copyable sub-object field
  var st = s.primary.stats           # copy Stats (pure object) — s stays Alive
  echo st.hits                       # OK: independent copy

  # Level 1→2→3: copy a primitive field deep in the chain
  var idx = s.primary.index          # copy int — no move anywhere
  echo idx                           # OK

  # Level 1→2→3: move a ref field inside the non-copyable object
  var cache = s.primary.cache        # MOVE Cache ref — s.primary.cache is now Moved

  echo cache.size                    # OK: cache owns the Cache
  echo s.primary.stats.hits          # OK: stats is copyable, unaffected by cache move
  echo s.primary.index               # OK: primitive, unaffected
  echo s.tag                         # OK: top-level primitive, unaffected
  echo s.primary.cache.size          # Error: s.primary.cache was moved to `cache`

main()
