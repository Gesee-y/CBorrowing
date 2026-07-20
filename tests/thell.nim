import ../src/borrowing
import std/syncio

enableBorrowChecker()
{.feature: "lenientnils".}

type
  # Le nœud pointe vers le suivant avec ref object
  Node* = ref object
    val*: int
    next*: Node

  # La structure de la liste chaînée
  LinkedList* = object
    head*: Node

# Création d'un nouveau nœud
proc newNode(val: int): Node =
  Node(val: val, next: nil)

# Ajout en tête de liste (O(1))
proc append*(list: var LinkedList, val: int) =
  var node = newNode(val)
  if list.head == nil:
    list.head = node
  else:
    var current = list.head
    while current.next != nil:
      current = current.next
    current.next = node

# Parcours et affichage
proc printList*(list: var LinkedList) =
  var current = list.head
  while current != nil:
    # Utilisation explicite de $ pour Nimony
    stdout.write($current.val & " -> ")
    current = current.next
  echo "nil"

# --- Test ---
var list: LinkedList

list.append(10)
list.append(20)
list.append(30)

echo "Contenu de la liste :"
printList(list)
# Résultat : 10 -> 20 -> 30 -> nil
