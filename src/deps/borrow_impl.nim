import std/tables, std/syncio
import plugins

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
    moveState: Table[SymId, BorrowState]
    errorStack: seq[ErrorInstance]

proc errorInstance(msg: string, at, orig: NifCursor): ErrorInstance =
  result = ErrorInstance()
  result.msg = msg
  result.at = at
  result.orig = orig

proc collectLifetimes(root: NifCursor; ctx: var BCContext) =
  var n = root
  if n.kind != TagLit:
    if n.kind == Symbol:
      if n.kind == Symbol:
        let sym = n.symId
        if sym in ctx.lifetimes:
          try:
            ctx.lifetimes[sym].last = n.info  # update last usage
          except:
            discard
    return
  n.loopInto:
    case n.stmtKind
    of VarS, LetS:
      # structure : (var/let <symdef> <type> <value>)
      let def = firstChild(n)
      var typ = def
      skip typ
      skip typ
      skip typ
      if def.kind == SymbolDef and typ.typeKind == RefT:
        let sym = def.symId
        let kind = if n.stmtKind in {VarS}: VarK else: LetK
        ctx.moveState[sym] = BorrowState(kind:Alive)
        ctx.varKinds[sym] = kind
        ctx.lifetimes[sym] = Lifetime(creation: def.info, last: def.info)
    of NoStmt:
      # token feuille — check si c'est un usage de symbole
      if n.kind == Symbol:
        let sym = n.symId
        if sym in ctx.lifetimes:
          try:
            ctx.lifetimes[sym].last = n.info  # update last usage
          except:
            discard
    else:
      discard
    # toujours descendre récursivement
    collectLifetimes(n, ctx)
    n.skip()

proc checkMoves(r: var Replacer; ctx: var BCContext, isAssign=NoAsgn) =
  echo r.getCursor.kind
  if r.isAtom:
    # usage d'un symbole — vérifier use-after-move
    let n = r.getCursor
    if n.kind == Symbol:
      let sym = n.symId
      let info = n.info
      if sym in ctx.lifetimes:
        var l = ctx.lifetimes.getOrDefault(sym)
        let vk = ctx.varKinds.getOrDefault(sym)
        if isAssign == LHSAsgn and l.creation != info:
          if vk == LetK:
            ctx.errorStack.add errorInstance("Can't modifiy an immutable let variable", n, n)
          else:
            ctx.moveState[sym] = BorrowState(kind:Alive)

        if l.creation != info and vk == VarK:
          let b = ctx.moveState.getOrDefault(sym, BorrowState())
          if b.kind == Moved:
            var bnode = b.pos
            var rnode = r.getCursor
            ctx.errorStack.add errorInstance("Used after move here", rnode, bnode)

          if isAssign == RHSAsgn:
            ctx.moveState[sym] = BorrowState(kind:Moved, pos: r.getCursor)
    keep r, Any
  else:
    echo r.stmtKind
    case r.stmtKind
    of AsgnS:
      loopKeepTag r:
        checkMoves(r, ctx, isAssign=LHSAsgn)
        checkMoves(r, ctx, isAssign=RHSAsgn)
    of CommentS:
      var stmt = createTree()
      for err in ctx.errorStack:
        stmt.addTree errorTree(err.msg, err.at, err.orig)

      replace r, Any, stmt
    of VarS, LetS:
      echo renderNode r.getCursor
      var cnt = 0
      loopKeepTag r:
        checkMoves(r, ctx, isAssign = if cnt > 0: RHSAsgn else: NoAsgn)
        cnt += 1
    else:
      loopKeepTag r:
        checkMoves(r, ctx)

var ctx = BCContext()
# Passe 1
var r = loadReplacer()
var scan = r.getCursor  # ou loadReplacer + getCursor                   # non-destructif
collectLifetimes(scan, ctx)
for (k,v) in ctx.varKinds.pairs:
  echo $k.uint32 & " is " & $v
loopKeepTag r:
  checkMoves(r, ctx)
saveReplacer(r)
