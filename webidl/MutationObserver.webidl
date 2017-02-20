/* -*- Mode: IDL; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * The origin of this IDL file is
 * http://dom.spec.whatwg.org
 */

[Exposed=Window]
interface MutationRecord {
  readonly attribute DOMString type;
  [SameObject] readonly attribute Node target;
  [SameObject] readonly attribute NodeList addedNodes;
  [SameObject] readonly attribute NodeList removedNodes;
  readonly attribute Node? previousSibling;
  readonly attribute Node? nextSibling;
  readonly attribute DOMString? attributeName;
  readonly attribute DOMString? attributeNamespace;
  readonly attribute DOMString? oldValue;
};

[Constructor(MutationCallback mutationCallback)]
interface MutationObserver {
  [Throws]
  void observe(Node target, optional MutationObserverInit options);
  void disconnect();
  sequence<MutationRecord> takeRecords();

  [ChromeOnly, Throws]
  sequence<MutationObservingInfo?> getObservingInfo();
  [ChromeOnly]
  readonly attribute MutationCallback mutationCallback;
  [ChromeOnly]
  attribute boolean mergeAttributeRecords;
};

callback MutationCallback = void (sequence<MutationRecord> mutations, MutationObserver observer);

dictionary MutationObserverInit {
  boolean childList = false;
  boolean attributes;
  boolean characterData;
  boolean subtree = false;
  boolean attributeOldValue;
  boolean characterDataOldValue;
  [ChromeOnly]
  boolean nativeAnonymousChildList = false;
  [ChromeOnly]
  boolean animations = false;
  sequence<DOMString> attributeFilter;
};

dictionary MutationObservingInfo : MutationObserverInit
{
  Node? observedNode = null;
};
