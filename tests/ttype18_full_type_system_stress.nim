import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: Full type-system stress test combining all previous rules simultaneously.
# One procedure exercises: pure objects (copy), refs (move), objects with ref fields
# (non-copyable/move), copyable fields within non-copyable parents (copy),
# NLL borrow expiry, partial moves, revives, and independent sibling paths.

type
  Vec2 = object              # pure object — always copyable
    x, y: float
  Color = object             # pure object — always copyable
    r, g, b: uint8
  Texture = ref object       # ref — non-copyable, move-checked
    id: int
    size: Vec2               # copyable field inside ref
  Material = object          # non-copyable: has a Texture ref field
    color: Color             # copyable sub-object
    tex: Texture             # ref field → Material is non-copyable
    opacity: float           # primitive — copyable
  Mesh = ref object          # ref — non-copyable
    mat: Material            # non-copyable object field
    vcount: int              # primitive — copyable

proc main() =
  var mesh = Mesh(
    mat: Material(
      color: Color(r: 255, g: 128, b: 0),
      tex:   Texture(id: 7, size: Vec2(x: 512.0, y: 512.0)),
      opacity: 0.9
    ),
    vcount: 3000
  )

  # --- Copyable extractions (no move, mesh stays Alive) ---
  var vc   = mesh.vcount            # copy int
  var col  = mesh.mat.color         # copy Color (pure object)
  var op   = mesh.mat.opacity       # copy float
  var tsz  = mesh.mat.tex.size      # copy Vec2 from inside the ref (size is an object field)

  echo vc                           # OK
  echo col.r                        # OK: independent Color copy
  echo op                           # OK
  echo tsz.x                        # OK: independent Vec2 copy

  # --- Non-copyable borrow (NLL) ---
  let tex_borrow = mesh.mat.tex     # borrow the Texture ref (alias, not a move)
  echo tex_borrow.id                # last use of tex_borrow — borrow expires HERE

  # --- After NLL expiry: move the ref field ---
  var tex = mesh.mat.tex            # OK: tex_borrow expired, move Texture ref
  echo tex.id                       # OK: tex owns the Texture

  # --- Sibling fields still accessible ---
  echo mesh.mat.color.r             # OK: Color field unaffected by tex move
  echo mesh.mat.opacity             # OK: float field unaffected
  echo mesh.vcount                  # OK: top-level primitive, unaffected

  # --- Revive the moved field ---
  mesh.mat.tex = Texture(id: 99, size: Vec2(x: 1024.0, y: 1024.0))
  echo mesh.mat.tex.id              # OK: tex was revived

  # --- Error case: access the original path after move (before revive) ---
  # (Conceptually: if we had accessed mesh.mat.tex.id between the move and the revive,
  #  that would be the Error. Demonstrate it by moving tex a second time.)
  var tex2 = mesh.mat.tex           # move the revived Texture again
  echo mesh.mat.tex.id              # Error: mesh.mat.tex was moved again (to tex2)

main()
