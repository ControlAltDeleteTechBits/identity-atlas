import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.dirname(testDirectory);
const reportPath = process.env.IDENTITY_ATLAS_TEST_REPORT;
const workerSourcePath = path.join(projectRoot, 'Web', 'assets', 'graph-worker-source.js');

function loadUiFunction(name, nextName, bindings = {}) {
  const source = fs.readFileSync(path.join(projectRoot, 'Web/assets/app.js'), 'utf8');
  const start = source.indexOf(`  function ${name}(`);
  const end = source.indexOf(`  function ${nextName}(`, start);
  assert.ok(start >= 0 && end > start);
  return vm.runInNewContext(`${source.slice(start, end)}; ${name}`, bindings);
}

test('authentication findings exclude denied failed skipped partial and legacy unknown collection', () => {
  const statuses = ['empty', 'complete', 'accessDenied', 'failed', 'partial', 'skipped', 'notCollected', 'future-status'];
  const nodes = statuses.map((status) => ({ Key: status, Kind: 'user', Status: 'complete', Properties: {} }));
  const coverage = Object.fromEntries(statuses.map((status) => [status, { status }]));
  const report = { nodes, edges: nodes.map((node) => ({ From: node.Key, Relationship: 'assignedRole' })), manifest: { tenant: { id: 'test' }, coverage: { collectors: [{ name: 'devicesAndAuthentication', metrics: { authenticationByUser: coverage } }] } } };
  const authenticationCollectionStatus = loadUiFunction('authenticationCollectionStatus', 'nodeHasStrongAuthentication', { report });
  const bindings = { report, nodesByKey: new Map(nodes.map((node) => [node.Key, node])), authenticationCollectionStatus, nodeHasStrongAuthentication: () => false };
  const privilegedRoleUsersWithoutStrongAuth = loadUiFunction('privilegedRoleUsersWithoutStrongAuth', 'isTenantManagedApplication', bindings);
  assert.deepEqual(Array.from(privilegedRoleUsersWithoutStrongAuth(), (node) => node.Key), ['empty', 'complete']);
  const collect = loadUiFunction('collectInsights', 'insightReviewKey', { ...bindings, privilegedRoleUsersWithoutStrongAuth, isTenantManagedApplication: () => false, outboundRelationships: () => [], credentialExpiresSoon: () => false, daysSince: () => null });
  assert.deepEqual(Array.from(collect().find((insight) => insight.id === 'users-without-authentication-methods').nodes, (node) => node.Key), ['empty']);
  assert.match(authenticationCollectionStatus(nodes[2]).label, /Access denied.*unknown/);
  report.manifest.coverage.collectors = [];
  assert.equal(privilegedRoleUsersWithoutStrongAuth().length, 0);
  assert.equal(collect().find((insight) => insight.id === 'users-without-authentication-methods').nodes.length, 0);
});

test('strong method recognition handles Graph camel-case method names', () => {
  for (const methodType of ['windowsHelloForBusinessAuthenticationMethod', 'temporaryAccessPassAuthenticationMethod', 'fido2AuthenticationMethod', 'microsoftAuthenticatorAuthenticationMethod', 'passwordAuthenticationMethod']) {
    const check = loadUiFunction('nodeHasStrongAuthentication', 'privilegedRoleUsersWithoutStrongAuth', { outboundRelationships: () => [{ To: 'method' }], nodesByKey: new Map([['method', { DisplayName: methodType, Properties: { methodType } }]]) });
    assert.equal(check({ Key: 'user' }), methodType !== 'passwordAuthenticationMethod');
  }
});

