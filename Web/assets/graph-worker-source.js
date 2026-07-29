window.IdentityAtlasWorkerSource = `
'use strict';

let nodes = [];
let edges = [];
let nodesByKey = new Map();
let edgesByKey = new Map();
let outgoing = new Map();
let incoming = new Map();
let searchTextByKey = new Map();

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
  if (edge.Relationship === 'memberOf') {
    return ['user', 'guestUser'].includes(currentNode.Kind) && nextNode.Kind === 'group';
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
      if (['ownedBy', 'hasCredential', 'requiresApiPermission', 'hasServicePrincipal', 'assignedRole', 'requiresAuthenticationStrength', 'conditionalAccessIncludesLocation', 'conditionalAccessExcludesLocation'].includes(edge.Relationship)) {
        paths.push({
          nodeKey: nextNode.Key,
          nodeKeys: [nodeKey, nextNode.Key],
          edgeKeys: [edge.Key]
        });
      }
    }
  }

  return paths.slice(0, 20);
}

function explainUserAccess(startKey, targetKinds) {
  const startNode = nodesByKey.get(startKey);
  if (!startNode || !['user', 'guestUser'].includes(startNode.Kind)) {
    return [];
  }

  const allowedTargetKinds = new Set(targetKinds || ['roleDefinition', 'servicePrincipal', 'conditionalAccessPolicy', 'device', 'authenticationMethod']);

  const queue = [{
    nodeKey: startKey,
    nodeKeys: [startKey],
    edgeKeys: []
  }];
  const paths = [];

  while (queue.length > 0 && paths.length < 10) {
    const current = queue.shift();
    const currentNode = nodesByKey.get(current.nodeKey);

    if (current.edgeKeys.length >= 2) {
      continue;
    }

    for (const edge of outgoing.get(current.nodeKey) || []) {
      const nextNode = nodesByKey.get(edge.To);
      if (!nextNode || !edgeAllowed(currentNode, edge, nextNode)) {
        continue;
      }
      if (current.nodeKeys.includes(nextNode.Key)) {
        continue;
      }

      const nextPath = {
        nodeKey: nextNode.Key,
        nodeKeys: current.nodeKeys.concat(nextNode.Key),
        edgeKeys: current.edgeKeys.concat(edge.Key)
      };

      if (allowedTargetKinds.has(nextNode.Kind)) {
        paths.push(nextPath);
      } else {
        queue.push(nextPath);
      }
    }
  }

  return paths.sort((left, right) => left.edgeKeys.length - right.edgeKeys.length);
}

function explainUserDirectoryRole(startKey) {
  return explainUserAccess(startKey, ['roleDefinition']);
}

self.onmessage = (event) => {
  const message = event.data;
  let result;

  if (message.type === 'initialise') {
    nodes = message.nodes || [];
    edges = message.edges || [];
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
    result
  });
};
`;
