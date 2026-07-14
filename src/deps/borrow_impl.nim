import std/[tables, syncio, hashes]
import plugins

type
  SymPath = object
    valid: bool
    path: seq[SymId]
    ty: seq[NimonyType]

const PATH_SEPARATOR = "::"

func hash(s: SymPath): Hash =
  var h: Hash = 0
  for item in s.path:
    h = h !& hash(item)
  h = h !& hash(s.valid)
  result = !$h

func `==`(s1, s2: SymPath): bool =
  if s1.valid != s2.valid:
    return false
  if s1.path.len != s2.path.len:
    return false
  for i in 0 .. s1.path.high:
    if s1.path[i] != s2.path[i]:
      return false
  true

proc renderPath(path: SymPath): string =
  if path.path.len == 0:
    return "<path>"
  result = symText(path.path[0])
  for i in 1 .. path.path.high:
    result.add PATH_SEPARATOR
    result.add symText(path.path[i])

type
  VarKind = enum VarK, LetK
  MoveState = enum Alive, Moved
  AsgnState = enum NoAsgn, LHSAsgn, RHSAsgn

  Lifetime = object
    creation: LineInfo
    last: LineInfo
  BorrowState = object
    kind: MoveState
    pos: NifCursor
  ErrorInstance = object
    msg: string
    at, orig: NifCursor

proc errorInstance(msg: string; at, orig: NifCursor): ErrorInstance =
  result = ErrorInstance()
  result.msg = msg
  result.at = at
  result.orig = orig

include "types.nim"
include "scopes.nim"

var ctx = BCContext(scopes: @[ScopeNode(parent: -1, id: 0, variables: newTrie())])
var r = loadReplacer()
var scanTy = r.getCursor
var scanVar = r.getCursor
collectTypeDecls(ctx.cache, scanTy)
collectVarData(ctx, 0, scanVar)

for k,v in ctx.cache.nameToId:
  echo "Type " & k & " maps to " & $v
  let inst = ctx.cache.instances[v]

  echo "kind = ", inst.kind
  echo "associated = ", inst.associated
  echo "fields: "
  for f in inst.fields:
    echo "  ", f.name, ": ", f.ty

#loopKeepTag r:
#  checkMoves(r, ctx.scope)
loopKeepTag r:
  keep r, Any

saveReplacer(r)
