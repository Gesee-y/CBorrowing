# Borrow checker design

In order to achieve borrow checking, we use **NLL** (Non-Lexical Lifetimes), meaning lifetimes are tied to the variable's last use.

So I propose that in order to achieve borrow checking, we leverage the current powers of our system

## Value semantics as default

I propse to make every objects use value semantics by default, which allows trivial memory safety and thread safety.

We use the distinction between between *value types* and *ref types* know hen to enable the borrow checker
Value types are already enough for most programs but ref types could still come in handy

## Make the ARC the main memory safety net

It may seems counter intuitive but it's actually the first step to make our borrow checker not invasive.
One huge problem that make a borrow checker feel like hell is **lifetimes**.
Since the borrow checker is the one inserting destructors and stuffs, it needs to precisely know when a variable is still alive to free it correctly.
This induce a huge complexity, both on us and the users.

So to fix it, I propose to have an ARC as default for ref types.
It's flexible, doesn't get in the way an is more efficient than a traditional RC as it try it's best to induce increment/decrement at compile-time and reduce them.

So if we achieved memory safety with ARC, why a borrow checker ?

## Speeding up the ARC with a borrow checker

We know that we have to do increment an decrement with ARC but the borrow checker can actually make it easier.
THrough it's aliasing rules and borrowing concepts, it heavily reduces the number of necessary increment and decrement in a program.

Plus it heavily increase thread safety and make it easier to build thread safe programs and schedulers.
It also solves the cycle issue of the ARC as there can't be cycle like A owns B and B owns A in a borrow checker.

Note that here, the borrow checker doesn't try to *free* things, it only check correctness with his rules.
So no need for complex lifetimes, an easier codebase, and an extremely fast system.

## New borrow checker rules

In order to leverage the power of the ARC to simplify the borrow checker and keep it completely local, we can say this:

- Only the scope that create a variable can move or destroy it
- A child scope taking a ref from a parent scope is a borrow
- An object can't be used if one of it's field is currently borrowe or moved
- A field can be used even though a sibling field is moved (**partial borrow/move**)
- Borrow checking is done with variable kind not the distinction mutable/immutable ref. Assigning to a `let` is an immutable borrow, assigning to a `var` is a move/mutable borrow.

## Use the borrow checker to make the unsafe pointers safe

Before, the pointer type was considered unsafe constructs and yes, it's impossible to guarantee at 100% that they are safe, especially when dealing with FFI.
But we can at least guarantee they are always correct in our code through simple rules:

- No pointer arithmetics
- No wild cast to integer
- Single owner, dropping the owner cause an error as all the pointers are now invalid

So this allows to have safe pointer types to allows simpler interfacing and stuff.
The real challenge is knowing when a pointer will be dropped (the lifetimes thing we want to avoid) but I'm sure we can achieve that through some good static analysis.
