

type
  # Describe which kind of type we are dealing with
  TypeKind* = enum
    RefType
    ObjectType
    PrimitiveType

  # Annotation currently seen on the type
  TypeFlag = enum
    Nil

  # An instance of a type.
  # It's obtained from a type declaration
  TypeInst = object
    kind: TypeKind
    subinfo: set[TypeFlag]
    raw: NifCursor
    fields: Table[string, int]

  # Type cache, a global structure bookeeping informations about types
  TypeCache = object
    instances: seq[TypeInst]
