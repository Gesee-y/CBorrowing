import ../src/borrowing
import std/syncio

enableBorrowChecker()

# Target: In the SAME expression, access both copyable and non-copyable fields.
# When building a new value from parts of an existing struct, copyable fields
# can be read multiple times freely, while non-copyable fields can only be
# moved once.

type
  Payload = ref object
    data: int
  Header = object
    size: int           # copyable
    flags: int          # copyable
  Packet = object       # non-copyable: has a ref field
    header: Header      # copyable sub-object
    payload: Payload    # non-copyable ref field

proc main() =
  var pkt = Packet(header: Header(size: 64, flags: 0b101), payload: Payload(data: 42))

  # Reading copyable fields multiple times is fine
  echo pkt.header.size    # copy — OK
  echo pkt.header.flags   # copy — OK
  echo pkt.header.size    # copy again — OK, no borrow exhaustion for value types

  # Moving the ref field
  var pay = pkt.payload   # move pkt.payload → pkt is now partial
  echo pay.data           # OK: pay owns the payload

  echo pkt.header.size    # OK: header is copyable, pkt.header is still accessible
  echo pkt.payload.data   # Error: pkt.payload was moved to `pay`

main()
