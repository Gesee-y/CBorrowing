import std/[tables, syncio, hashes]
import plugins
import graph

type
  RefKind = enum
    NotARef
    RefNilable
    RefNotNil
    UnknownT

  SymPath = object
    valid: bool
    path: seq[SymId]
    ty: seq[NimonyType]
    refKind: RefKind

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
  BCContext = object
    lifetimes: Table[SymId, Lifetime]
    varKinds: Table[SymId, VarKind]
    moveState: Table[SymPath, BorrowState]
    declTypes: Table[SymId, NifCursor]
    fieldTypes: Table[SymId, Table[SymId, NifCursor]]
    inlineVars: Table[SymId, NifCursor]
    errorStack: seq[ErrorInstance]

proc errorInstance(msg: string; at, orig: NifCursor): ErrorInstance =
  result = ErrorInstance()
  result.msg = msg
  result.at = at
  result.orig = orig

proc isRefType(t: NifCursor): bool =
  var n = t
  while n.typeKind in {SinkT, MutT, LentT, OutT}:
    inc n
  result = n.typeKind == RefT

proc refKindFromType(t: NifCursor): RefKind =
  var n = t
  while n.typeKind in {SinkT, MutT, LentT, OutT}:
    inc n

  if n.typeKind != RefT:
    return NotARef
  if n.kind == TagLit:
    var marker = firstChild(n)
    skip marker
    if marker.hasMore and marker.otherKind == NotnilU:
      return RefNotNil
  result = RefNilable

proc stripTypeWrappers(t: NifCursor): NifCursor =
  result = t
  while result.typeKind in {SinkT, MutT, LentT, OutT}:
    inc result

proc declaredTypeBody(n: NifCursor): NifCursor =
  result = n
  if result.kind == TagLit:
    inc result
    skip result # export marker
    skip result # pragmas
    skip result # typevars/body prefix

proc registerObjectFields(c: var BCContext; objSym: SymId; objBody: NifCursor) =
  if objBody.kind != TagLit:
    return

  var fields = initTable[SymId, NifCursor]()
  var fieldCursor = firstChild(objBody)
  skip fieldCursor # parent type / inheritance slot
  while fieldCursor.hasMore:
    if fieldCursor.kind == TagLit and fieldCursor.otherKind == FldU:
      var field = firstChild(fieldCursor)
      let fieldSym = field.symId
      skip field # export marker
      skip field # pragmas
      let fieldType = field
      fields[fieldSym] = fieldType
    skip fieldCursor
  c.fieldTypes[objSym] = fields

proc collectTypeDecls(root: NifCursor; ctx: var BCContext) =
  var n = root
  if n.kind != TagLit:
    return
  n.loopInto:
    case n.stmtKind
    of TypeS:
      let symNode = firstChild(n)
      if symNode.kind == SymbolDef:
        let sym = symNode.symId
        let body = declaredTypeBody(n)
        ctx.declTypes[sym] = body
        if body.kind == TagLit and body.typeKind == ObjectT:
          ctx.registerObjectFields(sym, body)
    of VarS, LetS:
      let symNode = firstChild(n)
      if symNode.kind == SymbolDef:
        var typ = symNode
        skip typ
        skip typ
        skip typ
        ctx.declTypes[symNode.symId] = typ
    else:
      discard
    collectTypeDecls(n, ctx)
    n.skip()

proc addPathSegment(res: var SymPath; n: NifCursor) =
  res.path.add n.symId
  res.ty.add n.typeKind

proc rootPath(sym: SymId): SymPath =
  result = SymPath(valid: true, path: @[sym], refKind: NotARef)

proc renderPath(path: SymPath): string =
  if path.path.len == 0:
    return "<path>"
  result = symText(path.path[0])
  for i in 1 .. path.path.high:
    result.add '.'
    result.add symText(path.path[i])

