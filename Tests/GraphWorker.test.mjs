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

function groupDependencyModel(edges, extraNodes = [], evidence = []) {
  const outgoing = new Map();
  const incoming = new Map();
  for (const edge of edges) {
    if (!outgoing.has(edge.From)) outgoing.set(edge.From, []);
    if (!incoming.has(edge.To)) incoming.set(edge.To, []);
    outgoing.get(edge.From).push(edge);
    incoming.get(edge.To).push(edge);
  }
  return loadUiFunction('collectGroupDependencies', 'renderGroupDependenciesSection', {
    outgoing, incoming,
    nodesByKey: new Map([{ Key: 'group', Kind: 'group' }, ...extraNodes].map((node) => [node.Key, node])),
    evidenceByKey: new Map(evidence.map((item) => [item.Key, item])),
    report: { manifest: { generatedAtUtc: '2026-09-10T00:00:00Z' } }
  });
}

function analysisFixture() {
  const node = (Key, Kind, Properties = {}) => ({ Key, Id: Key, Kind, DisplayName: Key, Status: 'complete', Properties });
  return { manifest: { tenant: { id: 'test-only' }, schemaVersion: '1.1.0', generatedAtUtc: '2026-09-10T12:00:00Z', coverage: { status: 'complete', collectors: [{ name: 'all', status: 'complete', metrics: { collectionStartedAtUtc: '2026-09-10T11:00:00Z', collectionCompletedAtUtc: '2026-09-10T11:30:00Z' } }] } },
    nodes: [node('user', 'user', { department: 'Finance', accountEnabled: true }), node('group', 'group'), node('app', 'servicePrincipal', { appId: 'api' }), node('role', 'roleDefinition'), node('review', 'accessReviewInstance')],
    edges: [], evidence: [{ Key: 'proof', Completeness: 'complete' }] };
}
const analysisEdge = (Key, From, To, Relationship, State = {}) => ({ Key, From, To, Relationship, State, EvidenceIds: ['proof'] });
function analyse(snapshot) {
  return loadUiFunction('createAccessAnalysis', 'renderAnalysisValue', {})(snapshot);
}

test('access removal matches exact entitlements and retains alternative and eligible paths', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('direct', 'user', 'app', 'assignedAppRole', { appRoleId: 'reader' }), analysisEdge('member', 'user', 'group', 'memberOf'), analysisEdge('via', 'group', 'app', 'assignedAppRole', { appRoleId: 'reader' })];
  const after = structuredClone(before); after.manifest.generatedAtUtc = '2026-09-10T12:00:00Z'; after.edges.shift();
  let result = analyse(after).compare(before, 'user');
  assert.equal(result.conclusions[0].result, 'Collected path removed');
  assert.equal(result.conclusions[0].alternatives.length, 1);
  after.edges[0].Relationship = 'pimEligibleMember';
  result = analyse(after).compare(before, 'user');
  assert.equal(result.conclusions[0].eligible.length, 1);
  after.edges[1].State.appRoleId = 'writer';
  assert.equal(analyse(after).compare(before, 'user').conclusions[0].eligible.length, 0);
  assert.match(result.caveat, /sessions ended/);
});

test('partial coverage and missing evidence prevent removal confirmation', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('direct', 'user', 'app', 'assignedAppRole', { appRoleId: 'reader' })];
  const after = analysisFixture(); after.manifest.coverage.status = 'partial';
  assert.match(analyse(after).compare(before, 'user').conclusions[0].result, /Unable/);
  after.manifest.coverage.status = 'complete'; before.evidence = [];
  assert.match(analyse(after).compare(before, 'user').conclusions[0].result, /Unable/);
});

test('comparison refuses wrong tenant schema and reversed or invalid timestamps', () => {
  const before = analysisFixture(); const after = analysisFixture();
  assert.throws(() => analyse(after).compare(before, 'user'), /earlier/);
  before.manifest.generatedAtUtc = 'invalid'; assert.throws(() => analyse(after).compare(before, 'user'), /earlier/);
  before.manifest.tenant.id = 'other'; assert.throws(() => analyse(after).compare(before, 'user'), /tenant/);
  before.manifest.tenant.id = 'test-only'; before.manifest.schemaVersion = 'other'; assert.throws(() => analyse(after).compare(before, 'user'), /schemas/);
});

