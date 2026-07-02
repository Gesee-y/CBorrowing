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

import std/syncio
import plugins

type
  VarId = distinct uint32
  Lifetime = object
    creation: (int, int)
    last: (int, int)
