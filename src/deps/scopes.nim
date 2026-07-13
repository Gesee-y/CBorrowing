

type
  Liveness = object
    birth: NifCursor
    uses: seq[NifCursor]

  Variable = object
    kind: VarKind
    name: string
    type: TypeInst
    liveness: Liveness

  ScopeNode = ref object
    variables: Table[string, Variable]
    children: seq[ScopeNode]
    moveState: Table[SymPath, BorrowState]
    inlineVars: Table[SymId, NifCursor]
    parent: nil ScopeNode
    stackCount: int

# ############################################################################################################ #
# ############################################### Functions ################################################## #
# ############################################################################################################ #

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

      var ownerScope = scope
      while root notin scope.moveState and ownerScope.parent != nil:
        ownerScope = ownerScope.parent

      ownerScope.moveState[path] = BorrowState(kind: Alive)
      let rv = ownerScope.variables.getOrDefault(root)

      if strPath in ownerScope.variables:
        try:
          ownerScope.variables[strPath].liveness.uses.add(n)
        else:
          discard
      else:
        var v = Variable(name: strPath, kind: rv.kind, ty: cache.getType(rv.ty, strPath.split(".")[1..^1]),
          liveness: Liveness(birth: n))
        v.liveness.uses.add(n)
        ownerScope.variables[strPath] = v


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
        scope.declTypes[symNode.symId] = typ
    of StmtsS, BlockS:
      var newNode = ScopeNode()
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