test('review results require application time and observed removal; pending never confirms removal', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('direct', 'user', 'group', 'memberOf')];
  const after = analysisFixture();
  const decision = analysisEdge('decision', 'user', 'review', 'reviewedInAccessReview', { decision: 'Deny', resourceId: 'group', applyResult: 'NotApplied' });
  after.edges = [decision];
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Decision pending application');
  decision.State.applyResult = 'AppliedSuccessfully';
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Unable to verify');
  decision.State.appliedDateTime = '2026-09-10T10:00:00Z';
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Reviewed path removed');
  after.manifest.coverage.status = 'partial';
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Unable to verify');
});

test('dynamic explanation uses supported grammar and distinguishes observation from calculation', () => {
  const fixture = analysisFixture();
  fixture.nodes[1].Properties.membershipRule = '(user.department -eq "finance") -and (user.accountEnabled -eq true)';
  let result = analyse(fixture).dynamic('group', 'user');
  assert.equal(result.result, 'Calculated match'); assert.equal(result.observed, false); assert.equal(result.conditions.length, 2);
  fixture.nodes[0].Properties.accountEnabled = false;
  assert.equal(analyse(fixture).dynamic('group', 'user').result, 'Calculated non-match');
  delete fixture.nodes[0].Properties.accountEnabled;
  assert.match(analyse(fixture).dynamic('group', 'user').result, /missing attributes/);
  fixture.nodes[1].Properties.membershipRule = 'user.department -match "Finance"';
  assert.match(analyse(fixture).dynamic('group', 'user').result, /unsupported/);
  fixture.nodes[1].Properties.membershipRule = 'globalThis.compromised=true';
  assert.match(analyse(fixture).dynamic('group', 'user').result, /unsupported/);
});

test('PIM analysis never labels activation as standing and requires matching scope for conflicts', () => {
  const fixture = analysisFixture();
  fixture.edges = [analysisEdge('eligible', 'user', 'role', 'eligibleRole', { directoryScopeId: '/' }), analysisEdge('active', 'user', 'role', 'assignedRole', { directoryScopeId: '/', scheduleInstances: [{ assignmentType: 'Activated' }] })];
  assert.equal(analyse(fixture).pim('role').alternatives.length, 0);
  assert.equal(analyse(fixture).pim('role').rows[1].category, 'PIM activation');
  fixture.edges[1].State.scheduleInstances[0].assignmentType = 'Assigned';
  assert.equal(analyse(fixture).pim('role').alternatives.length, 1);
  fixture.edges[1].State.directoryScopeId = '/administrativeUnits/example';
  assert.equal(analyse(fixture).pim('role').alternatives.length, 0);
  assert.equal(analyse(fixture).pim('role').requirements.length, 0);
});

test('group membership preview separates removal from Conditional Access exclusion effects', () => {
  const fixture = analysisFixture(); fixture.nodes.push({ Key: 'policy', Id: 'policy', Kind: 'conditionalAccessPolicy', Status: 'complete', Properties: {} });
  fixture.edges = [analysisEdge('member', 'user', 'group', 'memberOf'), analysisEdge('grant', 'group', 'app', 'assignedAppRole', { appRoleId: 'reader' }), analysisEdge('exclude', 'group', 'policy', 'conditionalAccessExcludes')];
  const result = analyse(fixture).preview('group', 'member');
  assert.equal(result.removed.length, 2);
  assert.equal(result.remaining.length, 0);
  assert.match(result.policyChanges[0].consequence, /exclusion/);
  assert.equal(fixture.edges.length, 3);
  assert.throws(() => analyse(fixture).preview('group', 'grant'), /membership/);
});

test('permission dossier matches IDs and permission type and preserves consent audience', () => {
  const fixture = analysisFixture();
  fixture.nodes.push({ Key: 'registration', Kind: 'application', Properties: { appId: 'client' } }, { Key: 'client', Kind: 'servicePrincipal', Properties: { appId: 'client' } }, { Key: 'requested', Kind: 'apiPermission', Properties: { resourceAppId: 'api', resourceAccessId: 'permission', permissionType: 'Scope' } });
  fixture.nodes[2].Properties.oauth2PermissionScopes = [{ id: 'permission', value: 'Read.Example', adminConsentDescription: 'Read authorised example resources' }];
  fixture.edges = [analysisEdge('request', 'registration', 'requested', 'requiresApiPermission'), analysisEdge('grant', 'client', 'consent', 'hasDelegatedConsent', { resourceId: 'app', scope: 'Read.Example', consentType: 'Principal', principalId: 'user' })];
  const result = analyse(fixture).dossier('client');
  assert.equal(result.requested[0].result, 'Matching collected grant');
  assert.match(result.grants[0].consent, /Individual-user/);
  fixture.nodes.at(-1).Properties.permissionType = 'Role';
  assert.match(analyse(fixture).dossier('client').requested[0].result, /No matching/);
});

