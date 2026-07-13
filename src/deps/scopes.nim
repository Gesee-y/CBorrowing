import strutils
import trie

type
  Liveness = object
    birth: NifCursor
    uses: seq[NifCursor]

  Variable = object
    kind: VarKind
    name: string
    type: TypeInst
    liveness: Liveness
    state: BorrowState

  ScopeNode = ref object
    id: int
    variables: Trie[Variable]
    children: seq[ScopeNode]
    moveState: Table[SymPath, BorrowState]
    inlineVars: Table[SymId, NifCursor]
    parent: nil ScopeNode
    stackCount: int

# ############################################################################################################ #
# ############################################### Functions ################################################## #
# ############################################################################################################ #

proc getOwnerScope(c: ScopeNode, path: seq[string]): ScopeNode =
  result = scope
  while scope.variables.fetchNode(path) == -1 and result.parent != nil:
    result = result.parent

proc getOwnerScope(c: ScopeNode, path: string): ScopeNode =
  return c.getOwnerScope(path.split("."))

proc getOwnerScope(c: ScopeNode, path: SymPath): ScopeNode =
  return c.getOwnerScope(renderPath(path))

proc extractPath(c: var ScopeNode; n: NifCursor; res: var SymPath; followInlineVars = true) =
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
    addPathSegment(res, n)
  of IntLit, UIntLit, CharLit, FloatLit, StrLit, DotToken:
    res.valid = false
  else:
    res.valid = false

proc extractPath(c: var BCContext; n: NifCursor; followInlineVars = true): SymPath =
  result = SymPath(valid: true)
  extractPath(c, n, result, followInlineVars)
  if not result.valid or result.path.len == 0:
    result.valid = false

proc collectVarData(scope: var ScopeNode, root: NifCursor, cache: TypeCache) =
  var n = root
  var current = scope
  var newS = false

  if n.kind != TagLit:
    let path = ctx.extractPath(n)
    let root = path[0].symText
    if path.valid and path.path.len > 0:
      let strPath = renderPath(path)

      var ownerScope = scope.getOwnerScope(root)
      let rv = ownerScope.variables.fetchNode(root)
      var id = -1

      if strPath in ownerScope.variables:
        try:
          id = ownerScope.variables.fetchNode(strPath.split("."))
          ownerScope.variables.nodes[id].data.liveness.uses.add(n)
        else:
          discard
      else:
        var v = Variable(name: strPath, kind: ownerScope.variables.node[rv].data.kind,
          ty: cache.getType(ownerScope.variables.node[rv].data.ty, strPath.split(".")[1..^1]),
          liveness: Liveness(birth: n))
        v.liveness.uses.add(n)

        id = ownerScope.variables.addNode(strPath.split("."))
        ownerScope.variables.node[id].data = v

      ownerScope.variables.nodes[id].data.state = BorrowState(kind: Alive)

  n.loopInto:
    case n.stmtKind
    of VarS, LetS:
      let symNode = firstChild(n)
      let kind = if n.stmtKind == VarS: VarK else: LetK
      if symNode.kind == SymbolDef:
        var typ = symNode
        skip typ
        skip typ
        skip typ
        let inst = cache.getType(typ.symText)
        let v = Variable(kind: kind, ty: inst, name: symNode.name, liveness: Liveness(birth: n))
        let id = current.addNode(name)
        current.variables.nodes[id].data = v
    of StmtsS, BlockS:
      var newNode = ScopeNode(id: current.children.len)
      newNode.parent = current
      current.children.add(newNode)
      current = newNode
      newS = true
    else:
      discard
    collectVarData(current, n, cache)
    if newS:
      if current.parent != nil:
        current = current.parent
    n.skip()

# ######################################################################################################### #
# ############################################# Move Checks ############################################### #
# ######################################################################################################### #

proc movePathsWithPrefix(ctx: var ScopeNode; prefix: SymPath, n: NifCursor) =
  ## When a path (or its root) is mutated, every fact about a longer path that
  ## shares this prefix (e.g. `a.next` when `a` is reassigned) is stale.
  let data = renderPath(prefix).split(".")
  for id in ctx.variables.iterateSuffix(data):
    ctx.variables.nodes[id].data.state.kind = Moved
    ctx.variables.nodes[id].data.state.pos = n