proc extractPath(c: var BCContext; n: NifCursor; res: var SymPath; followInlineVars = true) =
  if not res.valid:
    return
  case n.kind
  of TagLit:
    case n.exprKind
    of CallX, CmdX:
      res.valid = false
    of DotX, DdotX:
      var left = n
      inc left
      extractPath(c, left, res, followInlineVars)
      skip left
      if left.kind == Symbol:
        addPathSegment(res, left)
    of HderefX, HaddrX, AddrX, DerefX, TupatX, ArratX, AtX, PatX:
      var inner = n
      inc inner
      extractPath(c, inner, res, followInlineVars)
    of ConvX, HconvX, DconvX:
      var inner = n
      inc inner
      skip inner
      extractPath(c, inner, res, followInlineVars)
    of BaseobjX:
      var inner = n
      inc inner
      skip inner
      skip inner
      extractPath(c, inner, res, followInlineVars)
    of AconstrX, SetconstrX, TupconstrX, OconstrX, NilX, TrueX, FalseX:
      res.valid = false
    else:
      res.valid = false
  of Symbol:
    let s = n.symId
    if followInlineVars and s in c.inlineVars:
      extractPath(c, c.inlineVars.getOrQuit(s), res, followInlineVars)
    else:
      addPathSegment(res, n)
  of IntLit, UIntLit, CharLit, FloatLit, StrLit, DotToken:
    res.valid = false
  else:
    res.valid = false

proc extractPath(c: var BCContext; n: NifCursor; followInlineVars = true): SymPath =
  result = SymPath(valid: true, refKind: NotARef)
  extractPath(c, n, result, followInlineVars)
  if not result.valid or result.path.len == 0:
    result.valid = false

proc resolveDeclaredType(c: BCContext; typ: NifCursor; owner: var SymId): NifCursor =
  result = stripTypeWrappers(typ)
  var guard = 0
  while guard < 16:
    if result.kind == Symbol and result.symId in c.declTypes:
      owner = result.symId
      result = stripTypeWrappers(c.declTypes.getOrDefault(result.symId, result))
      inc guard
    else:
      break

proc resolvePathKind(c: BCContext; path: SymPath): RefKind =
  if path.path.len == 0:
    return UnknownT

  var owner = path.path[0]
  if owner notin c.declTypes:
    return UnknownT

  var typ = resolveDeclaredType(c, c.declTypes.getOrDefault(owner, default(NifCursor)), owner)
  if path.path.len == 1:
    return if typ.kind == TagLit and typ.typeKind == RefT: refKindFromType(typ) else: NotARef

  for i in 1 .. path.path.high:
    if typ.kind == TagLit and typ.typeKind == RefT:
      typ = stripTypeWrappers(firstChild(typ))
      owner = SymId(0)
      typ = resolveDeclaredType(c, typ, owner)
    elif typ.typeKind == PtrT:
      return NotARef

    if typ.kind != TagLit or typ.typeKind != ObjectT or owner == SymId(0):
      return NotARef

    let fields = c.fieldTypes.getOrDefault(owner, default(Table[SymId, NifCursor]))
    let fieldSym = path.path[i]
    if fieldSym notin fields:
      return UnknownT
    typ = resolveDeclaredType(c, fields.getOrDefault(fieldSym, default(NifCursor)), owner)

  if typ.kind == TagLit and typ.typeKind == RefT:
    result = refKindFromType(typ)
  else:
    result = NotARef

proc isPrefix(a, b: SymPath): bool =
  ## Check if `a` is a (non-empty) prefix of `b`.
  if a.path.len == 0 or b.path.len == 0 or a.path.len > b.path.len: return false
  for i in 0 ..< a.path.len:
    if a.path[i] != b.path[i]:
      return false
  result = true

proc pathsOverlap(a, b: SymPath): bool =
  ## Two paths overlap if one is a prefix of the other (or they are equal).
  ## Disjoint siblings (e.g. a.b vs a.c) do not overlap.
  if a.path.len == 0 or b.path.len == 0: return false
  let minLen = min(a.path.len, b.path.len)
  for i in 0 ..< minLen:
    if a.path[i] != b.path[i]:
      return false
  result = true

proc movePathsWithPrefix(ctx: var BCContext; prefix: SymPath, n: NifCursor) =
  ## When a path (or its root) is mutated, every fact about a longer path that
  ## shares this prefix (e.g. `a.next` when `a` is reassigned) is stale.
  for path, state in ctx.moveState.mpairs:
    if path != prefix and isPrefix(prefix, path):
      state.kind = Moved
      state.pos = n

proc relivePathsWithPrefix(ctx: var BCContext; prefix: SymPath, n: NifCursor) =
  ## When a path (or its root) is mutated, every fact about a longer path that
  ## shares this prefix (e.g. `a.next` when `a` is reassigned) is stale.
  for path, state in ctx.moveState.mpairs:
    if path != prefix and isPrefix(prefix, path):
      state.kind = Alive