test('unsupported requested permission types remain unevaluated', () => {
  const fixture = analysisFixture();
  fixture.nodes.push({ Key: 'registration', Kind: 'application', Properties: { appId: 'api' } }, { Key: 'permission', Kind: 'apiPermission', Properties: { permissionType: 'Role,Scope', resourceAppId: 'api', resourceAccessId: 'read' } });
  fixture.edges.push(analysisEdge('request', 'registration', 'permission', 'requiresApiPermission'));
  const request = analyse(fixture).dossier('registration').requested[0];
  assert.equal(request.permissionType, 'Role,Scope');
  assert.match(request.result, /Unevaluated: unsupported/);
});

test('export serialisation removes fills and builds self-contained safe icon geometry', () => {
  const source = fs.readFileSync(path.join(projectRoot, 'Web/assets/app.js'), 'utf8');
  const exportCode = source.slice(source.indexOf('  async function currentGraphSvgContent('), source.indexOf('  async function exportCurrentSvg('));
  assert.match(exportCode, /\.graph-edge \{ fill: none;/);
  assert.match(exportCode, /allowed\.has\(href\)/);
  assert.match(exportCode, /image\.replaceWith\(icon\)/);
  assert.match(exportCode, /clean\.setAttribute\('d'/);
  assert.doesNotMatch(exportCode, /innerHTML|importNode/);
});

test('baseline state remains in memory with explicit clear and load race protection', () => {
  const source = fs.readFileSync(path.join(projectRoot, 'Web/assets/app.js'), 'utf8');
  const code = source.slice(source.indexOf('  function renderAccessAnalysisSection('), source.indexOf('  function renderObjectDetails('));
  assert.match(code, /renderBaseline\(\);/);
  assert.match(code, /accessBaseline = null/);
  assert.match(code, /sequence !== baselineLoadSequence/);
  assert.match(code, /Incomplete collectors:/);
  assert.doesNotMatch(code, /localStorage|sessionStorage/);
});

test('baseline loads persist across object renders and clear without browser storage', async () => {
  const made = [];
  const makeElement = (tag, cls, text = '') => {
    const element = { tag, textContent: text, children: [], events: {}, append(...items) { this.children.push(...items); }, before() {}, setAttribute() {}, replaceChildren(...items) { this.children = items; }, addEventListener(name, handler) { this.events[name] = handler; } };
    made.push(element); return element;
  };
  const snapshot = analysisFixture();
  const previous = structuredClone(snapshot); previous.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  const context = { accessBaseline: null, baselineLoadSequence: 0, accessAnalysis: analyse(snapshot), report: snapshot, nodesByKey: new Map(snapshot.nodes.map(n => [n.Key,n])), outgoing: new Map(), incoming: new Map(), selectedKey: 'user', makeElement, renderAnalysisValue: value => ({ value }), renderObjectDetails() {} };
  const render = loadUiFunction('renderAccessAnalysisSection', 'renderObjectDetails', context);
  render(snapshot.nodes[0]);
  const input = made.find(e => e.tag === 'input');
  input.files = [{name: 'baseline.json', size: 100, text: async () => JSON.stringify(previous)}];
  await input.events.change();
  assert.equal(context.accessBaseline.name, 'baseline.json');
  made.length = 0; render(snapshot.nodes[0]);
  assert.ok(made.some(e => e.textContent.includes('Loaded: baseline.json')));
  const nextInput = made.find(e => e.tag === 'input');
  nextInput.files = [{name:'bad.json',size:10,text:async()=>'{bad'}];
  await nextInput.events.change();
  assert.equal(context.accessBaseline.name, 'baseline.json');
  made.find(e => e.textContent === 'Clear baseline').events.click();
  assert.equal(context.accessBaseline, null);
});

test('stale checkpoint timing and absent collection timing cannot confirm removals', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('direct', 'user', 'group', 'memberOf')];
  const after = analysisFixture();
  after.manifest.coverage.collectors[0].metrics.collectionStartedAtUtc = '2026-09-08T12:00:00Z';
  assert.equal(analyse(after).compare(before, 'user').verified, false);
  delete after.manifest.coverage.collectors[0].metrics;
  assert.equal(analyse(after).compare(before, 'user').verified, false);
});

