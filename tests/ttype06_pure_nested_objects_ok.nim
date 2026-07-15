import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Deeply nested pure object types remain fully copyable at every level.
# No matter how many layers of `object` are nested, if NO ref appears anywhere
# in the chain, all copies are free and borrow checking never triggers.

type
  Vec2 = object
    x, y: float
  AABB = object
    min: Vec2
    max: Vec2
  Transform = object
    pos: Vec2
    bounds: AABB

proc main() =
  var t = Transform(
    pos: Vec2(x: 1.0, y: 2.0),
    bounds: AABB(min: Vec2(x: 0.0, y: 0.0), max: Vec2(x: 10.0, y: 10.0))
  )

  var copy1 = t           # copy — all fields are value types
  var copy2 = t           # another copy — still OK
  var copy3 = copy1       # copy of copy — still OK

  echo t.pos.x            # OK: t is still alive
  echo copy1.bounds.min.x # OK
  echo copy2.pos.y        # OK
  echo copy3.bounds.max.x # OK

main()
