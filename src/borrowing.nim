import std/syncio

template enableBorrowChecker*() = {.plugin: "deps/borrow_impl".}
template copyable*(x) = discard

proc enableStrictLets* = discard
proc disableStrictLets* = discard

proc disableAliases* = discard
proc enableAliases* = discard

proc disableMove* = discard
proc enableMove* = discard
