import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: A ref object whose field is a non-copyable object (object with ref field).
# Moving the non-copyable object field out of the ref makes the ref partial.
# This is the reverse of ttype12: here the object field IS non-copyable itself,
# so accessing it is a move, not a copy.

type
  Token = ref object
    id: int
  Credentials = object    # non-copyable: has a ref field
    token: Token
    scope: int
  Session = ref object
    creds: Credentials    # non-copyable object field inside a ref

proc main() =
  var s = Session(creds: Credentials(token: Token(id: 7), scope: 3))

  var c = s.creds          # MOVE s.creds (Credentials is non-copyable → move)
  echo c.token.id          # OK: c owns the credentials
  echo c.scope             # OK

  echo s.creds.scope       # Error: s.creds was moved to c
  echo s.creds.token.id    # Error: s.creds was moved (sub-path also invalid)

main()