proc relivePathsWithPrefix(ctx: var ScopeNode; prefix: SymPath, n: NifCursor) =
  ## When a path (or its root) is mutated, every fact about a longer path that
  ## shares this prefix (e.g. `a.next` when `a` is reassigned) is stale.
  let data = renderPath(prefix).split(".")
  for id in ctx.variables.iterateSuffix(data):
    ctx.variables.nodes[id].data.state.kind = Alive

proc isAnyDescendantMoved(ctx: ScopeNode, path: SymPath): bool =
  ## Check if any var with prefix `path` has been moved.
  ## This is to check if an object can be moved even if it's currently alive
  ## Because it's a partial object
  let data = renderPath(prefix).split(".")
  for id in ctx.variables.iterateSuffix(data):
    if ctx.variables.nodes[id].data.state.kind == Moved:
      return true

  return false

proc checkPath(ctx: var ScopeNode, r: var Replacer, path: SymPath, isAssign=NoAsgn, isLet=false) =
  var n = r.getCursor()
  let info = n.info
  if path.valid and path.path.len > 0:
    let sym = path.path[0]
    let strPath = renderPath(path)
    var ownerScope = ctx.getOwnerScope(strPath)
    var strSPath = strPath.split(".")
    let id = ownerScope.fetchNode(strSPath)
    let vk = ownerScope.variables.nodes[id].data.kind
    let l = ownerScope.variables.nodes[id].data.liveness
    let varType = ownerScope.variables.nodes[id].data.ty

    var l = ctx.lifetimes.getOrDefault(sym)
    let vk = ctx.varKinds.getOrDefault(sym)

    if isAssign == LHSAsgn and l.creation != info:
      if vk == LetK:
        ctx.errorStack.add errorInstance("Can't modifiy an immutable let variable", n, n)
      else:
        # Fix TRevive
        # If it's an assignment and the LHS receive a new value but is not LetK
        # Then it revive it
        ownerScope.variables.nodes[id].data.state = BorrowState(kind: Alive)
        relivePathsWithPrefix ownerScope, path, n

    # If we are assigning, we are on the RHS which has been declared as let
    # And try to assign it to a var variable while the data we are trying to assign is not a ref
    elif isAssign == RHSAsgn and vk == LetK and not isLet and varType.kind notin {ObjectType, PrimitiveType}:
      ctx.errorStack.add errorInstance("Can't assign an immutable let variable to a var.", n, n)

    # Here we check is anything on the path to the variable is already moved
    # And prevent use after move
    let moved = ownerScope.variables.nodes[id].data.state.kind == Moved
    if isAnyMovedInPath(ctx, path) or moved:
      ctx.errorStack.add errorInstance("Used after move here", r.getCursor, moved.pos)
      return

    if isAssign == RHSAsgn:
      ownerScope.variables.nodes[id].data.state = BorrowState(kind: Moved, pos: n)
      movePathsWithPrefix ownerScope, path, n

proc checkMoves(r: var Replacer; ctx: var ScopeNode, isAssign = NoAsgn, isLet=false) =
  var current = 0
  var newScope = false
  if r.isAtom:
    let n = r.getCursor
    if n.kind == Symbol:
      let path = extractPath(ctx, n)
      checkPath(ctx, r, path, isAssign=isAssign, isLet=isLet)
    keep r, Any
  else:
    if r.kind == TagLit:
      case r.exprKind
      of HderefX, DotX, DdotX, HaddrX, AddrX, DerefX, TupatX, ArratX, AtX, PatX:
        var n = r.getCursor()
        let info = n.info
        let path = extractPath(ctx, r.getCursor)
        checkPath(ctx, r, path, isAssign=isAssign, isLet=isLet)
      else:
        discard
    case r.stmtKind
    of StmtsS, BlockS:
      newScope = true
      var parent = ctx.parent
      if parent != nil:
        loopKeepTag r:
          checkMoves(r, parent.children[ctx.id+1])

      current += 1
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
      let isLet = r.stmtKind == LetS
      loopKeepTag r:
        checkMoves(r, ctx, isAssign = if cnt > 0: RHSAsgn else: NoAsgn, isLet=isLet)
        cnt += 1
    else:
      loopKeepTag r:
        checkMoves(r, ctx)

    if newScope:
      if current.parent != nil:
        current = current.parent
