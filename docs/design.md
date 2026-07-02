# Borrow checker design

In order to achieve borrow checking, we use **NLL** (Non-Lexical Lifetimes), meaning lifetimes are tied to variable last use.
We have `Copyable` and non-`Copyable` types.

Value types are `Copyable` by default while ref types aren't. However Value types with fields that are ref types becomes non-`Copyable`. This is annotated by the pragma `{.copyable.}`.

Basically non copyable types are the one affected by borrow checking (since `Copyable` one don't require move semantics except if done explicitly like `let b = move(a)`)

## Lifetimes

Each variable is associated with a pair `(creation, last use)`, and borrow conflicts ia just about checking if variable pointing to the same data have overlapping lifetimes.

But this has gotchas like `iterator`, if the last use of a variable is in the loop then it should be considered death after the whole loop (except it's been declared in it)

## Escape Hatchs: pointer

Pointer are considered unsafe so borrow checking for them is unsupported.