test('owner findings distinguish tenant applications from external and managed identities', () => {
  const eligible = loadUiFunction('isTenantManagedApplication', 'collectInsights');
  assert.equal(eligible({ Kind: 'application' }, 'tenant'), true);
  assert.equal(eligible({ Kind: 'servicePrincipal', Properties: { servicePrincipalType: 'Application', appOwnerOrganizationId: 'TENANT' } }, 'tenant'), true);
  assert.equal(eligible({ Kind: 'servicePrincipal', Properties: { servicePrincipalType: 'Application', appOwnerOrganizationId: 'external' } }, 'tenant'), false);
  assert.equal(eligible({ Kind: 'servicePrincipal', Properties: { servicePrincipalType: 'ManagedIdentity', appOwnerOrganizationId: 'tenant' } }, 'tenant'), false);
  assert.equal(eligible({ Kind: 'servicePrincipal', Properties: {} }, 'tenant'), false);
});

test('remediation chooses the resource type and rejects executable tenant strings', () => {
  const snippet = loadUiFunction('remediationForInsight', 'exportInsightEvidence');
  const node = { Kind: 'servicePrincipal', Id: "bad'; unexpected-command", DisplayName: 'Label\nunexpected-command', Properties: {} };
  const result = snippet({ id: 'ownerless-applications' }, node);
  assert.match(result, /Get-MgServicePrincipalOwner -ServicePrincipalId '<object-id>'/);
  assert.match(result, /New-MgServicePrincipalOwnerByRef/);
  assert.ok(!result.includes('\nunexpected-command'));
  assert.ok(!result.includes("bad';"));
  node.Kind = 'application';
  assert.match(snippet({ id: 'ownerless-applications' }, node), /Get-MgApplicationOwner -ApplicationId/);
});

test('masked evidence drops names identifiers state and unrecognised relationship text', () => {
  const mask = loadUiFunction('maskedEvidence', 'previewEvidenceExport', { formatRelationship: (value) => value });
  const result = mask([{ From: 'private-user', To: 'private-group', Relationship: 'memberOf', State: { secret: 'private-state' } }, { From: 'private-user', To: 'another-object', Relationship: 'private-label' }]);
  assert.match(result, /Object 1 > memberOf > Object 2/);
  assert.match(result, /Object 1 > Collected relationship > Object 3/);
  assert.ok(!result.includes('private-'));
});

test('assignment rules distinguish nesting, eligibility and ownership', () => {
  const nodes = [['u', 'user'], ['g', 'group'], ['nested', 'group'], ['app', 'servicePrincipal'], ['role', 'roleDefinition']]
    .map(([Key, Kind]) => ({ Key, Id: Key, Kind, DisplayName: Key, Properties: {} }));
  const edge = (Key, From, To, Relationship) => ({ Key, From, To, Relationship, State: {}, EvidenceIds: [] });
  const query = (edges) => createWorkerHarness({ nodes, edges }).send({ type: 'explainUserAccess', requestId: 99, startKey: 'u' });
  assert.equal(query([edge('a', 'u', 'g', 'memberOf'), edge('b', 'g', 'nested', 'memberOf'), edge('c', 'nested', 'app', 'assignedAppRole')]).length, 0);
  assert.equal(query([edge('a', 'u', 'g', 'memberOf'), edge('b', 'g', 'app', 'assignedAppRole')]).length, 1);
  const eligible = query([edge('a', 'u', 'g', 'pimEligibleMember'), edge('b', 'g', 'role', 'assignedRole')]);
  assert.equal(eligible[0].classification, 'Eligible route, activation required');
  const owner = query([edge('a', 'u', 'g', 'pimActiveOwner'), edge('b', 'g', 'role', 'assignedRole')]);
  assert.equal(owner.length, 1);
  assert.equal(owner[0].nodeKey, 'g');
  assert.equal(owner[0].classification, 'Contextual relationship');
});

test('dense cyclic graph search has a bounded work budget', () => {
  const nodes = [{ Key: 'u', Kind: 'user', DisplayName: 'u' }, ...Array.from({ length: 160 }, (_, i) => ({ Key: `g${i}`, Kind: 'group', DisplayName: `g${i}` }))];
  const edges = [{ Key: 'start', From: 'u', To: 'g0', Relationship: 'memberOf' }];
  for (let i = 0; i < 160; i++) for (let j = 0; j < 160; j++) if (i !== j) edges.push({ Key: `${i}:${j}`, From: `g${i}`, To: `g${j}`, Relationship: 'memberOf' });
  const harness = createWorkerHarness({ nodes, edges });
  const start = Date.now();
  assert.equal(harness.send({ type: 'explainUserAccess', requestId: 100, startKey: 'u' }).length, 0);
  assert.equal(harness.diagnostics(100).truncated, true);
  assert.ok(Date.now() - start < 2500);
});

