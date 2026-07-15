# CBorrowing

Borrow checker implementation for Nim.

This offer multiple features like:

- Move semantics
- Partial borrows (borrow only a field of an object for example)
- Non Lexical Lifetimes
- Borrow semantic
- Ease of use (no lifetime annoations)
- Integrated with Nim's value semantics and ARC making it less annoying yet still powerful

## Quick example

```nim
import ../src/borrowing
import std/syncio

enableBorrowChecker()

type
  RefO = ref object
    x: int

proc main() =
  var p = RefO()
  var n = p # `p` is moved to `n` here
  echo p.x # Error: Use after move

main()
```

## But Why

In a world where Nim already possess an ARC which offer memory safety and stuffs, why making a borrow checker ?
Multiple reason drove this project:

- Explore another path for borrow checking, an easier and less verbose path than the one of rust
- An optional borrow checker that only act when needed
- Offer thread-safety, borrow checking greatly improve safety between threads
- AI Workflow, this can act as a constraint to make AI output better results

## License

This project is under the MIT License
