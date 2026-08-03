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

if (!reportPath || !path.isAbsolute(reportPath)) {
  throw new Error('IDENTITY_ATLAS_TEST_REPORT must contain an absolute path to an ephemeral test report.');
}

function createWorkerHarness(report) {
  const sourceContext = { window: {} };
  vm.createContext(sourceContext);
  vm.runInContext(fs.readFileSync(workerSourcePath, 'utf8'), sourceContext);

  const messages = new Map();
  const workerContext = {
    self: {
      postMessage(message) {
        messages.set(message.requestId, message.result);
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
    edges: report.edges
  });

  return { send };
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

test('worker explains access through more than one nested group', () => {
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

  assert.equal(paths.length, 1);
  assert.equal(paths[0].edgeKeys.length, 3);
  assert.deepEqual(
    Array.from(paths[0].nodeKeys, (key) => report.nodes.find((node) => node.Key === key).DisplayName),
    ['Mark Oldham', 'Nested administration group', 'Privileged Access Operators', 'Global Administrator']
  );
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