test('bounded path search reports truncation and never confirms an absent route', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('direct', 'user', 'group', 'memberOf')];
  const after = analysisFixture();
  after.edges = Array.from({ length: 5100 }, (_, i) => analysisEdge(String(i), 'user', 'app', 'ownedBy'));
  const result = analyse(after).compare(before, 'user');
  assert.equal(result.truncated, true);
  assert.equal(result.verified, false);
});

test('PIM group activation is not mistaken for a standing group route', () => {
  const fixture = analysisFixture();
  fixture.edges = [analysisEdge('eligible', 'user', 'role', 'eligibleRole', { directoryScopeId: '/' }), analysisEdge('membership', 'user', 'group', 'memberOf'), analysisEdge('pim', 'user', 'group', 'pimActiveMember'), analysisEdge('role', 'group', 'role', 'assignedRole', { directoryScopeId: '/', scheduleInstances: [{ assignmentType: 'Assigned' }] })];
  assert.equal(analyse(fixture).pim('role').alternatives.length, 0);
});

test('review application failures and ambiguous app permissions remain unverified', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = ['one', 'two'].map(id => analysisEdge(id, 'user', 'app', 'assignedAppRole', { appRoleId: id }));
  const after = analysisFixture(); after.edges = [analysisEdge('review', 'user', 'review', 'reviewedInAccessReview', { resourceId: 'app', decision: 'Deny', applyResult: 'AppliedSuccessfully', appliedDateTime: '2026-09-10T10:00:00Z' })];
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Unable to verify');
  after.edges[0].State.applyResult = 'AppliedWithUnknownFailure';
  assert.equal(analyse(after).reviews(before, 'user')[0].result, 'Unable to verify');
});

test('expired and invalid assignment schedules cannot appear as current alternatives', () => {
  const fixture = analysisFixture();
  fixture.edges = [analysisEdge('role', 'user', 'role', 'assignedRole', { directoryScopeId: '/', scheduleInstances: [{ assignmentType: 'Activated', endDateTime: '2026-09-01T00:00:00Z' }] })];
  assert.equal(analyse(fixture).routes('user').paths[0].type, 'Expired');
  fixture.edges[0].State.scheduleInstances[0].endDateTime = 'bad';
  assert.equal(analyse(fixture).routes('user').paths[0].type, 'Unknown timing');
});

test('PIM policy explanation separates activation rules from administrator assignment rules', () => {
  const fixture = analysisFixture();
  fixture.nodes[3].Properties.pimPolicies = [{ policyId: 'policy', scopeId: '/', evidenceId: 'proof', rules: [
    { id: 'Approval_EndUser_Assignment', target: { caller: 'EndUser', level: 'Assignment' }, setting: { isApprovalRequired: true } },
    { id: 'Expiration_EndUser_Assignment', target: { caller: 'EndUser', level: 'Assignment' }, maximumDuration: 'PT2H' },
    { id: 'Expiration_Admin_Assignment', target: { caller: 'Admin', level: 'Assignment' }, maximumDuration: 'P365D' }
  ] }];
  const result = analyse(fixture).pim('role').requirements[0];
  assert.equal(result.activationRules.length, 2);
  assert.equal(result.activationRules[0].approval, true);
  assert.equal(result.activationRules[1].maximumDuration, 'PT2H');
});

test('review updates replace earlier pending states even when edge identity changes', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('old', 'user', 'review', 'reviewedInAccessReview', { decisionId: 'decision', resourceId: 'group', decision: 'Deny', applyResult: 'New' }), analysisEdge('member', 'user', 'group', 'memberOf')];
  const after = analysisFixture(); after.edges = [analysisEdge('new', 'user', 'review', 'reviewedInAccessReview', { decisionId: 'decision', resourceId: 'group', decision: 'Deny', applyResult: 'AppliedSuccessfully', appliedDateTime: '2026-09-10T10:00:00Z' })];
  const results = analyse(after).reviews(before, 'user');
  assert.equal(results.length, 1);
  assert.equal(results[0].result, 'Reviewed path removed');
});

