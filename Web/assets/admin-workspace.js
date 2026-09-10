/* Local administration views. This module never makes a tenant request. */
(function initialiseAdminWorkspace() {
  'use strict';

  function createModel(report, now = Date.now()) {
    const nodes = new Map(report.nodes.map(n => [n.Key, n]));
    const incoming = new Map(), outgoing = new Map();
    for (const e of report.edges) {
      if (!incoming.has(e.To)) incoming.set(e.To, []);
      if (!outgoing.has(e.From)) outgoing.set(e.From, []);
      incoming.get(e.To).push(e); outgoing.get(e.From).push(e);
    }
    const out = key => outgoing.get(key) || [];
    const inc = key => incoming.get(key) || [];
    const adjacent = key => [...out(key), ...inc(key)];
    const owners = key => out(key).filter(e => e.Relationship === 'ownedBy');
    const members = key => inc(key).filter(e => e.Relationship === 'memberOf');
    const label = key => nodes.get(key)?.DisplayName || key;
    const days = date => date && Number.isFinite(Date.parse(date)) ? Math.ceil((Date.parse(date) - now) / 86400000) : null;
    function portal(node) {
      const id = encodeURIComponent(node?.Id || '');
      const root = `https://entra.microsoft.com/?tenantId=${encodeURIComponent(report.manifest?.tenant?.id || '')}`;
      if (['user', 'guestUser'].includes(node?.Kind)) return `${root}#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/${id}`;
      if (node?.Kind === 'group') return `${root}#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/${id}`;
      if (node?.Kind === 'application') return `${root}#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/objectId/${id}/appId/${encodeURIComponent(node.Properties?.appId || '')}`;
      if (node?.Kind === 'servicePrincipal') return `${root}#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/${id}/appId/${encodeURIComponent(node.Properties?.appId || '')}`;
      if (node?.Kind === 'roleDefinition') return `${root}#view/Microsoft_AAD_IAM/AllRolesBlade`;
      return `${root}#view/Microsoft_AAD_IGA/IdentityGovernanceMenuBlade/~/overview`;
    }
    function certificates(node) {
      return (node.Properties?.signingCertificates || []).filter(c => c && c.usage === 'Sign' && node.Properties?.preferredSingleSignOnMode === 'saml');
    }
    function credentials(key) {
      return out(key).filter(e => e.Relationship === 'hasCredential').map(e => ({ node: nodes.get(e.To), edge: e })).filter(x => x.node);
    }
    function attention(horizon = 30) {
      const items = [];
      const add = (node, title, reason, due = null, evidence = [], source = '') => items.push({ key: node?.Key || '', title, reason, due, evidence, source, dependencies: node ? adjacent(node.Key).length : 0, url: node ? portal(node) : '' });
      const deadline = (node, title, date, evidence, source) => {
        const d = days(date);
        if (d !== null && d <= horizon) add(node, title, `${d < 0 ? `Expired ${Math.abs(d)} days ago` : d === 0 ? 'Due within 24 hours' : `Due in ${d} days`}. Recorded expiry: ${date}. Review the configuration and dependencies; this is not proof of an outage.`, d, evidence, source);
      };
      for (const n of report.nodes) {
        const ownerCandidate = ['application', 'group'].includes(n.Kind) || (n.Kind === 'servicePrincipal' && n.Properties?.servicePrincipalType !== 'ManagedIdentity' && n.Properties?.appOwnerOrganizationId === report.manifest?.tenant?.id);
        if (ownerCandidate && owners(n.Key).length === 0) add(n, 'No collected technical owner', 'Review responsibility. Absence in this snapshot does not establish that no owner exists or that the object is unused.', null, [], n.Source?.resourcePath || n.Source?.collector || 'Owner relationships');
        for (const c of credentials(n.Key)) deadline(n, `Application credential: ${c.node.DisplayName}`, c.node.Properties?.endDateTime, c.edge.EvidenceIds || [], c.node.Source?.resourcePath || '');
        for (const c of certificates(n)) deadline(n, `SAML signing certificate: ${c.displayName || c.keyId}`, c.endDateTime, [], n.Source?.resourcePath || 'Service principal key credential metadata');
        if (n.Kind === 'accessReviewInstance' && !['Completed', 'Applied', 'Expired'].includes(n.Properties?.status)) deadline(n, 'Access Review deadline', n.Properties?.endDateTime, adjacent(n.Key).flatMap(e => e.EvidenceIds || []), n.Source?.resourcePath || '');
      }
      for (const e of report.edges.filter(e => ['assignedRole', 'eligibleRole', 'pimActiveMember', 'pimEligibleMember', 'pimActiveOwner', 'pimEligibleOwner'].includes(e.Relationship))) {
        const dates = new Set([e.State?.endDateTime, ...(e.State?.scheduleInstances || []).map(s => s.endDateTime)].filter(Boolean));
        for (const date of dates) deadline(nodes.get(e.From), `${e.Relationship}: ${label(e.To)}`, date, e.EvidenceIds || [], 'Assignment schedule evidence. A separate assignment may remain.');
      }
      for (const c of report.manifest?.coverage?.collectors || []) if (c.status !== 'complete') add(null, `Collection requires attention: ${c.name}`, `${c.status || 'Unknown status'}. ${(c.warnings || []).join(' ')} Review collection permissions, skipped options and request failures before drawing absence conclusions.`, null, [], c.name);
      return items.sort((a, b) => (a.due ?? Infinity) - (b.due ?? Infinity) || a.title.localeCompare(b.title));
    }
    function matches(n, preset, roleKey = '') {
      const p = n.Properties || {};
      switch (preset) {
        case 'noManager': return ['user', 'guestUser'].includes(n.Kind) && p.accountEnabled === true && p.managerCollectionStatus === 'collected' && !p.managerId;
        case 'noOwner': return ['group', 'application', 'servicePrincipal'].includes(n.Kind) && owners(n.Key).length === 0;
        case 'noMembers': return n.Kind === 'group' && members(n.Key).length === 0;
        case 'noDescription': return n.Kind === 'group' && !String(p.description || '').trim();
        case 'noDependencies': return n.Kind === 'group' && !adjacent(n.Key).some(e => e.Relationship !== 'ownedBy');
        case 'expiry': return credentials(n.Key).some(c => days(c.node.Properties?.endDateTime) !== null && days(c.node.Properties.endDateTime) <= 30) || certificates(n).some(c => days(c.endDateTime) !== null && days(c.endDateTime) <= 30);
        case 'guestRoles': return (n.Kind === 'guestUser' || p.userType === 'Guest') && out(n.Key).some(e => ['assignedRole', 'eligibleRole'].includes(e.Relationship));
        case 'directRole': return ['user', 'guestUser'].includes(n.Kind) && out(n.Key).some(e => e.Relationship === 'assignedRole' && (!roleKey || e.To === roleKey));
        case 'caExclusion': return n.Kind === 'group' && adjacent(n.Key).some(e => e.Relationship === 'conditionalAccessExcludes');
        default: return true;
      }
    }
    function directory({ kind = '', text = '', preset = '', roleKey = '', sort = 'name', descending = false } = {}) {
      const result = report.nodes.filter(n => ['user', 'guestUser', 'group', 'application', 'servicePrincipal', 'roleDefinition'].includes(n.Kind))
        .filter(n => !kind || (kind === 'users' ? ['user', 'guestUser'].includes(n.Kind) : kind === 'apps' ? ['application', 'servicePrincipal'].includes(n.Kind) : n.Kind === kind))
        .filter(n => matches(n, preset, roleKey))
        .filter(n => `${n.DisplayName} ${n.Id} ${n.Properties?.userPrincipalName || ''} ${n.Properties?.description || ''}`.toLowerCase().includes(text.toLowerCase()));
      const value = n => sort === 'name' ? n.DisplayName : sort === 'kind' ? n.Kind : sort === 'owners' ? owners(n.Key).length : sort === 'members' ? members(n.Key).length : n.Properties?.[sort] ?? '';
      return result.sort((a, b) => (typeof value(a) === 'number' && typeof value(b) === 'number' ? value(a) - value(b) : String(value(a)).localeCompare(String(value(b)), 'en', { numeric: true })) * (descending ? -1 : 1) || a.Key.localeCompare(b.Key));
    }
    function housekeeping(key) {
      const group = nodes.get(key);
      if (group?.Kind !== 'group') return null;
      const ownMembers = new Set(members(key).map(e => e.From));
      const peers = [];
      let inspected = 0, comparisons = 0, truncated = false;
      for (const other of report.nodes) {
        if (other.Kind !== 'group' || other.Key === key || !ownMembers.size) continue;
        if (++inspected > 1000 || comparisons > 100000) { truncated = true; break; }
        const theirs = new Set(members(other.Key).map(e => e.From));
        let shared = 0;
        for (const member of theirs) { if (++comparisons > 100000) { truncated = true; break; } if (ownMembers.has(member)) shared++; }
        if (truncated) break;
        const overlap = shared / (ownMembers.size + theirs.size - shared);
        if (shared && overlap >= 0.5) peers.push({ key: other.Key, name: other.DisplayName, shared, overlap: Math.round(overlap * 100), uses: adjacent(other.Key).filter(e => !['memberOf', 'ownedBy'].includes(e.Relationship)).map(e => e.Relationship) });
      }
      return { ownerCount: owners(key).length, directMemberCount: ownMembers.size, description: group.Properties?.description || 'No description recorded', uses: adjacent(key).filter(e => !['ownedBy'].includes(e.Relationship)), peers: peers.sort((a, b) => b.overlap - a.overlap).slice(0, 20), truncated, inspected: Math.min(inspected, 1000) };
    }
    function responsibility(key) {
      const n = nodes.get(key), result = [];
      if (!n) return result;
      const resource = ['user', 'guestUser'].includes(n.Kind) ? 'users' : n.Kind === 'group' ? 'groups' : n.Kind === 'application' ? 'applications' : n.Kind === 'servicePrincipal' ? 'servicePrincipals' : '';
      if (!resource) return result;
      for (const e of report.edges) {
        if (!['assignedRole', 'eligibleRole'].includes(e.Relationship)) continue;
        const role = nodes.get(e.To);
        const rules = (role?.Properties?.rolePermissions || []).filter(Boolean);
        const actions = rules.flatMap(r => r.allowedResourceActions || []).filter(a => typeof a === 'string' && a.startsWith(`microsoft.directory/${resource}/`) && !/\/(read|create|createAsOwner|restore)$/.test(a));
        if (!actions.length) continue;
        const scope = e.State?.directoryScopeId;
        const objectScope = scope === `/${n.Id}`;
        const unitId = /^\/administrativeUnits\/([^/]+)$/.exec(scope || '')?.[1];
        const unit = unitId ? report.nodes.find(x => x.Kind === 'administrativeUnit' && x.Id === unitId) : null;
        const membership = unit && adjacent(key).find(x => [x.From, x.To].includes(unit.Key) && /member/i.test(x.Relationship));
        const scopeResult = scope === '/' ? 'Tenant scope; object restrictions are not evaluated' : objectScope ? 'Exact object scope; action conditions are not evaluated' : membership ? `Collected Administrative Unit membership; restricted management: ${unit.Properties?.isMemberManagementRestricted ?? 'unknown'}` : 'Scope applicability unknown or outside this object';
        const expiry = days(e.State?.endDateTime);
        result.push({ principal: label(e.From), role: role.DisplayName, assignment: e.Relationship === 'eligibleRole' ? 'Eligible: activation required' : 'Active assignment recorded at collection', scope: scope || 'Unknown', appScope: e.State?.appScopeId || '', scopeResult, timing: expiry !== null && expiry < 0 ? 'Assignment end date has passed' : 'See assignment evidence and schedules', schedules: e.State?.scheduleInstances || [], actions, conditions: rules.map(r => r.condition).filter(Boolean), evidenceIds: e.EvidenceIds || [] });
        if (result.length === 500) break;
      }
      return result;
    }
    function csv(rows) {
      return rows.map(row => row.map(value => {
        let text = String(value ?? '');
        if (/^[\s]*[=+@-]/.test(text) || /^[\t\r\n]/.test(text)) text = `'${text}`;
        return `"${text.replace(/"/g, '""')}"`;
      }).join(',')).join('\r\n');
    }
    return { nodes, label, out, inc, adjacent, owners, members, credentials, certificates, attention, directory, housekeeping, responsibility, portal, csv };
  }

  function mount(report, bridge) {
    const model = createModel(report);
    const explorer = document.querySelector('.explorer-frame');
    const root = document.createElement('section'); root.className = 'admin-workspace'; root.hidden = true; root.setAttribute('aria-label', 'Admin workspace'); explorer.before(root);
    const storageKey = `identity-atlas:admin:${report.manifest?.tenant?.id || 'unknown'}`;
    let state = { kind: '', text: '', preset: '', roleKey: '', sort: 'name', descending: false }, columns = ['kind', 'accountEnabled', 'owners', 'members'], selected = new Set(), page = 0;
    let saved = [], notes = {}, view = 'home', directoryMessage = '';
    try {
      const value = JSON.parse(localStorage.getItem(storageKey) || '{}');
      saved = Array.isArray(value.saved) ? value.saved.filter(s => s && typeof s.name === 'string' && s.state && ['kind', 'text', 'preset', 'roleKey', 'sort'].every(k => typeof s.state[k] === 'string')).slice(0, 30) : [];
      notes = value.notes && typeof value.notes === 'object' && !Array.isArray(value.notes) ? value.notes : {};
    } catch { /* Storage may be unavailable in private browsing. */ }
    const el = (tag, text, css) => { const e = document.createElement(tag); if (text !== undefined) e.textContent = String(text); if (css) e.className = css; return e; };
    const button = (name, fn) => { const b = el('button', name); b.type = 'button'; b.setAttribute('data-focus-key', `button:${name}`); b.addEventListener('click', fn); return b; };
    const detail = (name, content) => { const d = el('details'); d.append(el('summary', name), content); return d; };
    function data(value, depth = 0) {
      if (depth > 7) return el('p', 'Additional detail omitted at display depth limit. See the private report JSON.');
      if (value === null || value === undefined) return el('span', 'Not recorded');
      if (typeof value !== 'object') return el('span', typeof value === 'boolean' ? value ? 'Yes' : 'No' : String(value));
      if (Array.isArray(value)) {
        const list = el('ol');
        if (!value.length) return el('p', 'No entries recorded. Check collection coverage before drawing an absence conclusion.');
        for (const item of value.slice(0, 200)) { const row = el('li'); row.append(data(item, depth + 1)); list.append(row); }
        if (value.length > 200) list.append(el('li', `${value.length - 200} further entries omitted from this panel.`)); return list;
      }
      const grid = el('dl', undefined, 'admin-properties');
      for (const [key, item] of Object.entries(value)) { const label = key.replace(/([a-z])([A-Z])/g, '$1 $2'); const cell = el('dd'); cell.append(data(item, depth + 1)); grid.append(el('dt', label.charAt(0).toUpperCase() + label.slice(1)), cell); } return grid;
    }
    const persist = () => { try { localStorage.setItem(storageKey, JSON.stringify({ saved, notes })); return true; } catch { return false; } };
    const link = n => { const a = el('a', 'Open in Microsoft Entra'); a.href = model.portal(n); a.target = '_blank'; a.rel = 'noopener noreferrer'; return a; };
    const open = key => { hide(); bridge.open(key); };
    function selectControl(name, options, current, onChange) {
      const label = el('label', name), control = el('select');
      for (const [value, text] of options) { const o = el('option', text); o.value = value; control.append(o); }
      control.value = current; control.addEventListener('change', () => onChange(control.value)); label.append(control); return label;
    }
    function heading(title) {
      root.replaceChildren(); root.append(el('h2', title));
      if (bridge.viewChanged) bridge.viewChanged(title);
      const nav = el('nav', undefined, 'admin-toolbar'); nav.setAttribute('aria-label', 'Administration views');
      nav.append(button('Tenant home', home), button('Object directory', directory), button('Group housekeeping', () => { state.kind = 'group'; directory(); }), button('Collection diagnostics', () => { hide(); bridge.coverage(); })); root.append(nav);
      root.append(el('p', `Snapshot: ${report.manifest?.generatedAtUtc || 'Unknown date'}. Read only collected evidence, not live tenant state. Technical ownership is separate from locally recorded business responsibility.`, 'admin-muted'));
      const headingTitle = document.querySelector('.page-heading h2'); if (headingTitle) headingTitle.textContent = title;
    }
    function show() { root.hidden = false; explorer.hidden = true; }
    function hide() { root.hidden = true; explorer.hidden = false; }
    function home() {
      view = 'home'; show(); heading('Tenant administration');
      root.append(el('p', 'Upcoming deadlines and outstanding administration work. Expiry is calculated against this device’s current date. Historical and incomplete evidence must be checked in Entra before action.'));
      const unknownSso = report.nodes.filter(n => n.Kind === 'servicePrincipal' && !Object.hasOwn(n.Properties || {}, 'signingCertificates')).length;
      if (unknownSso) root.append(el('p', `${unknownSso} application objects lack SSO certificate collection metadata. Regenerate with the updated collector to inspect those dates.`, 'verification-status'));
      if ((report.manifest?.coverage?.warnings || []).length) root.append(detail('Collection warnings', data(report.manifest.coverage.warnings)));
      const items = model.attention();
      const counts = el('div', undefined, 'admin-stats');
      for (const [name, count] of [['Expired dates', items.filter(x => x.due !== null && x.due < 0).length], ['Due within 30 days', items.filter(x => x.due !== null && x.due >= 0).length], ['Responsibility and coverage', items.filter(x => x.due === null).length]]) counts.append(el('p', `${count} · ${name}`));
      root.append(counts);
      const filter = el('input'); filter.type = 'search'; filter.placeholder = 'Filter attention items'; filter.setAttribute('aria-label', 'Filter attention items');
      const list = el('div', undefined, 'admin-cards'), status = el('p');
      function draw() {
        list.replaceChildren(); const filtered = items.filter(x => `${x.title} ${model.label(x.key)} ${x.reason}`.toLowerCase().includes(filter.value.toLowerCase()));
        status.textContent = `${filtered.length} attention items. Showing the first 100. No results is not a clean bill of health.`;
        for (const item of filtered.slice(0, 100)) {
          const card = el('article', undefined, 'admin-card'); card.append(el('h3', item.title), el('p', item.key ? model.label(item.key) : 'Collection'), el('p', item.reason), el('p', `${item.dependencies} collected adjacent relationships. Source: ${item.source || 'Snapshot relationship index'}.`));
          if (item.key) card.append(button('Inspect object', () => object(item.key)), link(model.nodes.get(item.key)));
          card.append(detail('Evidence references', data(item.evidence))); list.append(card);
        }
      }
      filter.addEventListener('input', draw); root.append(filter, status, list); draw();
    }
    const columnNames = { kind: 'Object type', accountEnabled: 'Enabled', userPrincipalName: 'User principal name', department: 'Department', managerDisplayName: 'Manager', owners: 'Collected owners', members: 'Direct members', description: 'Description' };
    const cellValue = (n, key) => key === 'kind' ? ({ user: 'User', guestUser: 'Guest', group: 'Group', application: 'App registration', servicePrincipal: 'Enterprise application', roleDefinition: 'Directory role' }[n.Kind] || n.Kind) : key === 'owners' ? model.owners(n.Key).length : key === 'members' ? n.Kind === 'group' ? model.members(n.Key).length : 'Not applicable' : typeof n.Properties?.[key] === 'boolean' ? n.Properties[key] ? 'Yes' : 'No' : n.Properties?.[key] ?? 'Not recorded';
    function directory() {
      const focusKey = document.activeElement?.getAttribute?.('data-focus-key');
      const expanded = Array.from(root.querySelectorAll?.('details[open]') || []).map(d => d.querySelector('summary')?.textContent);
      view = 'directory'; show(); heading('Object directory');
      root.append(el('p', 'Zero owners or members means none observed, not confirmed absence. Guest role views include direct active and eligible directory role assignments; not every directory role is privileged. Search applies to name, ID, user principal name and description.'));
      const toolbar = el('div', undefined, 'admin-toolbar');
      const resetPage = fn => v => { fn(v); page = 0; selected.clear(); directory(); };
      toolbar.append(selectControl('Object type', [['', 'All directory objects'], ['users', 'Users and guests'], ['group', 'Groups'], ['apps', 'Applications and registrations'], ['roleDefinition', 'Directory roles']], state.kind, resetPage(v => state.kind = v)));
      toolbar.append(selectControl('Filter', [['', 'All'], ['noManager', 'Enabled users: no collected manager'], ['noOwner', 'No collected owner'], ['noMembers', 'Groups: no collected direct members'], ['noDescription', 'Groups: missing description'], ['noDependencies', 'Groups: no collected dependencies except owners'], ['expiry', 'Credentials expired or due within 30 days'], ['guestRoles', 'Guests with direct directory role assignments'], ['directRole', 'Users directly assigned to a role'], ['caExclusion', 'Groups used in CA exclusions']], state.preset, resetPage(v => state.preset = v)));
      if (state.preset === 'directRole') toolbar.append(selectControl('Role', [['', 'Any role'], ...report.nodes.filter(n => n.Kind === 'roleDefinition').map(n => [n.Key, n.DisplayName])], state.roleKey, resetPage(v => state.roleKey = v)));
      const searchLabel = el('label', 'Search'), search = el('input'); search.type = 'search'; search.value = state.text; searchLabel.append(search); toolbar.append(searchLabel);
      const applySearch = () => { state.text = search.value.slice(0, 500); page = 0; selected.clear(); directory(); }; search.addEventListener('keydown', e => { if (e.key === 'Enter') applySearch(); }); toolbar.append(button('Search', applySearch), button('Reset filters', () => { state = { kind: '', text: '', preset: '', roleKey: '', sort: 'name', descending: false }; page = 0; selected.clear(); directory(); })); root.append(toolbar);
      const choices = el('fieldset'); choices.append(el('legend', 'Visible columns'));
      for (const [key, name] of Object.entries(columnNames)) { const label = el('label', name), input = el('input'); input.type = 'checkbox'; input.checked = columns.includes(key); input.addEventListener('change', () => { columns = input.checked ? [...columns, key] : columns.filter(x => x !== key); directory(); }); label.prepend(input); choices.append(label); }
      root.append(detail('Customise columns', choices));
      const savedBar = el('div', undefined, 'admin-toolbar'), nameLabel = el('label', 'Saved view name'), name = el('input'); name.maxLength = 80; nameLabel.append(name);
      const message = el('p', directoryMessage); message.setAttribute('role', 'status');
      savedBar.append(nameLabel, button('Save view on this device', () => { const title = name.value.trim(); if (!title) { message.textContent = 'Enter a name first.'; return; } saved = [...saved.filter(s => s.name !== title), { name: title, state: { ...state }, columns: [...columns] }].slice(-30); directoryMessage = persist() ? 'Saved locally for this tenant and browser origin. Saved filters may contain tenant information.' : 'Browser storage unavailable; not saved to disk.'; directory(); }));
      for (const s of saved) if (typeof s.name === 'string' && s.state) savedBar.append(button(`Load ${s.name}`, () => { state = { kind: '', text: '', preset: '', roleKey: '', sort: 'name', descending: false, ...s.state }; columns = Array.isArray(s.columns) ? s.columns.filter(x => Object.hasOwn(columnNames, x)) : columns; page = 0; selected.clear(); directory(); }));
      savedBar.append(button('Clear saved views', () => { saved = []; persist(); directory(); })); root.append(detail('Saved views', savedBar), message);
      const rows = model.directory(state); const pageSize = 100; page = Math.min(page, Math.max(0, Math.ceil(rows.length / pageSize) - 1)); const visible = rows.slice(page * pageSize, (page + 1) * pageSize);
      const actions = el('div', undefined, 'admin-toolbar');
      actions.append(el('span', `${rows.length} matches · page ${page + 1} · ${selected.size} selected`), button('Select this page', () => { visible.forEach(n => selected.add(n.Key)); directory(); }), button('Clear selection', () => { selected.clear(); directory(); }), button('Inspect selected relationships', () => relationships()), button('Export filtered CSV', () => {
        const csv = model.csv([['Name', 'Object ID', ...columns.map(k => columnNames[k])], ...rows.map(n => [n.DisplayName, n.Id, ...columns.map(k => cellValue(n, k))])]); bridge.download('identity-atlas-directory.csv', csv, 'text/csv;charset=utf-8');
      })); root.append(actions);
      const scroll = el('div', undefined, 'admin-table-scroll'), table = el('table'), head = el('thead'), tr = el('tr');
      tr.append(el('th', 'Select'));
      for (const [key, title] of [['name', 'Name'], ...columns.map(k => [k, columnNames[k]])]) { const th = el('th'); th.scope = 'col'; th.setAttribute('aria-sort', state.sort === key ? state.descending ? 'descending' : 'ascending' : 'none'); th.append(button(title, () => { state.descending = state.sort === key ? !state.descending : false; state.sort = key; directory(); })); tr.append(th); }
      head.append(tr); table.append(head); const body = el('tbody');
      for (const n of visible) { const row = el('tr'), check = el('input'); check.type = 'checkbox'; check.checked = selected.has(n.Key); check.setAttribute('aria-label', `Select ${n.DisplayName}`); check.setAttribute('data-focus-key', `select:${n.Key}`); check.addEventListener('change', () => { check.checked ? selected.add(n.Key) : selected.delete(n.Key); directory(); }); const choice = el('td'); choice.append(check); const nameCell = el('td'); nameCell.append(button(n.DisplayName, () => object(n.Key))); row.append(choice, nameCell); for (const k of columns) row.append(el('td', cellValue(n, k))); body.append(row); }
      table.append(body); scroll.append(table); root.append(scroll);
      const paging = el('div', undefined, 'admin-toolbar'), previous = button('Previous page', () => { page--; directory(); }), next = button('Next page', () => { page++; directory(); }); previous.disabled = page === 0; next.disabled = (page + 1) * pageSize >= rows.length; paging.append(previous, next); root.append(paging);
      for (const d of root.querySelectorAll?.('details') || []) if (expanded.includes(d.querySelector('summary')?.textContent)) d.open = true;
      if (focusKey) Array.from(root.querySelectorAll?.('[data-focus-key]') || []).find(e => e.getAttribute('data-focus-key') === focusKey)?.focus({ preventScroll: true });
    }
    function relationships() {
      show(); heading('Selected object relationships'); root.append(button('Back to directory', directory));
      const keys = [...selected].slice(0, 50), edgeMap = new Map();
      for (const key of keys) for (const edge of model.adjacent(key)) { if (edgeMap.size >= 2000) break; edgeMap.set(edge.Key, edge); }
      root.append(el('p', `${selected.size} objects selected. Inspecting at most 50 objects and 2,000 adjacent relationships; no inferred access or deletion safety conclusion.`));
      for (const key of keys) root.append(button(model.label(key), () => object(key)));
      const graphEdges = [...edgeMap.values()].slice(0, 100), graphNodes = [...new Set([...keys, ...graphEdges.flatMap(e => [e.From, e.To])])];
      root.append(button('Open combined graph (first 100 relationships)', () => { hide(); bridge.graph(graphNodes, graphEdges.map(e => e.Key)); }));
      for (const e of [...edgeMap.values()].slice(0, 200)) root.append(detail(`${model.label(e.From)} > ${e.Relationship} > ${model.label(e.To)}`, data({ state: e.State, evidence: e.EvidenceIds })));
      root.append(el('p', 'First 200 relationships shown here. Use individual object views for further evidence.'));
    }
    function object(key) {
      const n = model.nodes.get(key); if (!n) return;
      view = 'object'; show(); heading(n.DisplayName); root.append(button('Back to directory', directory), button('Open relationship graph', () => open(key)), link(n));
      root.append(el('p', `${n.Kind} · ${n.Id}`));
      const notesBox = el('section', undefined, 'admin-card'), noteLabel = el('label', 'Business responsibility and notes (local only)'), input = el('textarea'); input.maxLength = 4000; input.value = typeof notes[key] === 'string' ? notes[key] : ''; noteLabel.append(input); const feedback = el('p'); feedback.setAttribute('role', 'status');
      notesBox.append(noteLabel, el('p', 'Notes are stored unencrypted in this browser origin, scoped to the tenant. They are not Entra ownership, are not included in report exports and may contain sensitive information.'), button('Save local note', () => { notes[key] = input.value; feedback.textContent = persist() ? 'Saved on this device.' : 'Storage unavailable; note remains in memory only.'; }), button('Delete local note', () => { delete notes[key]; input.value = ''; feedback.textContent = persist() ? 'Local note removed.' : 'Removed from memory; browser storage could not be updated.'; }), feedback); root.append(notesBox);
      root.append(el('h3', 'Collected technical owners'));
      const ownerEdges = model.owners(key); if (!ownerEdges.length) root.append(el('p', 'No technical owners observed. Check collection coverage; this is not proof of no owner.'));
      for (const e of ownerEdges) root.append(detail(model.label(e.To), data({ evidence: e.EvidenceIds, relationship: e.Relationship })));
      if (['application', 'servicePrincipal'].includes(n.Kind)) application(n);
      if (n.Kind === 'group') group(n);
      root.append(el('h3', 'Who can administer this?'), el('p', 'Candidate role authority from collected explicit resource actions, not a verified authorisation decision. Owners and business notes above are separate. Wildcards, inherited role permissions, action conditions, restricted management units, privileged target protections and group supplied administrators require further evaluation. Up to 500 matching assignments shown.'));
      const roles = model.responsibility(key); if (!roles.length) root.append(el('p', 'No matching explicit role actions were collected. This does not mean no administrator can manage this object.'));
      for (const role of roles) root.append(detail(`${role.principal} · ${role.role} · ${role.assignment}`, data(role)));
      root.append(detail('Object collection source and properties', data({ source: n.Source, status: n.Status, properties: n.Properties })));
    }
    function application(n) {
      const linked = model.adjacent(n.Key).filter(e => e.Relationship === 'hasServicePrincipal');
      const keys = new Set([n.Key, ...linked.flatMap(e => [e.From, e.To])]);
      root.append(el('h3', 'Application administration'));
      if (!linked.length) root.append(el('p', 'No local registration / service principal link collected. External applications may not have a registration in this tenant.'));
      for (const key of keys) {
        const current = model.nodes.get(key); if (!current) continue;
        const section = el('section', undefined, 'admin-card'); section.append(el('h4', `${current.DisplayName} (${current.Kind})`), link(current));
        const owners = model.owners(key).map(e => ({ name: model.label(e.To), evidence: e.EvidenceIds }));
        section.append(detail('Technical owners', data(owners)), detail('User and group assignments', data(model.inc(key).filter(e => e.Relationship === 'assignedAppRole').map(e => ({ principal: model.label(e.From), state: e.State, evidence: e.EvidenceIds })))));
        section.append(detail('Credentials and SSO certificate metadata', data({ ssoMode: current.Properties?.preferredSingleSignOnMode || 'Not recorded', preferredSigningThumbprint: current.Properties?.preferredTokenSigningKeyThumbprint || 'Not recorded', certificates: current.Properties?.signingCertificates || 'Not collected', credentials: model.credentials(key).map(c => ({ name: c.node.DisplayName, properties: c.node.Properties, evidence: c.edge.EvidenceIds })), federatedCredentials: current.Properties?.federatedIdentityCredentials || 'Not collected' })));
        section.append(el('p', 'SAML signing keys are candidates, not necessarily the active certificate. Check the preferred signing thumbprint in Entra. No secret or certificate key material is collected.'));
        section.append(detail('Provisioning and activity', data({ provisioning: current.Properties?.provisioningStatus || 'Not collected by this report', activity: current.Properties?.signInActivity || 'Not collected by this report', limitation: 'No recorded activity is not evidence that an application is unused.' })));
        root.append(section);
      }
      root.append(detail('Requested and granted permission dossier', data(bridge.dossier(n.Key))));
    }
    function group(n) {
      const result = model.housekeeping(n.Key); root.append(el('h3', 'Group housekeeping'), el('p', 'Review candidates only. No collected dependency, empty membership or overlap is not permission to delete or merge a group. Nested membership and policy exclusions can have different consequences.'));
      root.append(data({ collectedOwners: result.ownerCount, collectedDirectMembers: result.directMemberCount, description: result.description }));
      root.append(detail('Collected uses and dependencies', data(result.uses.slice(0, 500).map(e => ({ from: model.label(e.From), relationship: e.Relationship, to: model.label(e.To), evidence: e.EvidenceIds })))));
      root.append(el('h4', 'Similar direct membership'), el('p', `Jaccard overlap of at least 50%; first 20 matches. ${result.inspected} groups inspected. ${result.truncated ? 'Search limit reached; more matches may exist.' : 'Only collected direct membership is compared.'}`));
      for (const peer of result.peers) { const card = el('article', undefined, 'admin-card'); card.append(button(peer.name, () => object(peer.key)), el('p', `${peer.overlap}% overlap · ${peer.shared} shared direct members`), data({ uses: [...new Set(peer.uses)] })); root.append(card); }
    }
    return { home, directory, object, hide, get view() { return view; } };
  }
  window.IdentityAtlasAdmin = { createModel, mount };
})();
