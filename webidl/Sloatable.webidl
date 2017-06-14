[NoInterfaceObject,
 Exposed=Window]
interface Slotable {
  readonly attribute HTMLSlotElement? assignedSlot;
};
Element implements Slotable;
Text implements Slotable;

[HTMLConstructor]
interface HTMLSlotElement : HTMLElement {
  [CEReactions] attribute DOMString name;
  sequence<Node> assignedNodes(optional AssignedNodesOptions options);
};

dictionary AssignedNodesOptions {
  boolean flatten = false;
};
