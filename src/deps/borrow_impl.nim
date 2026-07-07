# ######################################################################################### #
# ################################# Borrow checker plugin ################################# #
# ######################################################################################### #

#[
  There seems to be multiple way to achieve borrow checking and multiple language tried their own
  approach:
    - Lexical scope: Here we bind the lifetime of a variable to its scope and ensure it stay valid
    - Non-Lexical lifetime: He we find the first and last use of a variable and ensure it's valid
    - Generational references: Each region has a generation, a pointer to a region can be invalidated
      by a generation
]#

#[
  Nimony is not able to know when a proc that accept a var nillable object can actually put it to nil
  So that is the first fix

  Next the fix about move.
  It's more complex
]#

import std/[syncio, tables, hashes]
import plugins

type
  SymPath = object
    data: seq[SymId]
func hash(s: SymPath): Hash =
  var h: Hash = 0
  for item in s.data: h = h !& hash(item)
  result = !$h
func `==`(s1, s2: SymPath): bool =
  if s1.data.len != s2.data.len: return false
  for i in 0..s1.data.high:
    if s1.data[i] != s2.data[i]: return false
  return true

type
  VarId = distinct uint32
  Lifetime = object
    creation: (int, int)
    last: (int, int)

  BCContext = object
    buffer: NifBuilder
    liveness: Table[VarId, Lifetime]
    toVarId: Table[SymId, VarId]

proc borrow_check(c: var NifCursor): NifBuilder =
  var context = BCContext()
  context.buffer = createTree()

  var body = c.firstChild
  while body.hasMore:
    context.buffer.takeTree(body)

  echo context.buffer.renderTree()

var inp = loadPluginInput()
saveTree borrow_check(inp)
