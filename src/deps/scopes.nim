

type
  Liveness = object
    birth: NifCursor
    uses: seq[NifCursor]

  ScopeNode = ref object
    variables: Table[string, Liveness]
    registers: Table[string, int]
    children: seq[ScopeNode]
    parent: nil ScopeNode
    stackCount: int