test('assignment dates are evaluated at report time, not the current clock', () => {
  const nodes = [{ Key: 'u', Kind: 'user', DisplayName: 'User' }, { Key: 'r', Kind: 'roleDefinition', DisplayName: 'Role' }];
  const query = (State) => createWorkerHarness({ nodes, edges: [{ Key: 'e', From: 'u', To: 'r', Relationship: 'assignedRole', State }], manifest: { generatedAtUtc: '2025-01-01T00:00:00Z' } })
    .send({ type: 'explainUserAccess', requestId: 2, startKey: 'u' })[0];
  assert.equal(query({ endDateTime: '2024-12-31T00:00:00Z' }).assignmentState, 'Expired');
  assert.equal(query({ startDateTime: '2025-02-01T00:00:00Z' }).assignmentState, 'Future');
  assert.equal(query({ endDateTime: '2025-02-01T00:00:00Z' }).assignmentState, 'Observed assignment');
});

if (!reportPath || !path.isAbsolute(reportPath)) {
  throw new Error('IDENTITY_ATLAS_TEST_REPORT must contain an absolute path to an ephemeral test report.');
}

function createWorkerHarness(report) {
  const sourceContext = { window: {} };
  vm.createContext(sourceContext);
  vm.runInContext(fs.readFileSync(workerSourcePath, 'utf8'), sourceContext);

  const messages = new Map();
  const diagnostics = new Map();
  const workerContext = {
    self: {
      postMessage(message) {
        messages.set(message.requestId, message.result);
        diagnostics.set(message.requestId, message.diagnostics);
      }
    }
  };
  vm.createContext(workerContext);
  vm.runInContext(sourceContext.window.IdentityAtlasWorkerSource, workerContext);

  function send(message) {
    workerContext.self.onmessage({ data: message });
    return messages.get(message.requestId);
  }

  send({
    type: 'initialise',
    requestId: 1,
    nodes: report.nodes,
    edges: report.edges,
    observedAt: report.manifest?.generatedAtUtc
  });

  return { send, diagnostics: (id) => diagnostics.get(id) };
}

test('worker search finds Mark Oldham', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const result = harness.send({
    type: 'search',
    requestId: 2,
    query: 'mark oldham',
    kind: ''
  });

  assert.equal(result.length, 1);
  assert.equal(report.nodes.find((node) => node.Key === result[0]).DisplayName, 'Mark Oldham');
});

test('worker explains the group-based Global Administrator path', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const paths = harness.send({
    type: 'explainUserDirectoryRole',
    requestId: 3,
    startKey: mark.Key
  });

  assert.equal(paths.length, 1);
  assert.equal(paths[0].edgeKeys.length, 2);
  assert.deepEqual(
    Array.from(paths[0].nodeKeys, (key) => report.nodes.find((node) => node.Key === key).DisplayName),
    ['Mark Oldham', 'Privileged Access Operators', 'Global Administrator']
  );
});

test('worker keeps direct role assignments shorter than group-based paths', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const priya = report.nodes.find((node) => node.DisplayName === 'Priya Shah');
  const paths = harness.send({
    type: 'explainUserDirectoryRole',
    requestId: 4,
    startKey: priya.Key
  });

  assert.equal(paths.length, 1);
  assert.equal(paths[0].edgeKeys.length, 1);
});

