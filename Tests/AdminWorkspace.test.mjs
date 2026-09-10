import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
const source = fs.readFileSync(new URL('../Web/assets/admin-workspace.js', import.meta.url), 'utf8');
function fixture() {
  const node = (Key, Kind, Properties = {}) => ({ Key, Id: Key, DisplayName: Key, Kind, Properties, Source: { resourcePath: `/objects/${Key}` } });
  const edge = (From, To, Relationship, State = {}) => ({ Key: `${From}-${To}-${Relationship}`, From, To, Relationship, State, EvidenceIds: ['evidence'] });
  return { manifest: { tenant: { id: 'test-tenant' }, generatedAtUtc: '2026-01-01T00:00:00Z', coverage: { status: 'partial', collectors: [{ name: 'groups', status: 'partial' }] } }, evidence: [], nodes: [
    node('user', 'user', { accountEnabled: true, managerCollectionStatus: 'collected', managerId: null }), node('unknown-manager', 'user', { accountEnabled: true }), node('guest', 'guestUser'),
    node('group', 'group'), node('peer', 'group'), node('empty', 'group'), node('app', 'application'), node('cred', 'applicationCredential', { endDateTime: '2026-01-15T00:00:00Z' }),
    node('sp', 'servicePrincipal', { preferredSingleSignOnMode: 'saml', signingCertificates: [{ usage: 'Sign', keyId: 'sign', endDateTime: '2026-01-20T00:00:00Z' }, { usage: 'Verify', endDateTime: '2026-01-20T00:00:00Z' }] }),
    node('role', 'roleDefinition', { rolePermissions: [{ allowedResourceActions: ['microsoft.directory/users/basic/update', 'microsoft.directory/users/standard/read', 'microsoft.directory/users/create'], condition: 'restricted' }] }),
    node('unit', 'administrativeUnit', { isMemberManagementRestricted: true }), node('review', 'accessReviewInstance', { status: 'InProgress', endDateTime: '2026-01-12T00:00:00Z' })
  ], edges: [edge('user', 'group', 'memberOf'), edge('user', 'peer', 'memberOf'), edge('group', 'sp', 'assignedAppRole'), edge('peer', 'sp', 'conditionalAccessExcludes'), edge('app', 'cred', 'hasCredential'), edge('guest', 'role', 'eligibleRole', { directoryScopeId: '/administrativeUnits/unit', endDateTime: '2026-01-22T00:00:00Z' }), edge('user', 'unit', 'memberOfAdministrativeUnit')] };
}
function model(report = fixture()) { const window = {}; vm.runInNewContext(source, { window }); return window.IdentityAtlasAdmin.createModel(report, Date.parse('2026-01-01T00:00:00Z')); }
test('admin attention uses coverage collectors, signing usage and recorded deadlines', () => {
  const items = model().attention();
  assert.equal(items.filter(x => x.title.startsWith('SAML')).length, 1);
  assert.ok(items.some(x => x.title.includes('Collection requires attention: groups')));
  assert.ok(items.some(x => x.title === 'Access Review deadline' && x.due === 11));
  assert.ok(items.some(x => x.title.startsWith('Application credential') && x.evidence[0] === 'evidence'));
  assert.ok(items.some(x => x.title.startsWith('eligibleRole')));
});
test('invalid dates never become expired credentials and completed reviews are not outstanding', () => {
  const r = fixture(); r.nodes.find(n => n.Key === 'cred').Properties.endDateTime = 'invalid'; r.nodes.find(n => n.Key === 'review').Properties.status = 'Completed';
  assert.ok(!model(r).attention().some(x => x.title === 'Access Review deadline' || x.title.startsWith('Application credential')));
});
test('external service principals and managed identities do not generate owner chores', () => {
  const r = fixture(); r.nodes.find(n => n.Key === 'sp').Properties.servicePrincipalType = 'ManagedIdentity';
  assert.ok(!model(r).attention().some(x => x.key === 'sp' && x.title.includes('owner')));
});
test('directory distinguishes unknown manager data from collected empty manager', () => {
  assert.deepEqual(Array.from(model().directory({ preset: 'noManager' }), n => n.Key), ['user']);
  assert.equal(model().directory({ preset: 'guestRoles' })[0].Key, 'guest');
  assert.equal(model().directory({ preset: 'caExclusion' })[0].Key, 'peer');
  assert.equal(model().directory({ preset: 'directRole' }).length, 0);
});
test('directory combines kind text preset and sort without changing input', () => {
  const r = fixture(), before = JSON.stringify(r), m = model(r);
  assert.equal(m.directory({ kind: 'group', text: 'empty', preset: 'noMembers' }).length, 1);
  assert.equal(m.directory({ kind: 'apps', preset: 'expiry' }).length, 2);
  m.attention(); m.housekeeping('group'); m.responsibility('user');
  assert.equal(JSON.stringify(r), before);
});
test('housekeeping compares direct membership but preserves different group purposes', () => {
  const result = model().housekeeping('group'); assert.equal(result.peers[0].overlap, 100);
  assert.ok(result.peers[0].uses.includes('conditionalAccessExcludes'));
  assert.ok(result.uses.some(e => e.Relationship === 'assignedAppRole'));
  assert.equal(model().housekeeping('empty').peers.length, 0);
});
test('housekeeping similarity work is bounded on a large directory', () => {
  const r = fixture();
  for (let i = 0; i < 1500; i++) { r.nodes.push({ Key: `large${i}`, Id: `large${i}`, Kind: 'group', DisplayName: `Large ${i}`, Properties: {} }); r.edges.push({ Key: `largeEdge${i}`, From: 'user', To: `large${i}`, Relationship: 'memberOf' }); }
  const result = model(r).housekeeping('group'); assert.equal(result.truncated, true); assert.equal(result.inspected, 1000); assert.equal(result.peers.length, 20);
});
test('role authority separates eligibility conditions AU restrictions and read actions', () => {
  const result = model().responsibility('user')[0];
  assert.match(result.assignment, /activation required/); assert.match(result.scopeResult, /true/);
  assert.equal(result.actions.length, 1); assert.equal(result.conditions[0], 'restricted');
  assert.match(model().responsibility('unknown-manager')[0].scopeResult, /unknown or outside/);
  assert.equal(model().responsibility('app').length, 0);
});
test('portal links use encoded IDs and fixed Entra origin, CSV prevents formula execution', () => {
  const m = model(); const url = m.portal({ Kind: 'group', Id: 'x/#?javascript:evil' });
  assert.equal(new URL(url).origin, 'https://entra.microsoft.com'); assert.ok(url.includes('x%2F%23%3Fjavascript%3Aevil'));
  assert.equal(m.csv([['=SUM(1,2)', ' normal', 'a"b', '\t+1']]), '"\'=SUM(1,2)"," normal","a""b","\'\t+1"');
});
test('admin source keeps tenant content out of HTML and network APIs', () => {
  assert.doesNotMatch(source, /innerHTML|outerHTML|insertAdjacentHTML|\bfetch\s*\(|XMLHttpRequest|\beval\s*\(/);
  assert.match(source, /textContent/); assert.match(source, /noopener noreferrer/);
});

// Event-driven DOM harness validates navigation, filtering, selection and persistence.
class Element {
  constructor(tag) { this.tagName = tag; this.children = []; this.listeners = {}; this.value = ''; this.hidden = false; }
  append(...nodes) { this.children.push(...nodes); }
  prepend(...nodes) { this.children.unshift(...nodes); }
  before(node) { this.previous = node; }
  replaceChildren(...nodes) { this.children = nodes; }
  setAttribute(key, value) { this[key] = value; }
  addEventListener(name, fn) { this.listeners[name] = fn; }
  fire(name) { this.listeners[name]?.({ key: 'Enter' }); }
}
test('workspace navigates filters columns selection notes and exports through real handlers', () => {
  const explorer = new Element('section'), values = new Map(), exports = [], window = {};
  const document = { createElement: tag => new Element(tag), querySelector: () => explorer };
  vm.runInNewContext(source, { window, document, localStorage: { getItem: k => values.get(k), setItem: (k, v) => values.set(k, v) } });
  const workspace = window.IdentityAtlasAdmin.mount(fixture(), { dossier: () => ({}), download: (...args) => exports.push(args), open: () => {}, coverage: () => {}, graph: () => {} });
  const all = (root = explorer.previous) => [root, ...root.children.flatMap(x => x instanceof Element ? all(x) : [])];
  const click = name => { const found = all().find(e => e.tagName === 'button' && e.textContent === name); assert.ok(found, name); found.fire('click'); };
  workspace.home(); assert.equal(explorer.hidden, true); click('Object directory');
  const search = all().find(e => e.tagName === 'input' && e.type === 'search'); search.value = 'empty'; search.fire('keydown');
  assert.ok(all().some(e => e.textContent === '1 matches · page 1 · 0 selected'));
  click('Export filtered CSV'); assert.ok(exports[0][1].includes('empty')); assert.ok(!exports[0][1].includes('unknown-manager'));
  click('Select this page'); click('Inspect selected relationships'); assert.ok(all().some(e => e.textContent === 'Selected object relationships'));
  workspace.object('app'); const note = all().find(e => e.tagName === 'textarea'); note.value = '<script>plain note</script>'; click('Save local note'); assert.ok([...values.values()][0].includes('plain note'));
  click('Delete local note'); assert.ok(![...values.values()][0].includes('plain note'));
  workspace.hide(); assert.equal(explorer.hidden, false);
});
