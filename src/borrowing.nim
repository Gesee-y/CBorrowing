import std/syncio

template enableBorrowChecker*() = {.plugin: "deps/borrow_impl".}
template copyable*(x) = discard
