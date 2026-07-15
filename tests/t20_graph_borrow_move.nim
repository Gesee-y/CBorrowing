import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Full integration — graph-like structure with nodes and edges,
# mixing borrows, partial moves, revives, and ownership transfers.
# Each operation builds on the previous, forming a complete real-world-like scenario.
# Tests: field borrow → parent move blocked → borrow expires → field move OK →
#        revive → reborrow → use chain.

type
  Node = ref object
    value: int
  Edge = ref object
    src: Node
    dst: Node
  Graph = ref object
    e1: Edge
    e2: Edge

proc main() =
  var g = Graph(
    e1: Edge(src: Node(), dst: Node()),
    e2: Edge(src: Node(), dst: Node())
  )

  # --- Phase 1: borrow g.e1.src, then move g.e2 (they are independent) ---
  let srcBorrow = g.e1.src     # borrow g.e1.src
  var e2 = g.e2                # OK: g.e2 is independent of g.e1
  echo srcBorrow.value         # last use of srcBorrow — borrow expires (NLL)

  # --- Phase 2: srcBorrow has expired, g.e1 is free to move ---
  var e1 = g.e1                # OK: srcBorrow expired, move g.e1
  g.e1 = Edge(src: Node(), dst: Node()) # revive g.e1

  # --- Phase 3: all variables in clean state, use freely ---
  echo g.e1.src.value          # OK: g.e1 was revived
  echo g.e1.dst.value          # OK: g.e1.dst never moved
  echo e1.src.value            # OK: e1 owns what was g.e1
  echo e2.dst.value            # OK: e2 owns what was g.e2
  echo g.e2.src.value          # Error: g.e2 was moved to e2 and not revived

main()