proc isAnyMovedInPath(ctx: BCContext, path: SymPath): bool =
  for p, s in ctx.moveState:
    if isPrefix(p, path):
      if s.kind == Moved: return true

  return false

proc collectLifetimes(root: NifCursor; ctx: var BCContext) =
  var n = root
  if n.kind != TagLit:
    let path = ctx.extractPath(n)
    if path.valid and path.path.len > 0:
      ctx.moveState[path] = BorrowState(kind: Alive)
    if n.kind == Symbol:
      let sym = n.symId
      if sym in ctx.lifetimes:
        try:
          ctx.lifetimes[sym].last = n.info
        except:
          discard
    return

  n.loopInto:
    case n.stmtKind
    of VarS, LetS:
      let def = firstChild(n)
      var typ = def
      skip typ
      skip typ
      skip typ
      if def.kind == SymbolDef:
        let sym = def.symId
        let kind = if n.stmtKind == VarS: VarK else: LetK
        ctx.varKinds[sym] = kind
        ctx.lifetimes[sym] = Lifetime(creation: def.info, last: def.info)
    of NoStmt:
      let path = ctx.extractPath(n)
      if path.valid and path.path.len > 0:
        ctx.moveState[path] = BorrowState(kind: Alive)
      if n.kind == Symbol:
        let sym = n.symId
        if sym in ctx.lifetimes:
          try:
            ctx.lifetimes[sym].last = n.info
          except:
            discard
    else:
      discard
    collectLifetimes(n, ctx)
    n.skip()

proc checkPath(ctx: var BCContext, r: var Replacer, path: SymPath, isAssign=NoAsgn) =
  var n = r.getCursor()
  let info = n.info
  if path.valid and path.path.len > 0:
    let sym = path.path[0]
    if sym in ctx.lifetimes:
      var l = ctx.lifetimes.getOrDefault(sym)
      let vk = ctx.varKinds.getOrDefault(sym)
      if isAssign == LHSAsgn and l.creation != info:
        if vk == LetK:
          ctx.errorStack.add errorInstance("Can't modifiy an immutable let variable", n, n)
        else:
          # Fix TRevive
          # If it's an assignment and the LHS receive a new value but is not LetK
          # Then it revive it
          ctx.moveState[path] = BorrowState(kind: Alive)
          relivePathsWithPrefix ctx, path, n

    # Here we check is anything on the path to the variable is already moved
    # And prevent use after move
    let moved = ctx.moveState.getOrDefault(path, BorrowState())
    if isAnyMovedInPath(ctx, path):
      ctx.errorStack.add errorInstance("Used after move here", r.getCursor, moved.pos)
      return

    let kind = resolvePathKind(ctx, path)
    if kind != NotARef:
      echo "path ref kind: " & $kind

    if isAssign == RHSAsgn:
      ctx.moveState[path] = BorrowState(kind: Moved, pos: n)
      movePathsWithPrefix ctx, path, n

proc checkMoves(r: var Replacer; ctx: var BCContext, isAssign = NoAsgn) =
  if r.isAtom:
    let n = r.getCursor
    if n.kind == Symbol:
      let path = extractPath(ctx, n)
      checkPath(ctx, r, path, isAssign=isAssign)
    keep r, Any
  else:
    if r.kind == TagLit:
      case r.exprKind
      of HderefX, DotX, DdotX, HaddrX, AddrX, DerefX, TupatX, ArratX, AtX, PatX:
        var n = r.getCursor()
        let info = n.info
        let path = extractPath(ctx, r.getCursor)
        checkPath(ctx, r, path, isAssign=isAssign)
      else:
        discard
    case r.stmtKind
    of AsgnS:
      loopKeepTag r:
        checkMoves(r, ctx, isAssign = LHSAsgn)
        checkMoves(r, ctx, isAssign = RHSAsgn)
    of CommentS:
      var stmt = createTree()
      for err in ctx.errorStack:
        stmt.addTree errorTree(err.msg, err.at, err.orig)
      replace r, Any, stmt
    of VarS, LetS:
      var cnt = 0
      loopKeepTag r:
        checkMoves(r, ctx, isAssign = if cnt > 0: RHSAsgn else: NoAsgn)
        cnt += 1
    else:
      loopKeepTag r:
        checkMoves(r, ctx)

var ctx = BCContext()
var r = loadReplacer()
var scan = r.getCursor
collectTypeDecls(scan, ctx)
collectLifetimes(scan, ctx)
loopKeepTag r:
  checkMoves(r, ctx)
saveReplacer(r)