test('worker explains direct application app role assignments', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const paths = harness.send({
    type: 'explainUserAccess',
    requestId: 5,
    startKey: mark.Key
  });
  const applicationPath = paths.find((path) => {
    const target = report.nodes.find((node) => node.Key === path.nodeKeys[path.nodeKeys.length - 1]);
    return target && target.DisplayName === 'Contoso Finance API' && path.edgeKeys.length === 1;
  });

  assert.ok(applicationPath);
  assert.deepEqual(
    Array.from(applicationPath.nodeKeys, (key) => report.nodes.find((node) => node.Key === key).DisplayName),
    ['Mark Oldham', 'Contoso Finance API']
  );
});

test('worker explains direct Conditional Access policy inclusion', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const paths = harness.send({
    type: 'explainUserAccess',
    requestId: 6,
    startKey: mark.Key
  });
  const policyPath = paths.find((path) => {
    const target = report.nodes.find((node) => node.Key === path.nodeKeys[path.nodeKeys.length - 1]);
    return target && target.DisplayName === 'Require MFA for Finance API' && path.edgeKeys.length === 1;
  });

  assert.ok(policyPath);
  assert.deepEqual(
    Array.from(policyPath.nodeKeys, (key) => report.nodes.find((node) => node.Key === key).DisplayName),
    ['Mark Oldham', 'Require MFA for Finance API']
  );
});

test('worker search supports combined application filters', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const result = harness.send({
    type: 'search',
    requestId: 7,
    query: 'contoso finance',
    kind: 'servicePrincipal,application'
  });
  const names = result.map((key) => report.nodes.find((node) => node.Key === key).DisplayName);

  assert.deepEqual(names, ['Contoso Finance API', 'Contoso Finance API registration']);
});

test('worker explains application owners credentials and permissions', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const app = report.nodes.find((node) => node.DisplayName === 'Contoso Finance API registration');
  const paths = harness.send({
    type: 'explainApplicationAccess',
    requestId: 8,
    startKey: app.Key
  });
  const targets = paths.map((path) => report.nodes.find((node) => node.Key === path.nodeKeys[path.nodeKeys.length - 1]).DisplayName);

  assert.ok(targets.includes('Mark Oldham'));
  assert.ok(targets.includes('Finance API client secret'));
  assert.ok(targets.includes('Microsoft Graph User.Read.All'));
  assert.ok(targets.includes('Contoso Finance API'));
});

test('worker explains user device and authentication method relationships', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const harness = createWorkerHarness(report);
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const paths = harness.send({
    type: 'explainUserAccess',
    requestId: 9,
    startKey: mark.Key
  });
  const targets = paths.map((path) => report.nodes.find((node) => node.Key === path.nodeKeys[path.nodeKeys.length - 1]).Kind);

  assert.ok(targets.includes('device'));
  assert.ok(targets.includes('authenticationMethod'));
});

test('worker rejects directory role inheritance through nested groups', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const privilegedGroup = report.nodes.find((node) => node.DisplayName === 'Privileged Access Operators');
  const originalMembership = report.edges.find((edge) => edge.From === mark.Key && edge.To === privilegedGroup.Key && edge.Relationship === 'memberOf');
  report.edges = report.edges.filter((edge) => edge !== originalMembership);
  const intermediateGroup = {
    Key: 'tenant:test:graph:nested-group',
    Id: 'nested-group',
    Kind: 'group',
    DisplayName: 'Nested administration group',
    Properties: {},
    Status: 'complete'
  };
  report.nodes.push(intermediateGroup);
  report.edges.push(
    { Key: 'edge:nested-one', From: mark.Key, To: intermediateGroup.Key, Relationship: 'memberOf', EvidenceIds: [], State: { membershipType: 'directMember' } },
    { Key: 'edge:nested-two', From: intermediateGroup.Key, To: privilegedGroup.Key, Relationship: 'memberOf', EvidenceIds: [], State: { membershipType: 'nestedGroup' } }
  );
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainUserDirectoryRole', requestId: 10, startKey: mark.Key });

  assert.equal(paths.length, 0);
});