test('membership removal retains eligible PIM membership of the same group', () => {
  const before = analysisFixture(); before.manifest.generatedAtUtc = '2026-09-09T12:00:00Z';
  before.edges = [analysisEdge('member', 'user', 'group', 'memberOf')];
  const after = analysisFixture(); after.edges = [analysisEdge('eligible', 'user', 'group', 'pimEligibleMember')];
  const result = analyse(after).compare(before, 'user');
  assert.equal(result.conclusions[0].eligible.length, 1);
  assert.equal(result.conclusions[0].alternatives.length, 0);
});

test('group dependencies separate assignment inclusion exclusion and ownership evidence', () => {
  const relations = ['assignedRole', 'eligibleRole', 'assignedAppRole', 'conditionalAccessIncludes', 'conditionalAccessExcludes', 'pimActiveOwner', 'pimEligibleMember', 'coveredByAccessReview', 'grantsEntitlementResourceRole'];
  const edges = relations.map((relationship, i) => ({ Key: String(i), From: i >= 5 && i !== 7 ? 'other' : 'group', To: i >= 5 && i !== 7 ? 'group' : 'other', Relationship: relationship, EvidenceIds: ['proof'] }));
  const result = groupDependencyModel(edges, [{ Key: 'other', Kind: 'user', DisplayName: '<script>hostile</script>' }], [{ Key: 'proof', Completeness: 'complete' }])('group');
  assert.equal(result.categories.assignments.items.length, 3);
  assert.equal(result.categories.inclusions.items.length, 1);
  assert.equal(result.categories.exclusions.items.length, 1);
  assert.equal(result.categories.membership.items.length, 2);
  assert.equal(result.categories.governance.items.length, 2);
  assert.equal(result.categories.membership.items[0].direction, 'Incoming');
  assert.equal(result.categories.assignments.items[0].evidenceComplete, true);
  assert.equal(result.categories.assignments.items[0].relatedName, '<script>hostile</script>');
});

test('group dependency absence and unresolved references never manufacture evidence', () => {
  const collect = groupDependencyModel([{ Key: 'missing', From: 'group', To: 'absent', Relationship: 'assignedRole', EvidenceIds: ['unknown'] }]);
  assert.equal(collect('group').categories.assignments.items[0].evidenceComplete, false);
  assert.equal(collect('unknown'), null);
  assert.equal(groupDependencyModel([])('group').total, 0);
});

test('group dependency inspection is bounded and does not follow nested assignments', () => {
  const edges = Array.from({ length: 600 }, (_, i) => ({ Key: String(i), From: 'child' + i, To: 'group', Relationship: 'memberOf' }));
  edges.push({ Key: 'parent', From: 'group', To: 'parent', Relationship: 'memberOf' }, { Key: 'role', From: 'parent', To: 'role', Relationship: 'assignedRole' });
  const result = groupDependencyModel(edges)('group');
  assert.equal(result.total, 601);
  assert.equal(result.examined, 500);
  assert.equal(result.truncated, true);
  assert.equal(result.categories.assignments.items.length, 0);
});

test('group dependency categories preserve unknown relationship types as context', () => {
  const collect = groupDependencyModel([{ Key: 'edge', From: 'group', To: 'other', Relationship: 'futureRelationship', EvidenceIds: [] }]);
  assert.equal(collect('group').categories.context.items.length, 1);
  assert.equal(collect('group', Number.NaN).examined, 1);
});

test('group dependency renderer uses text nodes and exposes coverage and exclusion warnings', () => {
  const model = groupDependencyModel([{ Key: 'edge', From: 'group', To: 'policy', Relationship: 'conditionalAccessExcludes', EvidenceIds: ['missing'] }], [{ Key: 'policy', Kind: 'conditionalAccessPolicy', DisplayName: '<img onerror=alert(1)>' }]);
  const makeElement = (tag, className, text) => ({ tag, text, children: [], append(...children) { this.children.push(...children); } });
  const render = loadUiFunction('renderGroupDependenciesSection', 'renderObjectDetails', {
    collectGroupDependencies: model, makeElement, formatRelationship: (value) => value,
    nodesByKey: new Map(), evidenceByKey: new Map(), openNodeButton: () => { throw new Error('Unresolved object must not link'); }
  });
  const result = JSON.stringify(render({ Key: 'group' }));
  assert.match(result, /Dependencies outside collection coverage are unknown/);
  assert.match(result, /A sign-in outcome is not evaluated/);
  assert.match(result, /<img onerror=alert\(1\)>/);
  assert.doesNotMatch(result, /innerHTML/);
});

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
