template enableBorrowChecker() = {.plugin: "deps/borrow_impl".}
template copyable(x) = discard

proc `&`*[T: ref object](x: T): lent T = x
proc `&mut`*[T: ref object](x: var T): var T = x
