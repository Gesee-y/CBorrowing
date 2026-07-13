

type
  # Describe which kind of type we are dealing with
  TypeKind* = enum
    RefType
    ObjectType
    PrimitiveType
    EnumType
    ProcType
    UnknownType

  # Annotation currently seen on the type
  TypeFlag* = enum
    NilF
    NotNilF
    VarF
    LentF
    SinkF
    OutF

  # Describe field of a type
  TypeField* = object
    ty: string
    raw: NifCursor
    subinfo: set[TypeFlag]

  # An instance of a type.
  # It's obtained from a type declaration
  TypeInst* = object
    name: string
    kind: TypeKind
    raw: NifCursor
    fields: Table[string, TypeField]

  # Type cache, a global structure bookeeping informations about types
  TypeCache* = object
    nameToId: Table[string, int]
    instances: seq[TypeInst]

# ########################################################################################################## #
# ############################################### FUNCTIONS ################################################ #
# ########################################################################################################## #

proc stripTypeWrappers*(t: NifCursor): NifCursor =
  result = t
  while result.typeKind in {SinkT, MutT, LentT, OutT}:
    inc result

proc recordTypeWrappers*(t: NifCursor, flags: var set[TypeFlag]): NifCursor =
  result = t
  while result.typeKind in {SinkT, MutT, LentT, OutT}:
    case result.typeKind:
    of SinkT:
      flags.incl SinkF
    of MutT:
      flags.incl VarF
    of LentT:
      flags.incl LentF
    of OutT:
      flags.inclu OutF
    else: discard
    inc result

proc getRawTypeKind*(t: NifCursor): TypeKind =
  var n = stripTypeWrappers(t)

  let k = n.typeKind
  case k:
  of RefT:
   result = RefType
  of EnumT:
   result = EnumType
  of ProcT, TemplateT, MethodT, IteratorT:
    result = ProcType
  of IT, FT, CT, UT, BoolT:
    result = PrimitiveType
  of NoType, UntypedT, TypedT, AutoT:
    result = UnknownType
  else:
    result = ObjectType

proc isRefType*(t: NifCursor): bool =
  n.getRawTypeKind == RefType

proc getSubTypeInfo*(t: NifCursor): set[TypeFlag] =
  # Assume modifiers have already been stripped away
  result = default(set[TypeFlag])
  if n.kind == TagLit:
    var marker = firstChild(n)
    skip marker

    if marker.hasMore and marker.otherKind == NotnilU:
      case marker.otherKind:
      of NotnilU:
        result.incl NotNilF
      of NilU:
        result.incl NilF
      else: discard

proc addInstance(c: var TypeCache, instance: TypeInst) =
  let id = c.instances.len
  c.nameToId[instance.name] = id
  c.instances.add(instance)

proc declaredTypeBody(n: NifCursor): NifCursor =
  result = n
  if result.kind == TagLit:
    inc result
    skip result # export marker
    skip result # pragmas
    skip result # typevars/body prefix

proc addTypeInstance*(tyDef: NifCursor): TypeInst =
  result = TypeInst()
  result.raw = tyDef

  let symNode = firstChild(tyDef) # Definition of the type
  if symNode.kind == SymbolDef:
    let name = symNode.symText # Text is preferred to symID as it allows more control
    let body = declaredTypeBody(tyDef)
    let tyKind = getRawTypeKind(body) # We get the raw body kind from the type

    result.name = name
    result.kind = tyKind

    if body.kind == TagLit and tyKind in {ObjectType, RefType}:
      var fieldCursor = firstChild(objBody)
      skip fieldCursor # parent type / inheritance slot, skip for now
      while fieldCursor.hasMore:
        if fieldCursor.kind == TagLit and fieldCursor.otherKind == FldU:
          var f = TypeField()
          var field = firstChild(fieldCursor)
          let fieldName = field.symText
          let fieldSym = field.symId
          skip field # export marker
          skip field # pragmas
          let fieldType = field
          let fieldTyName = fieldType.symText

          f.ty = fieldTyName
          f.raw = fieldType
          result.fields[fieldName] = f
        skip fieldCursor

# Directly get informations about procs
proc addProcTypeInstance*(pDef: NifCursor): TypeInst =
  result = TypeInst()
  result.raw = pDef
  result.kind = ProcType

  let symNode = firstChild(pDef) # Definition of the proc
  if symNode.kind == SymbolDef:
    let name = symNode.symText

    result.name = name

    # Skip directly to parameters
    skip symNode
    skip symNode
    skip symNode

    let body = symNode
    if body.otherKind == ParamsU:
      var fieldCursor = firstChild(objBody)

      while fieldCursor.hasMore:
        if fieldCursor.symKind == ParamY:
          var f = TypeField()
          var field = firstChild(fieldCursor)
          let fieldName = field.symText
          let fieldSym = field.symId
          skip field # export marker
          skip field # pragmas
          let fieldType = field
          let fieldTyName = fieldType.symText
          recordTypeWrappers(fieldType, f.subinfo)

          f.ty = fieldTyName
          f.raw = fieldType
          result.fields[fieldName] = f
        skip fieldCursor

proc collectTypeDecls*(c: var TypeCache, root: NifCursor) =
  var n = root
  if n.kind != TagLit:
    return
  n.loopInto:
    case n.stmtKind
    of TypeS:
      let tyDef = n
      let instance = addTypeInstance(tyDef)
      c.addInstance(instance)
    of ProcS, FuncS:
      let pDef = n
      let instance = addProcTypeInstance(pDef)
      c.addInstance(instance)
    else:
      discard
    collectTypeDecls(c, n)
    n.skip()