test('worker explains PIM group membership followed by a role assignment', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const group = report.nodes.find((node) => node.DisplayName === 'Privileged Access Operators');
  report.edges = report.edges.filter((edge) => !(edge.From === mark.Key && edge.To === group.Key && edge.Relationship === 'memberOf'));
  report.edges.push({ Key: 'edge:pim-active', From: mark.Key, To: group.Key, Relationship: 'pimActiveMember', EvidenceIds: [], State: { activation: 'active' } });
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainUserDirectoryRole', requestId: 11, startKey: mark.Key });

  assert.equal(paths.length, 1);
  assert.equal(paths[0].edgeKeys.length, 2);
  assert.equal(paths[0].edgeKeys[0], 'edge:pim-active');
});

test('worker explains access granted through an entitlement package', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const financeApp = report.nodes.find((node) => node.DisplayName === 'Contoso Finance API');
  const accessPackage = {
    Key: 'tenant:test:graph:access-package',
    Id: 'access-package',
    Kind: 'accessPackage',
    DisplayName: 'Finance access package',
    Properties: {},
    Status: 'complete'
  };
  report.nodes.push(accessPackage);
  report.edges.push(
    { Key: 'edge:package-assignment', From: mark.Key, To: accessPackage.Key, Relationship: 'assignedAccessPackage', EvidenceIds: [], State: { status: 'Delivered' } },
    { Key: 'edge:package-resource', From: accessPackage.Key, To: financeApp.Key, Relationship: 'grantsEntitlementResourceRole', EvidenceIds: [], State: { roleDisplayName: 'Finance.Reader' } }
  );
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainUserAccess', requestId: 12, startKey: mark.Key });
  const entitlementPath = paths.find((path) => path.edgeKeys.includes('edge:package-resource'));

  assert.ok(entitlementPath);
  assert.deepEqual(Array.from(entitlementPath.edgeKeys), ['edge:package-assignment', 'edge:package-resource']);
});

test('worker explains membership of an Administrative Unit', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const unit = {
    Key: 'tenant:test:graph:administrative-unit',
    Id: 'administrative-unit',
    Kind: 'administrativeUnit',
    DisplayName: 'UK Operations',
    Properties: {},
    Status: 'complete'
  };
  report.nodes.push(unit);
  report.edges.push({ Key: 'edge:administrative-unit', From: mark.Key, To: unit.Key, Relationship: 'memberOfAdministrativeUnit', EvidenceIds: [], State: {} });
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainUserAccess', requestId: 13, startKey: mark.Key });

  assert.ok(paths.some((path) => path.edgeKeys.includes('edge:administrative-unit')));
});

test('worker explains a user decision in an Access Review', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const mark = report.nodes.find((node) => node.DisplayName === 'Mark Oldham');
  const review = {
    Key: 'tenant:test:graph:access-review',
    Id: 'access-review',
    Kind: 'accessReviewInstance',
    DisplayName: 'Quarterly access review instance',
    Properties: {},
    Status: 'complete'
  };
  report.nodes.push(review);
  report.edges.push({ Key: 'edge:access-review', From: mark.Key, To: review.Key, Relationship: 'reviewedInAccessReview', EvidenceIds: [], State: { decision: 'Approve' } });
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainUserAccess', requestId: 14, startKey: mark.Key });

  assert.ok(paths.some((path) => path.edgeKeys.includes('edge:access-review')));
});

test('worker explains the application management policy governing an application', () => {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const app = report.nodes.find((node) => node.DisplayName === 'Contoso Finance API registration');
  const policy = {
    Key: 'tenant:test:graph:application-management-policy',
    Id: 'application-management-policy',
    Kind: 'applicationManagementPolicy',
    DisplayName: 'Strict application credentials',
    Properties: {},
    Status: 'complete'
  };
  report.nodes.push(policy);
  report.edges.push({ Key: 'edge:application-management-policy', From: app.Key, To: policy.Key, Relationship: 'governedByAppManagementPolicy', EvidenceIds: [], State: {} });
  const harness = createWorkerHarness(report);
  const paths = harness.send({ type: 'explainApplicationAccess', requestId: 15, startKey: app.Key });

  assert.ok(paths.some((path) => path.edgeKeys.includes('edge:application-management-policy')));
});
