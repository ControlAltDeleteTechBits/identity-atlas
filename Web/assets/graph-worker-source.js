window.IdentityAtlasWorkerSource = `
'use strict';

let nodes = [];
let edges = [];
let nodesByKey = new Map();
let edgesByKey = new Map();
let outgoing = new Map();
let incoming = new Map();
let searchTextByKey = new Map();
let observedAt = null;
let diagnostics = {};

function classifyPath(path) {
  const route = path.edgeKeys.map((key) => edgesByKey.get(key));
  const context = route.some((edge) => ['ownedBy', 'hasCredential', 'requiresApiPermission', 'hasServicePrincipal', 'registeredDevice', 'hasAuthenticationMethod', 'pimActiveOwner', 'pimEligibleOwner', 'memberOfAdministrativeUnit', 'reviewedInAccessReview', 'coveredByAccessReview', 'governedByAppManagementPolicy', 'governedByDefaultAppManagementPolicy'].includes(edge.Relationship));
  const scope = route.some((edge) => edge.Relationship.startsWith('conditionalAccess'));
  const eligible = route.some((edge) => ['eligibleRole', 'pimEligibleMember', 'pimEligibleOwner'].includes(edge.Relationship));
  const reference = Date.parse(observedAt);
  const expired = Number.isFinite(reference) && route.some((edge) => edge.State?.endDateTime && Date.parse(edge.State.endDateTime) <= reference);
  const future = Number.isFinite(reference) && route.some((edge) => edge.State?.startDateTime && Date.parse(edge.State.startDateTime) > reference);
  const packageUnknown = route.some((edge) => edge.Relationship === 'assignedAccessPackage' && !['delivered', 'partiallydelivered'].includes(String(edge.State?.state || edge.State?.status || '').toLowerCase()));
  const consent = route.some((edge) => ['hasDelegatedConsent', 'grantsDelegatedScopes', 'subjectOfDelegatedConsent'].includes(edge.Relationship));
  path.classification = consent ? 'Delegated consent, subject to user permissions' : context ? 'Contextual relationship' : scope ? 'Policy scope, not a sign-in decision' : expired ? 'Expired at report time' : future ? 'Not yet active at report time' : eligible ? 'Eligible route, activation required' : packageUnknown ? 'Access package assignment state undetermined' : 'Collected assignment route';
  path.assignmentState = context || scope || consent ? 'Not an active-access assertion' : expired ? 'Expired' : future ? 'Future' : eligible ? 'Eligible' : packageUnknown ? 'Unknown' : 'Observed assignment';
  path.observedAt = observedAt;
  return path;
}

function buildIndexes() {
  nodesByKey = new Map(nodes.map((node) => [node.Key, node]));
  edgesByKey = new Map(edges.map((edge) => [edge.Key, edge]));
  searchTextByKey = new Map(nodes.map((node) => [
    node.Key,
    [
      node.DisplayName,
      node.Id,
      node.Kind,
      node.Properties && node.Properties.userPrincipalName,
      node.Properties && node.Properties.appId
    ].map((value) => String(value || '').toLocaleLowerCase('en-GB')).join(' ')
  ]));
  outgoing = new Map();
  incoming = new Map();

  for (const edge of edges) {
    if (!outgoing.has(edge.From)) {
      outgoing.set(edge.From, []);
    }
    outgoing.get(edge.From).push(edge);
    if (!incoming.has(edge.To)) {
      incoming.set(edge.To, []);
    }
    incoming.get(edge.To).push(edge);
  }
}

function search(query, kind) {
  const needle = String(query || '').trim().toLocaleLowerCase('en-GB');
  const kinds = String(kind || '').split(',').filter(Boolean);
  return nodes
    .filter((node) => !kinds.length || kinds.includes(node.Kind))
    .filter((node) => {
      if (!needle) {
        return true;
      }
      return (searchTextByKey.get(node.Key) || '').includes(needle);
    })
    .sort((left, right) => left.DisplayName.localeCompare(right.DisplayName, 'en-GB'))
    .slice(0, 250)
    .map((node) => node.Key);
}

function edgeAllowed(currentNode, edge, nextNode) {
  if (edge.Relationship === 'subjectOfDelegatedConsent') return ['user', 'guestUser'].includes(currentNode.Kind) && nextNode.Kind === 'oauth2PermissionGrant';
  if (edge.Relationship === 'memberOf') {
    return ['user', 'guestUser', 'group'].includes(currentNode.Kind) && nextNode.Kind === 'group';
  }
  if (edge.Relationship === 'assignedRole') {
    return ['user', 'guestUser', 'group'].includes(currentNode.Kind) && nextNode.Kind === 'roleDefinition';
  }
  if (edge.Relationship === 'eligibleRole') {
    return ['user', 'guestUser', 'group'].includes(currentNode.Kind) && nextNode.Kind === 'roleDefinition';
  }
  if (edge.Relationship === 'assignedAppRole') {
    return ['user', 'guestUser', 'group'].includes(currentNode.Kind) && nextNode.Kind === 'servicePrincipal';
  }
  if (edge.Relationship === 'conditionalAccessIncludes') {
    return ['user', 'guestUser', 'group', 'servicePrincipal', 'conditionalAccessScope'].includes(currentNode.Kind) &&
      nextNode.Kind === 'conditionalAccessPolicy';
  }
  if (edge.Relationship === 'registeredDevice') {
    return ['user', 'guestUser'].includes(currentNode.Kind) && nextNode.Kind === 'device';
  }
  if (edge.Relationship === 'hasAuthenticationMethod') {
    return ['user', 'guestUser'].includes(currentNode.Kind) && nextNode.Kind === 'authenticationMethod';
  }
  if (['pimActiveMember', 'pimEligibleMember', 'pimActiveOwner', 'pimEligibleOwner'].includes(edge.Relationship)) {
    return ['user', 'guestUser', 'directoryObject'].includes(currentNode.Kind) && nextNode.Kind === 'group';
  }
  if (edge.Relationship === 'assignedAccessPackage') {
    return ['user', 'guestUser', 'entitlementSubject', 'directoryObject'].includes(currentNode.Kind) && nextNode.Kind === 'accessPackage';
  }
  if (edge.Relationship === 'grantsEntitlementResourceRole') {
    return currentNode.Kind === 'accessPackage' && ['group', 'servicePrincipal', 'application', 'entitlementResource'].includes(nextNode.Kind);
  }
  if (['memberOfAdministrativeUnit', 'administersAdministrativeUnit'].includes(edge.Relationship)) {
    return ['user', 'guestUser', 'group', 'device', 'directoryObject'].includes(currentNode.Kind) && nextNode.Kind === 'administrativeUnit';
  }
  if (edge.Relationship === 'reviewedInAccessReview') {
    return ['user', 'guestUser', 'directoryObject'].includes(currentNode.Kind) && nextNode.Kind === 'accessReviewInstance';
  }
  return false;
}

function explainApplicationAccess(startKey) {
  const startNode = nodesByKey.get(startKey);
  if (!startNode || !['application', 'servicePrincipal'].includes(startNode.Kind)) {
    return [];
  }

  const starts = [startKey];
  if (startNode.Kind === 'servicePrincipal') {
    for (const edge of incoming.get(startKey) || []) {
      const sourceNode = nodesByKey.get(edge.From);
      if (edge.Relationship === 'hasServicePrincipal' && sourceNode && sourceNode.Kind === 'application') {
        starts.push(edge.From);
      }
    }
  }

  const paths = [];
  for (const nodeKey of starts) {
    for (const edge of outgoing.get(nodeKey) || []) {
      const nextNode = nodesByKey.get(edge.To);
      if (!nextNode) {
        continue;
      }
      if (['hasDelegatedConsent', 'assignedAppRole', 'ownedBy', 'hasCredential', 'requiresApiPermission', 'hasServicePrincipal', 'assignedRole', 'requiresAuthenticationStrength', 'conditionalAccessIncludesLocation', 'conditionalAccessExcludesLocation', 'governedByAppManagementPolicy', 'governedByDefaultAppManagementPolicy', 'coveredByAccessReview'].includes(edge.Relationship)) {
        paths.push({
          nodeKey: nextNode.Key,
          nodeKeys: [nodeKey, nextNode.Key],
          edgeKeys: [edge.Key]
        });
      }
    }
  }

  diagnostics.truncated = paths.length > 20;
  diagnostics.reason = diagnostics.truncated ? 'Application result limit reached.' : '';
  return paths.slice(0, 20).map(classifyPath);
}

function explainUserAccess(startKey, targetKinds) {
  const startNode = nodesByKey.get(startKey);
  if (!startNode || !['user', 'guestUser'].includes(startNode.Kind)) {
    return [];
  }

  const allowedTargetKinds = new Set(targetKinds || ['roleDefinition', 'servicePrincipal', 'application', 'conditionalAccessPolicy', 'device', 'authenticationMethod', 'accessPackage', 'entitlementResource', 'administrativeUnit', 'accessReviewInstance']);
  const started = Date.now();
  let cursor = 0;
  let inspected = 0;

  const queue = [{
    nodeKey: startKey,
    nodeKeys: [startKey],
    edgeKeys: []
  }];
  const paths = [];

  while (cursor < queue.length && paths.length < 50) {
    const current = queue[cursor++];
    const currentNode = nodesByKey.get(current.nodeKey);

    if (current.edgeKeys.length >= 8) {
      diagnostics.truncated = true;
      diagnostics.reason = 'Depth limit reached.';
      continue;
    }

    for (const edge of outgoing.get(current.nodeKey) || []) {
      if (++inspected > 20000 || queue.length >= 20000 || Date.now() - started > 1500) {
        diagnostics.truncated = true;
        diagnostics.reason = 'Search work or time budget reached. Narrow the investigation.';
        return paths.map(classifyPath);
      }
      const nextNode = nodesByKey.get(edge.To);
      if (!nextNode || !edgeAllowed(currentNode, edge, nextNode)) {
        continue;
      }
      if (current.nodeKeys.includes(nextNode.Key)) {
        continue;
      }
      // Ownership is context, never inherited group membership. Application and
      // directory-role assignments do not inherit through nested groups.
      const prior = current.edgeKeys.map((key) => edgesByKey.get(key));
      if (prior.some((item) => ['pimActiveOwner', 'pimEligibleOwner', 'grantsEntitlementResourceRole'].includes(item.Relationship))) continue;
      if (['assignedRole', 'eligibleRole', 'assignedAppRole'].includes(edge.Relationship) &&
          prior.filter((item) => ['memberOf', 'pimActiveMember', 'pimEligibleMember'].includes(item.Relationship)).length > 1) continue;

      const nextPath = {
        nodeKey: nextNode.Key,
        nodeKeys: current.nodeKeys.concat(nextNode.Key),
        edgeKeys: current.edgeKeys.concat(edge.Key)
      };

      if (allowedTargetKinds.has(nextNode.Kind) || (!targetKinds && ['pimActiveOwner', 'pimEligibleOwner', 'subjectOfDelegatedConsent'].includes(edge.Relationship))) {
        paths.push(nextPath);
        if (paths.length >= 50) {
          diagnostics.truncated = true;
          diagnostics.reason = 'Result limit reached. Additional routes may exist.';
          break;
        }
      }
      if (!allowedTargetKinds.has(nextNode.Kind) || ['group', 'accessPackage'].includes(nextNode.Kind)) {
        queue.push(nextPath);
      }
    }
  }

  diagnostics.inspectedEdges = inspected;
  return paths.map(classifyPath).sort((left, right) => Number(left.assignmentState === 'Eligible') - Number(right.assignmentState === 'Eligible') || left.edgeKeys.length - right.edgeKeys.length);
}

function explainUserDirectoryRole(startKey) {
  return explainUserAccess(startKey, ['roleDefinition']);
}

self.onmessage = (event) => {
  const message = event.data;
  diagnostics = { truncated: false, reason: '' };
  let result;

  if (message.type === 'initialise') {
    nodes = message.nodes || [];
    edges = message.edges || [];
    observedAt = message.observedAt || null;
    buildIndexes();
    result = { nodeCount: nodes.length, edgeCount: edges.length };
  } else if (message.type === 'search') {
    result = search(message.query, message.kind);
  } else if (message.type === 'explainUserDirectoryRole') {
    result = explainUserDirectoryRole(message.startKey);
  } else if (message.type === 'explainUserAccess') {
    result = explainUserAccess(message.startKey);
  } else if (message.type === 'explainApplicationAccess') {
    result = explainApplicationAccess(message.startKey);
  } else {
    throw new Error('Unknown worker message type.');
  }

  self.postMessage({
    requestId: message.requestId,
    result,
    diagnostics
  });
};
`;
