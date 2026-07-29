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
