(function initialiseIdentityAtlas() {
  'use strict';

  const report = window.IdentityAtlasData.snapshot();
  let accessAnalysis = null;
  let accessBaseline = null;
  let baselineLoadSequence = 0;
  // Path geometry from the bundled Tabler icons; no external resources in exports.
  const exportIconPaths = {"assets/icons/user.svg":["M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0","M6 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2"],"assets/icons/users-group.svg":["M10 13a2 2 0 1 0 4 0a2 2 0 0 0 -4 0","M8 21v-1a2 2 0 0 1 2 -2h4a2 2 0 0 1 2 2v1","M15 5a2 2 0 1 0 4 0a2 2 0 0 0 -4 0","M17 10h2a2 2 0 0 1 2 2v1","M5 5a2 2 0 1 0 4 0a2 2 0 0 0 -4 0","M3 13v-1a2 2 0 0 1 2 -2h2"],"assets/icons/apps.svg":["M4 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4","M4 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4","M14 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4","M14 7l6 0","M17 4l0 6"],"assets/icons/shield-lock.svg":["M12 3a12 12 0 0 0 8.5 3a12 12 0 0 1 -8.5 15a12 12 0 0 1 -8.5 -15a12 12 0 0 0 8.5 -3","M11 11a1 1 0 1 0 2 0a1 1 0 1 0 -2 0","M12 12l0 2.5"],"assets/icons/shield-check.svg":["M11.46 20.846a12 12 0 0 1 -7.96 -14.846a12 12 0 0 0 8.5 -3a12 12 0 0 0 8.5 3a12 12 0 0 1 -.09 7.06","M15 19l2 2l4 -4"],"assets/icons/adjustments-horizontal.svg":["M12 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0","M4 6l8 0","M16 6l4 0","M6 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0","M4 12l2 0","M10 12l10 0","M15 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0","M4 18l11 0","M19 18l1 0"],"assets/icons/database.svg":["M4 6a8 3 0 1 0 16 0a8 3 0 1 0 -16 0","M4 6v6a8 3 0 0 0 16 0v-6","M4 12v6a8 3 0 0 0 16 0v-6"],"assets/icons/route.svg":["M3 19a2 2 0 1 0 4 0a2 2 0 0 0 -4 0","M19 7a2 2 0 1 0 0 -4a2 2 0 0 0 0 4","M11 19h5.5a3.5 3.5 0 0 0 0 -7h-8a3.5 3.5 0 0 1 0 -7h4.5"],"assets/icons/list-details.svg":["M13 5h8","M13 9h5","M13 15h8","M13 19h5","M3 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4","M3 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4"],"assets/icons/circle-check.svg":["M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0","M9 12l2 2l4 -4"]};
  const nodesByKey = new Map(report.nodes.map((node) => [node.Key, node]));
  const edgesByKey = new Map(report.edges.map((edge) => [edge.Key, edge]));
  const evidenceByKey = new Map(report.evidence.map((item) => [item.Key, item]));
  const outgoing = new Map();
  const incoming = new Map();
  let selectedKey = null;
  let contextKey = null;
  let requestSequence = 0;
  let searchSequence = 0;
  let searchTimer = null;
  let graphZoom = 1;
  let currentGraph = { nodeKeys: [], sourceEdgeKeys: [], edgeKeys: [], summary: '' };
  let currentPath = null;
  const selectionHistory = [];
  const relationshipGroupState = new Map();
  let pngRenderSequence = 0;
  let currentPngDataUrl = '';
  const pendingRequests = new Map();
  const tenantStorageKey = `identity-atlas:${report.manifest?.tenant?.id || 'tenant'}`;
  const reportStorageKey = `${tenantStorageKey}:${report.manifest?.generatedAtUtc || 'report'}`;
  const reviewStates = loadReviewStates();
  const pinnedKeys = loadPinnedKeys();
  let adminWorkspace = null;
  let viewGeneration = 0;

  for (const edge of report.edges) {
    if (!outgoing.has(edge.From)) {
      outgoing.set(edge.From, []);
    }
    if (!incoming.has(edge.To)) {
      incoming.set(edge.To, []);
    }
    outgoing.get(edge.From).push(edge);
    incoming.get(edge.To).push(edge);
  }

  const elements = {
    tenantName: document.getElementById('tenant-name'),
    coverageBanner: document.getElementById('coverage-banner'),
    collectionStatus: document.getElementById('collection-status'),
    collectionSummary: document.getElementById('collection-summary'),
    collectionDate: document.getElementById('collection-date'),
    statusDot: document.querySelector('.status-dot'),
    summaryCards: document.getElementById('summary-cards'),
    globalSearch: document.getElementById('global-search'),
    kindFilter: document.getElementById('kind-filter'),
    resultCount: document.getElementById('result-count'),
    searchResults: document.getElementById('search-results'),
    pinnedSection: document.getElementById('pinned-section'),
    pinnedCount: document.getElementById('pinned-count'),
    pinnedObjects: document.getElementById('pinned-objects'),
    navItems: Array.from(document.querySelectorAll('.product-nav [data-view]')),
    relationshipFilter: document.getElementById('relationship-filter'),
    exportMermaid: document.getElementById('export-mermaid'),
    exportSvg: document.getElementById('export-svg'),
    exportPng: document.getElementById('export-png'),
    exportEvidence: document.getElementById('export-evidence'),
    objectKind: document.getElementById('object-kind'),
    objectHeading: document.getElementById('object-heading'),
    objectSummary: document.getElementById('object-summary'),
    objectDetails: document.getElementById('object-details'),
    selectionBack: document.getElementById('selection-back'),
    selectionBreadcrumbs: document.getElementById('selection-breadcrumbs'),
    pinObject: document.getElementById('pin-object'),
    pageSubtitle: document.getElementById('page-subtitle'),
    showNeighbours: document.getElementById('show-neighbours'),
    explainAccess: document.getElementById('explain-access'),
    headerExplainAccess: document.getElementById('header-explain-access'),
    copyObjectId: document.getElementById('copy-object-id'),
    detailsTab: document.getElementById('details-tab'),
    evidenceTab: document.getElementById('evidence-tab'),
    graph: document.getElementById('relationship-graph'),
    graphCanvas: document.querySelector('.graph-canvas'),
    relationshipGroups: document.getElementById('relationship-groups'),
    graphSummary: document.getElementById('graph-summary'),
    graphDescription: document.getElementById('graph-description'),
    graphTextAlternative: document.getElementById('graph-text-alternative'),
    explanationPanel: document.getElementById('explanation-panel'),
    explanationStatus: document.getElementById('explanation-status'),
    pathList: document.getElementById('path-list'),
    pathDetail: document.getElementById('path-detail'),
    closeExplanation: document.getElementById('close-explanation'),
    contextMenu: document.getElementById('context-menu'),
    contextOpen: document.getElementById('context-open'),
    contextExplain: document.getElementById('context-explain'),
    fitGraph: document.getElementById('fit-graph'),
    graphSettings: document.getElementById('graph-settings'),
    zoomOut: document.getElementById('zoom-out'),
    zoomIn: document.getElementById('zoom-in'),
    zoomValue: document.getElementById('zoom-value'),
    viewAllObjects: document.getElementById('view-all-objects')
  };

  const workerBlob = new Blob([window.IdentityAtlasWorkerSource], { type: 'text/javascript' });
  const worker = new Worker(URL.createObjectURL(workerBlob));

  worker.onmessage = (event) => {
    const pending = pendingRequests.get(event.data.requestId);
    if (!pending) {
      return;
    }
    pendingRequests.delete(event.data.requestId);
    if (Array.isArray(event.data.result)) event.data.result.diagnostics = event.data.diagnostics;
    pending.resolve(event.data.result);
  };

  worker.onerror = (event) => {
    for (const pending of pendingRequests.values()) {
      pending.reject(new Error(event.message || 'The graph worker stopped.'));
    }
    pendingRequests.clear();
  };

  function requestWorker(type, payload) {
    requestSequence += 1;
    const requestId = requestSequence;
    return new Promise((resolve, reject) => {
      pendingRequests.set(requestId, { resolve, reject });
      worker.postMessage({ type, requestId, ...payload });
    });
  }

  function formatKind(kind) {
    const labels = {
      user: 'User',
      guestUser: 'Guest user',
      group: 'Group',
      servicePrincipal: 'Application',
      application: 'App registration',
      applicationCredential: 'Application credential',
      apiPermission: 'API permission',
      oauth2PermissionGrant: 'Delegated consent grant',
      conditionalAccessPolicy: 'Conditional Access policy',
      conditionalAccessScope: 'Conditional Access scope',
      namedLocation: 'Named location',
      authenticationStrength: 'Authentication strength',
      device: 'Device',
      authenticationMethod: 'Authentication method',
      roleDefinition: 'Directory role',
      crossTenantAccessPolicy: 'Cross-tenant access policy',
      externalTenant: 'External tenant',
      applicationManagementPolicy: 'Application management policy',
      administrativeUnit: 'Administrative Unit',
      accessPackageCatalog: 'Access package catalogue',
      accessPackage: 'Access package',
      accessPackageAssignmentPolicy: 'Access package policy',
      entitlementResource: 'Entitlement resource',
      entitlementSubject: 'Entitlement subject',
      accessReviewDefinition: 'Access Review',
      accessReviewInstance: 'Access Review instance',
      accessReviewReviewerScope: 'Access Review reviewer scope',
      directoryObject: 'Directory object'
    };
    return labels[kind] || kind;
  }

  function kindIconClass(kind) {
    const icons = {
      user: 'icon-user',
      guestUser: 'icon-user',
      group: 'icon-users-group',
      servicePrincipal: 'icon-apps',
      application: 'icon-apps',
      applicationCredential: 'icon-shield-lock',
      apiPermission: 'icon-shield-check',
      conditionalAccessPolicy: 'icon-shield-check',
      conditionalAccessScope: 'icon-adjustments-horizontal',
      namedLocation: 'icon-adjustments-horizontal',
      authenticationStrength: 'icon-shield-lock',
      device: 'icon-database',
      authenticationMethod: 'icon-shield-check',
      roleDefinition: 'icon-shield-lock',
      crossTenantAccessPolicy: 'icon-route',
      externalTenant: 'icon-route',
      applicationManagementPolicy: 'icon-shield-check',
      administrativeUnit: 'icon-users-group',
      accessPackageCatalog: 'icon-database',
      accessPackage: 'icon-apps',
      accessPackageAssignmentPolicy: 'icon-shield-check',
      entitlementResource: 'icon-apps',
      entitlementSubject: 'icon-user',
      accessReviewDefinition: 'icon-list-details',
      accessReviewInstance: 'icon-circle-check',
      accessReviewReviewerScope: 'icon-user'
    };
    return icons[kind] || 'icon-apps';
  }

  function graphIconHref(kind) {
    const icons = {
      user: 'assets/icons/user.svg',
      guestUser: 'assets/icons/user.svg',
      group: 'assets/icons/users-group.svg',
      servicePrincipal: 'assets/icons/apps.svg',
      application: 'assets/icons/apps.svg',
      applicationCredential: 'assets/icons/shield-lock.svg',
      apiPermission: 'assets/icons/shield-check.svg',
      conditionalAccessPolicy: 'assets/icons/shield-check.svg',
      conditionalAccessScope: 'assets/icons/adjustments-horizontal.svg',
      namedLocation: 'assets/icons/adjustments-horizontal.svg',
      authenticationStrength: 'assets/icons/shield-lock.svg',
      device: 'assets/icons/database.svg',
      authenticationMethod: 'assets/icons/shield-check.svg',
      roleDefinition: 'assets/icons/shield-lock.svg',
      crossTenantAccessPolicy: 'assets/icons/route.svg',
      externalTenant: 'assets/icons/route.svg',
      applicationManagementPolicy: 'assets/icons/shield-check.svg',
      administrativeUnit: 'assets/icons/users-group.svg',
      accessPackageCatalog: 'assets/icons/database.svg',
      accessPackage: 'assets/icons/apps.svg',
      accessPackageAssignmentPolicy: 'assets/icons/shield-check.svg',
      entitlementResource: 'assets/icons/apps.svg',
      entitlementSubject: 'assets/icons/user.svg',
      accessReviewDefinition: 'assets/icons/list-details.svg',
      accessReviewInstance: 'assets/icons/circle-check.svg',
      accessReviewReviewerScope: 'assets/icons/user.svg'
    };
    return icons[kind] || 'assets/icons/apps.svg';
  }

  function formatRelationship(relationship) {
    const labels = {
      memberOf: 'Member of',
      assignedRole: 'Assigned role',
      eligibleRole: 'Eligible role',
      assignedAppRole: 'Assigned app role',
      hasDelegatedConsent: 'Has granted delegated consent',
      grantsDelegatedScopes: 'Granted delegated scopes on API',
      subjectOfDelegatedConsent: 'User covered by delegated consent',
      hasServicePrincipal: 'Enterprise app',
      hasCredential: 'Has credential',
      requiresApiPermission: 'Requires API permission',
      ownedBy: 'Owned by',
      conditionalAccessIncludes: 'Included in policy',
      conditionalAccessExcludes: 'Excluded from policy',
      registeredDevice: 'Registered device',
      hasAuthenticationMethod: 'Authentication method',
      conditionalAccessIncludesLocation: 'Includes location',
      conditionalAccessExcludesLocation: 'Excludes location',
      requiresAuthenticationStrength: 'Requires auth strength',
      hasCrossTenantPartner: 'Partner configuration',
      governedByAppManagementPolicy: 'Governed by app policy',
      governedByDefaultAppManagementPolicy: 'Governed by default app policy',
      memberOfAdministrativeUnit: 'Member of Administrative Unit',
      scopedToAdministrativeUnit: 'Scoped to Administrative Unit',
      administersAdministrativeUnit: 'Administers Administrative Unit',
      pimActiveMember: 'PIM active member',
      pimActiveOwner: 'PIM active owner',
      pimEligibleMember: 'PIM eligible member',
      pimEligibleOwner: 'PIM eligible owner',
      containsAccessPackage: 'Contains access package',
      governedByAccessPackagePolicy: 'Governed by access package policy',
      assignedAccessPackage: 'Assigned access package',
      grantsEntitlementResourceRole: 'Grants resource role',
      coveredByAccessReview: 'Covered by Access Review',
      reviewsAccess: 'Reviews access',
      hasAccessReviewInstance: 'Has review instance',
      reviewedInAccessReview: 'Reviewed in Access Review',
      resourceReviewedInAccessReview: 'Resource reviewed in Access Review'
    };
    return labels[relationship] || formatPropertyName(relationship);
  }

  function loadReviewStates() {
    try {
      return JSON.parse(localStorage.getItem(`${reportStorageKey}:reviewStates`) || '{}');
    }
    catch {
      return {};
    }
  }

  function saveReviewStates() {
    try {
      localStorage.setItem(`${reportStorageKey}:reviewStates`, JSON.stringify(reviewStates));
    }
    catch {
      // Review state is a convenience feature. The report remains usable if browser storage is blocked.
    }
  }

  function loadPinnedKeys() {
    try {
      const storedKeys = JSON.parse(localStorage.getItem(`${tenantStorageKey}:pinnedObjects`) || '[]');
      return new Set(Array.isArray(storedKeys) ? storedKeys.filter((key) => nodesByKey.has(key)) : []);
    }
    catch {
      return new Set();
    }
  }

  function savePinnedKeys() {
    try {
      localStorage.setItem(`${tenantStorageKey}:pinnedObjects`, JSON.stringify(Array.from(pinnedKeys)));
    }
    catch {
      // Pinned objects are optional. The report remains usable if browser storage is blocked.
    }
  }

  function updatePinButton() {
    const canPin = Boolean(selectedKey && nodesByKey.has(selectedKey));
    const isPinned = canPin && pinnedKeys.has(selectedKey);
    elements.pinObject.disabled = !canPin;
    elements.pinObject.setAttribute('aria-pressed', String(isPinned));
    elements.pinObject.textContent = isPinned ? 'Unpin object' : 'Pin object';
  }

  function renderPinnedObjects() {
    elements.pinnedObjects.replaceChildren();
    const nodes = Array.from(pinnedKeys)
      .map((key) => nodesByKey.get(key))
      .filter(Boolean)
      .sort((left, right) => left.DisplayName.localeCompare(right.DisplayName, 'en-GB'));
    elements.pinnedSection.hidden = !nodes.length;
    elements.pinnedCount.textContent = String(nodes.length);

    for (const node of nodes) {
      const item = makeElement('div', 'pinned-item');
      const openButton = makeElement('button', 'pinned-open');
      openButton.type = 'button';
      openButton.append(
        makeElement('span', 'pinned-name', node.DisplayName),
        makeElement('span', 'pinned-kind', formatKind(node.Kind))
      );
      openButton.addEventListener('click', () => selectNode(node.Key));

      const removeButton = makeElement('button', 'pinned-remove', 'Remove');
      removeButton.type = 'button';
      removeButton.setAttribute('aria-label', `Unpin ${node.DisplayName}`);
      removeButton.addEventListener('click', () => {
        pinnedKeys.delete(node.Key);
        savePinnedKeys();
        renderPinnedObjects();
        updatePinButton();
      });
      item.append(openButton, removeButton);
      elements.pinnedObjects.append(item);
    }
  }

  function reviewStateFor(key) {
    return reviewStates[key] || 'new';
  }

  function setReviewState(key, value) {
    reviewStates[key] = value;
    saveReviewStates();
  }

  function createReviewSelect(key) {
    const select = makeElement('select', 'review-select');
    select.setAttribute('aria-label', 'Review state');
    for (const [value, label] of [
      ['new', 'New'],
      ['reviewed', 'Reviewed'],
      ['acceptedRisk', 'Accepted risk'],
      ['needsChange', 'Needs change'],
      ['falsePositive', 'False positive']
    ]) {
      const option = makeElement('option', null, label);
      option.value = value;
      select.append(option);
    }
    select.value = reviewStateFor(key);
    select.addEventListener('change', () => setReviewState(key, select.value));
    return select;
  }

  function readStoredBoolean(key, defaultValue) {
    try {
      const stored = localStorage.getItem(key);
      return stored === null ? defaultValue : stored === 'true';
    }
    catch {
      return defaultValue;
    }
  }

  function writeStoredBoolean(key, value) {
    try {
      localStorage.setItem(key, String(value));
    }
    catch {
      // Browser storage can be disabled by policy. The setting still applies for the current page session.
    }
  }

  function clearIdentityAtlasBrowserData(button) {
    if (button.dataset.confirmClear !== 'true') {
      button.dataset.confirmClear = 'true';
      button.textContent = 'Click again to clear browser data';
      window.setTimeout(() => {
        if (button.dataset.confirmClear === 'true') {
          delete button.dataset.confirmClear;
          button.textContent = 'Clear Identity Atlas browser data';
        }
      }, 5000);
      return;
    }

    try {
      const storedKeys = [];
      for (let index = 0; index < localStorage.length; index += 1) {
        const key = localStorage.key(index);
        if (key?.startsWith('identity-atlas:')) {
          storedKeys.push(key);
        }
      }
      for (const key of storedKeys) {
        localStorage.removeItem(key);
      }
    }
    catch {
      // In-memory state is still cleared when browser storage is unavailable.
    }

    for (const key of Object.keys(reviewStates)) {
      delete reviewStates[key];
    }
    pinnedKeys.clear();
    document.body.classList.remove('evidence-first');
    renderPinnedObjects();
    updatePinButton();
    delete button.dataset.confirmClear;
    button.textContent = 'Browser data cleared';
    window.setTimeout(() => {
      button.textContent = 'Clear Identity Atlas browser data';
    }, 3000);
  }

  function applyLayoutSettings() {
    document.body.classList.toggle(
      'evidence-first',
      readStoredBoolean(`${reportStorageKey}:layout:evidenceFirst`, false)
    );
  }

  function formatPropertyName(name) {
    return name
      .replace(/([a-z])([A-Z])/g, '$1 $2')
      .replace(/^./, (letter) => letter.toUpperCase());
  }

  function formatValue(value) {
    if (value === null || value === undefined || value === '') {
      return 'Not recorded';
    }
    if (Array.isArray(value)) {
      return value.length ? value.join(', ') : 'None';
    }
    if (typeof value === 'boolean') {
      return value ? 'Yes' : 'No';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }
    return String(value);
  }

  function makeElement(tagName, className, text) {
    const element = document.createElement(tagName);
    if (className) {
      element.className = className;
    }
    if (text !== undefined) {
      element.textContent = text;
    }
    return element;
  }

  function renderCoverage() {
    const manifest = report.manifest;
    if (!manifest) {
      elements.coverageBanner.classList.add('coverage-error');
      elements.coverageBanner.textContent = 'The report manifest is missing.';
      return;
    }

    elements.tenantName.textContent = manifest.tenant.displayName;
    const generated = new Date(manifest.generatedAtUtc).toLocaleString('en-GB', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: 'UTC'
    });
    const warningCount = manifest.coverage.warnings.length;
    const collectionState = manifest.coverage.status === 'complete' ? 'Collection complete' : 'Partial collection';
    const collectionSummary =
      `${manifest.counts.nodes} objects, ${manifest.counts.edges} relationships and ` +
      `${manifest.counts.evidence} evidence records.`;
    elements.collectionStatus.textContent = collectionState;
    elements.collectionSummary.textContent = collectionSummary;
    elements.collectionDate.textContent = `${generated} UTC`;
    if (manifest.dataOrigin === 'SampleFixture') {
      elements.coverageBanner.textContent =
        `Sample fixture data. Do not use this report for tenant decisions. ${collectionSummary} Generated ${generated} UTC.`;
      elements.coverageBanner.classList.add('coverage-error');
      elements.statusDot.classList.add('warning');
      return;
    }

    elements.coverageBanner.textContent =
      `${collectionState}. ${collectionSummary} Generated ${generated} UTC.` +
      (warningCount ? ` ${warningCount} coverage warning${warningCount === 1 ? '' : 's'}.` : '');
    elements.coverageBanner.classList.toggle('coverage-warning', manifest.coverage.status !== 'complete');
    elements.coverageBanner.classList.remove('coverage-error');
    elements.statusDot.classList.toggle('warning', manifest.coverage.status !== 'complete');
  }

  const viewLabels = {
    overview: {
      title: 'Tenant administration',
      eyebrow: 'OVERVIEW',
      subtitle: 'Review upcoming deadlines, responsibility gaps and collection issues.',
      empty: 'No objects were collected in this report.'
    },
    identities: {
      title: 'Identities',
      eyebrow: 'IDENTITIES',
      subtitle: 'Inspect collected users and guest users.',
      empty: 'No users were collected in this report. Regenerate the report with User.Read.All.'
    },
    groups: {
      title: 'Groups',
      eyebrow: 'GROUPS',
      subtitle: 'Inspect collected Microsoft Entra groups and direct memberships.',
      empty: 'No groups were collected in this report. Regenerate the report with Group.Read.All.'
    },
    applications: {
      title: 'Applications',
      eyebrow: 'APPLICATIONS',
      subtitle: 'Inspect collected enterprise applications, app registrations, owners, credentials and permissions.',
      empty: 'No applications were collected in this report. Regenerate the report with Application.Read.All using Identity Atlas v0.3.0 or later.'
    },
    roles: {
      title: 'Roles',
      eyebrow: 'ROLES',
      subtitle: 'Inspect collected directory roles and active assignments.',
      empty: 'No directory roles were collected in this report. Regenerate the report with RoleManagement.Read.Directory.'
    },
    policies: {
      title: 'Policies',
      eyebrow: 'POLICIES',
      subtitle: 'Inspect Conditional Access and application management policies.',
      empty: 'No policy objects were collected. Ensure the signed-in account has Policy.Read.All and a supported Microsoft Entra role, then regenerate the report.'
    },
    external: {
      title: 'External access',
      eyebrow: 'EXTERNAL ACCESS',
      subtitle: 'Inspect default and partner-specific cross-tenant access settings.',
      empty: 'No cross-tenant access settings were collected in this report.'
    },
    governance: {
      title: 'Identity Governance',
      eyebrow: 'GOVERNANCE',
      subtitle: 'Inspect Administrative Units, access packages, PIM assignments and Access Reviews.',
      empty: 'No governance objects were collected. Regenerate the report with the Governance collection profile.'
    },
    insights: {
      title: 'Insights',
      eyebrow: 'INSIGHTS',
      subtitle: 'Answer common Microsoft Entra administration questions from the collected graph.',
      empty: 'No insight results were found in the collected data.'
    },
    timeline: {
      title: 'Timeline',
      eyebrow: 'TIMELINE',
      subtitle: 'Review important dates, report changes and time-sensitive findings.',
      empty: 'No timeline events were found in this report.'
    },
    settings: {
      title: 'Settings',
      eyebrow: 'SETTINGS',
      subtitle: 'Inspect report options, contact support and export behaviour.',
      empty: 'No settings are available.'
    },
    access: {
      title: 'Access explorer',
      eyebrow: 'ACCESS EXPLORER',
      subtitle: 'Explore why the selected identity has access.',
      empty: 'No objects match the current access explorer filter.'
    }
  };

  let activeView = 'access';

  function renderSummaryCards() {
    const counts = new Map();
    for (const node of report.nodes) {
      counts.set(node.Kind, (counts.get(node.Kind) || 0) + 1);
    }

    elements.summaryCards.replaceChildren();
    for (const [kind, label] of [
      ['user', 'Users'],
      ['group', 'Groups'],
      ['servicePrincipal', 'Applications'],
      ['conditionalAccessPolicy', 'Policies'],
      ['roleDefinition', 'Roles'],
      ['device', 'Devices']
    ]) {
      const card = makeElement('div', 'summary-card');
      card.append(
        makeElement('span', 'summary-label', label),
        makeElement('span', 'summary-value', String(counts.get(kind) || 0))
      );
      elements.summaryCards.append(card);
    }
  }

  function nodeRelationships(nodeKey) {
    return [...(outgoing.get(nodeKey) || []), ...(incoming.get(nodeKey) || [])];
  }

  function openNodeButton(node, metaText) {
    const button = makeElement('button', 'relationship-item');
    button.type = 'button';
    button.dataset.nodeKey = node.Key;
    button.append(
      makeElement('span', 'relationship-name', node.DisplayName),
      makeElement('span', 'relationship-meta', metaText || formatKind(node.Kind))
    );
    button.addEventListener('click', () => selectNode(node.Key));
    return button;
  }

  function appendRelationshipButtons(section, edgeItems) {
    const list = makeElement('div', 'blast-radius-list');
    for (const item of edgeItems.slice(0, 12)) {
      const node = item.node;
      if (!node) {
        continue;
      }
      list.append(openNodeButton(node, item.meta));
    }
    if (edgeItems.length > 12) {
      list.append(makeElement('p', 'muted-text', `${edgeItems.length - 12} more related object${edgeItems.length - 12 === 1 ? '' : 's'} not shown.`));
    }
    section.append(list);
  }

  function renderBlastRadiusSection(node) {
    let items = [];
    let description = '';

    if (node.Kind === 'apiPermission') {
      items = inboundRelationships(node.Key, 'requiresApiPermission').map((edge) => ({
        node: nodesByKey.get(edge.From),
        meta: `Requires ${node.DisplayName}`
      }));
      description = 'Applications requesting this API permission in their registration. This is not evidence that consent was granted.';
    }
    else if (['application', 'servicePrincipal'].includes(node.Kind)) {
      const permissionItems = outboundRelationships(node.Key, 'requiresApiPermission').map((edge) => ({
        node: nodesByKey.get(edge.To),
        meta: 'Required API permission'
      }));
      const assignmentItems = inboundRelationships(node.Key, 'assignedAppRole').map((edge) => ({
        node: nodesByKey.get(edge.From),
        meta: edge.State?.appRoleDisplayName ? `Assigned app role: ${edge.State.appRoleDisplayName}` : 'Assigned app role'
      }));
      const ownerItems = outboundRelationships(node.Key, 'ownedBy').map((edge) => ({
        node: nodesByKey.get(edge.To),
        meta: 'Application owner'
      }));
      const consentItems = outboundRelationships(node.Key, 'hasDelegatedConsent').map((edge) => ({ node: nodesByKey.get(edge.To), meta: `${edge.State.consentType}: ${edge.State.scope}` }));
      const apiAssignments = outboundRelationships(node.Key, 'assignedAppRole').map((edge) => ({ node: nodesByKey.get(edge.To), meta: `Granted application role: ${edge.State?.appRoleDisplayName || edge.State?.appRoleId || 'Unresolved role'}` }));
      items = [...consentItems, ...apiAssignments, ...permissionItems, ...assignmentItems, ...ownerItems];
      description = 'Requested permissions, granted consent, app role assignments and ownership are separate relationships. Delegated consent remains subject to the signed-in user permissions. Missing consent data is not proof of no consent.';
    }
    else if (node.Kind === 'oauth2PermissionGrant') {
      items = [...inboundRelationships(node.Key, 'hasDelegatedConsent'), ...inboundRelationships(node.Key, 'subjectOfDelegatedConsent')].map((edge) => ({ node: nodesByKey.get(edge.From), meta: formatRelationship(edge.Relationship) }));
      items.push(...outboundRelationships(node.Key, 'grantsDelegatedScopes').map((edge) => ({ node: nodesByKey.get(edge.To), meta: `Granted scopes: ${edge.State.scope}` })));
      description = `${node.Properties.consentType === 'AllPrincipals' ? 'Tenant-wide delegated consent' : 'Individual delegated consent'}. This is consent evidence, not proof of every user being able to access every resource.`;
    }
    else if (node.Kind === 'roleDefinition') {
      items = [...inboundRelationships(node.Key, 'assignedRole'), ...inboundRelationships(node.Key, 'eligibleRole')].map((edge) => ({
        node: nodesByKey.get(edge.From),
        meta: formatRelationship(edge.Relationship)
      }));
      description = 'Principals with collected active or eligible access to this directory role.';
    }
    else if (node.Kind === 'conditionalAccessPolicy') {
      items = [...inboundRelationships(node.Key, 'conditionalAccessIncludes'), ...inboundRelationships(node.Key, 'conditionalAccessExcludes')].map((edge) => ({
        node: nodesByKey.get(edge.From),
        meta: formatRelationship(edge.Relationship)
      }));
      description = 'Collected principals and groups that are included in or excluded from this policy.';
    }

    if (!items.length) {
      return null;
    }

    const section = makeElement('section', 'evidence-card');
    section.append(
      makeElement('h5', null, 'Permission blast radius'),
      makeElement('p', 'path-narrative', description)
    );
    appendRelationshipButtons(section, items);
    return section;
  }

  function conditionalAccessImpactItems(node) {
    const direct = [...outboundRelationships(node.Key, 'conditionalAccessIncludes'), ...outboundRelationships(node.Key, 'conditionalAccessExcludes')]
      .map((edge) => ({ node: nodesByKey.get(edge.To), meta: formatRelationship(edge.Relationship) }));
    const groupBased = [];

    if (['user', 'guestUser', 'servicePrincipal', 'application'].includes(node.Kind)) {
      for (const membership of outboundRelationships(node.Key, 'memberOf')) {
        const group = nodesByKey.get(membership.To);
        for (const edge of [
          ...outboundRelationships(membership.To, 'conditionalAccessIncludes'),
          ...outboundRelationships(membership.To, 'conditionalAccessExcludes')
        ]) {
          groupBased.push({
            node: nodesByKey.get(edge.To),
            meta: `${formatRelationship(edge.Relationship)} through ${group ? group.DisplayName : 'group'}`
          });
        }
      }
    }

    if (node.Kind === 'conditionalAccessPolicy') {
      return [...inboundRelationships(node.Key, 'conditionalAccessIncludes'), ...inboundRelationships(node.Key, 'conditionalAccessExcludes')]
        .map((edge) => ({ node: nodesByKey.get(edge.From), meta: formatRelationship(edge.Relationship) }));
    }

    return [...direct, ...groupBased];
  }

  function renderConditionalAccessImpactSection(node) {
    const items = conditionalAccessImpactItems(node).filter((item) => item.node);
    if (!items.length || !['user', 'guestUser', 'group', 'servicePrincipal', 'application', 'conditionalAccessPolicy'].includes(node.Kind)) {
      return null;
    }

    const section = makeElement('section', 'evidence-card');
    section.append(
      makeElement('h5', null, 'Conditional Access impact simulator'),
      makeElement('p', 'path-narrative', 'This uses collected direct and group-based policy assignment paths. It does not evaluate live sign-in risk, device state or session controls.')
    );
    appendRelationshipButtons(section, items);
    return section;
  }

  function collectGroupDependencies(nodeKey, maximum = 500) {
    const limit = Math.min(500, Math.max(1, Number.isFinite(maximum) ? Math.floor(maximum) : 500));
    const node = nodesByKey.get(nodeKey);
    if (!node || node.Kind !== 'group') return null;
    const categories = {
      assignments: { title: 'Role and application assignments', items: [] },
      inclusions: { title: 'Conditional Access inclusions', items: [] },
      exclusions: { title: 'Conditional Access exclusions', items: [] },
      membership: { title: 'Membership and PIM relationships', items: [] },
      governance: { title: 'Governance and review relationships', items: [] },
      context: { title: 'Other collected relationships', items: [] }
    };
    // Walk the existing adjacency indexes, not the whole tenant graph. These
    // are direct dependencies, never a claim of transitive effective access.
    const total = (outgoing.get(nodeKey) || []).length + (incoming.get(nodeKey) || []).length;
    let examined = 0;
    for (const list of [outgoing.get(nodeKey) || [], incoming.get(nodeKey) || []]) {
      for (const edge of list) {
        if (examined >= limit) break;
        examined++;
        const outward = edge.From === nodeKey;
        const relatedKey = outward ? edge.To : edge.From;
        const related = nodesByKey.get(relatedKey);
        const relation = edge.Relationship;
        let category = 'context';
        if (outward && ['assignedRole', 'eligibleRole', 'assignedAppRole'].includes(relation)) category = 'assignments';
        else if (outward && relation === 'conditionalAccessIncludes') category = 'inclusions';
        else if (outward && relation === 'conditionalAccessExcludes') category = 'exclusions';
        else if (['memberOf', 'pimActiveMember', 'pimEligibleMember', 'pimActiveOwner', 'pimEligibleOwner'].includes(relation)) category = 'membership';
        else if (['coveredByAccessReview', 'reviewedInAccessReview', 'resourceReviewedInAccessReview', 'grantsEntitlementResourceRole', 'memberOfAdministrativeUnit', 'administersAdministrativeUnit'].includes(relation)) category = 'governance';
        const evidenceIds = Array.isArray(edge.EvidenceIds) ? edge.EvidenceIds : [];
        categories[category].items.push({
          edgeKey: edge.Key, relatedKey, relatedName: related?.DisplayName || relatedKey,
          relationship: relation, direction: outward ? 'Outgoing' : 'Incoming',
          evidenceIds,
          evidenceComplete: !!related && evidenceIds.length > 0 && evidenceIds.every((id) => evidenceByKey.get(id)?.Completeness === 'complete'),
          state: edge.State || {}
        });
      }
    }
    return { categories, total, examined, truncated: total > examined, observedAt: report.manifest.generatedAtUtc };
  }

  function renderGroupDependenciesSection(node) {
    const result = collectGroupDependencies(node.Key);
    if (!result) return null;
    const section = makeElement('section', 'evidence-card');
    section.append(
      makeElement('h3', null, 'Group dependency inspector'),
      makeElement('p', 'path-narrative', 'Direct collected relationships only. Policy exclusion is not an access grant. Membership, ownership and eligibility have different meanings; nested membership does not prove inherited application or directory-role access.'),
      makeElement('p', 'muted-text', `Report observed at ${result.observedAt}. ${result.examined} of ${result.total} adjacent relationship records inspected. Dependencies outside collection coverage are unknown.`)
    );
    if (result.truncated) section.append(makeElement('p', null, 'Inspection limited to 500 records. Counts below describe inspected records only, not the whole group.'));
    if (!result.total) section.append(makeElement('p', null, 'No direct dependency was collected. This is not proof that the group is unused or safe to delete.'));
    for (const category of Object.values(result.categories)) {
      if (!category.items.length) continue;
      const details = makeElement('details');
      details.append(makeElement('summary', null, `${category.title}: ${category.items.length}`));
      for (const item of category.items.slice(0, 50)) {
        const row = makeElement('section', 'evidence-card');
        row.append(makeElement('p', null, `${item.direction}: ${formatRelationship(item.relationship)} > ${item.relatedName}`));
        if (item.relationship === 'conditionalAccessExcludes') row.append(makeElement('p', null, 'Changing this relationship could change policy scope. A sign-in outcome is not evaluated.'));
        if (['pimActiveOwner', 'pimEligibleOwner'].includes(item.relationship)) row.append(makeElement('p', null, 'Ownership is context, not membership.'));
        if (['eligibleRole', 'pimEligibleMember', 'pimEligibleOwner'].includes(item.relationship)) row.append(makeElement('p', null, 'Eligibility requires activation; it is not standing active access.'));
        row.append(makeElement('p', 'muted-text', item.evidenceComplete ? 'Linked evidence records are complete. This does not establish effective access.' : 'Evidence is missing, partial or unresolved.'));
        const related = nodesByKey.get(item.relatedKey);
        if (related) row.append(openNodeButton(related, 'Inspect connected object'));
        const evidenceDetails = makeElement('details');
        evidenceDetails.append(makeElement('summary', null, 'Relationship evidence'));
        evidenceDetails.append(makeElement('pre', null, JSON.stringify({ relationship: item.edgeKey, state: item.state, evidence: item.evidenceIds.map((id) => {
          const evidence = evidenceByKey.get(id);
          return { id, collector: evidence?.Collector, endpoint: evidence?.Endpoint, observedAt: evidence?.CollectedAtUtc, completeness: evidence?.Completeness || 'Missing' };
        }) }, null, 2)));
        row.append(evidenceDetails);
        details.append(row);
      }
      if (category.items.length > 50) details.append(makeElement('p', null, 'First 50 inspected records shown in this category. Full source evidence remains in the report.'));
      section.append(details);
    }
    return section;
  }

  function createAccessAnalysis(snapshot) {
    if (!snapshot?.manifest?.tenant?.id || !Array.isArray(snapshot.nodes) || !Array.isArray(snapshot.edges) || !Array.isArray(snapshot.evidence)) throw new Error('Invalid tenant snapshot structure.');
    const nodes = new Map(snapshot.nodes.map(n => [n.Key, n]));
    const evidence = new Map(snapshot.evidence.map(e => [e.Key, e]));
    const out = new Map();
    const incomingIndex = new Map();
    for (const edge of snapshot.edges) {
      if (!out.has(edge.From)) out.set(edge.From, []);
      if (!incomingIndex.has(edge.To)) incomingIndex.set(edge.To, []);
      out.get(edge.From).push(edge);
      incomingIndex.get(edge.To).push(edge);
    }
    const at = Date.parse(snapshot.manifest.generatedAtUtc);
    const label = key => nodes.get(key)?.DisplayName || key;
    const proof = edge => nodes.has(edge.From) && nodes.has(edge.To) &&
      nodes.get(edge.From).Status === 'complete' && nodes.get(edge.To).Status === 'complete' &&
      edge.EvidenceIds?.length > 0 && edge.EvidenceIds.every(id => evidence.get(id)?.Completeness === 'complete');
    function timing(state = {}) {
      for (const field of ['startDateTime', 'endDateTime']) {
        if (state[field] && !Number.isFinite(Date.parse(state[field]))) return 'Unknown timing';
      }
      if (!Number.isFinite(at)) return 'Unknown timing';
      if (state.startDateTime && Date.parse(state.startDateTime) > at) return 'Future';
      if (state.endDateTime && Date.parse(state.endDateTime) <= at) return 'Expired';
      return 'Observed';
    }
    function routes(source, omitted = null) {
      const paths = [];
      let inspected = 0;
      let truncated = false;
      const sourceNode = nodes.get(source);
      if (!sourceNode) return { paths, truncated: false };
      const add = edges => {
        const terminal = edges.at(-1);
        const state = terminal.State || {};
        const targetKind = nodes.get(terminal.To)?.Kind;
        if (['assignedRole', 'eligibleRole'].includes(terminal.Relationship) && targetKind !== 'roleDefinition') return;
        if (terminal.Relationship === 'assignedAppRole' && targetKind !== 'servicePrincipal') return;
        const states = edges.map(e => {
          const schedules = e.State?.scheduleInstances;
          if (e.Relationship === 'assignedRole' && schedules?.length) {
            const scheduleStates = schedules.map(timing);
            return scheduleStates.includes('Observed') ? 'Observed' : scheduleStates.every(s => s === 'Expired') ? 'Expired' : 'Unknown timing';
          }
          return timing(e.State);
        });
        const temporal = states.find(s => s !== 'Observed') || 'Observed';
        const eligible = edges.some(e => ['eligibleRole', 'pimEligibleMember'].includes(e.Relationship));
        const type = temporal !== 'Observed' ? temporal : eligible ? 'Eligible: activation required' : 'Observed assignment';
        const permission = terminal.Relationship === 'assignedAppRole' ? state.appRoleId : null;
        const scope = ['assignedRole', 'eligibleRole'].includes(terminal.Relationship) ? state.directoryScopeId : null;
        const complete = edges.every(proof) && (terminal.Relationship !== 'assignedAppRole' || Boolean(permission)) &&
          (!['assignedRole', 'eligibleRole'].includes(terminal.Relationship) || typeof scope === 'string');
        paths.push({ target: terminal.To, targetName: label(terminal.To), entitlement: JSON.stringify([terminal.To, permission, scope, state.appScopeId || null]),
          identity: JSON.stringify(edges.map(e => [e.From, e.To, e.Relationship, e.State?.appRoleId || null, e.State?.directoryScopeId || null, e.State?.appScopeId || null])),
          edgeKeys: edges.map(e => e.Key), type, complete, state, description: [label(source), ...edges.map(e => `${e.Relationship} > ${label(e.To)}`)].join(' > ') });
      };
      // One group hop only: nested groups do not inherit enterprise application or directory role assignments.
      for (const edge of out.get(source) || []) {
        if (++inspected > 5000 || paths.length >= 500) { truncated = true; break; }
        if (edge.Key === omitted) continue;
        if (['assignedAppRole', 'assignedRole', 'eligibleRole'].includes(edge.Relationship)) add([edge]);
        if (['memberOf', 'pimActiveMember', 'pimEligibleMember'].includes(edge.Relationship) && nodes.get(edge.To)?.Kind === 'group') add([edge]);
        if (['user', 'guestUser'].includes(sourceNode.Kind) && ['memberOf', 'pimActiveMember', 'pimEligibleMember'].includes(edge.Relationship) && nodes.get(edge.To)?.Kind === 'group') {
          for (const assignment of out.get(edge.To) || []) {
            if (++inspected > 5000 || paths.length >= 500) { truncated = true; break; }
            if (assignment.Key !== omitted && ['assignedAppRole', 'assignedRole', 'eligibleRole'].includes(assignment.Relationship)) add([edge, assignment]);
          }
        }
      }
      return { paths, truncated };
    }
    function completeCoverage(other) {
      const a = snapshot.manifest.coverage;
      const b = other.manifest.coverage;
      const collectors = c => JSON.stringify((c?.collectors || []).map(x => [x.name, x.status]).sort());
      return a?.status === 'complete' && b?.status === 'complete' && a.collectors?.length > 0 &&
        a.collectors.every(c => c.status === 'complete') && b.collectors?.every(c => c.status === 'complete') && collectors(a) === collectors(b) && collectedAfter(Date.parse(other.manifest.generatedAtUtc));
    }
    function collectedAfter(boundary) {
      const collectors = (snapshot.manifest.coverage?.collectors || []).filter(c => c.name !== 'permissionPreflight');
      return collectors.length > 0 && collectors.every(c => {
        const start = Date.parse(c.metrics?.collectionStartedAtUtc);
        const end = Date.parse(c.metrics?.collectionCompletedAtUtc);
        return Number.isFinite(start) && Number.isFinite(end) && start > boundary && end >= start && end <= at;
      });
    }
    function compare(previous, source) {
      if (previous.manifest?.tenant?.id !== snapshot.manifest.tenant.id || !snapshot.manifest.tenant.id) throw new Error('Snapshots must belong to the same tenant.');
      if (previous.manifest.schemaVersion !== snapshot.manifest.schemaVersion) throw new Error('Snapshot schemas must match.');
      const beforeTime = Date.parse(previous.manifest.generatedAtUtc);
      if (!Number.isFinite(beforeTime) || !Number.isFinite(at) || beforeTime >= at) throw new Error('Choose a strictly earlier snapshot with a valid collection timestamp.');
      const before = createAccessAnalysis(previous).routes(source);
      const after = routes(source);
      const removed = before.paths.filter(p => !after.paths.some(q => q.identity === p.identity));
      const verified = completeCoverage(previous) && !before.truncated && !after.truncated;
      return { verified, truncated: before.truncated || after.truncated, searchScope: 'Direct memberships, direct role/application assignments and one group hop. Other mechanisms are outside this verification.',
        conclusions: removed.map(p => ({ path: p.description, entitlement: p.entitlement,
          result: verified && p.complete ? 'Collected path removed' : 'Unable to verify removal: path no longer observed',
          alternatives: after.paths.filter(q => q.entitlement === p.entitlement && q.type === 'Observed assignment').map(q => q.description),
          eligible: after.paths.filter(q => q.entitlement === p.entitlement && q.type.startsWith('Eligible')).map(q => q.description) })),
        remaining: after.paths, caveat: 'Configuration evidence only. Removing an assignment does not prove that tokens were revoked or existing application sessions ended. Absence of supported paths does not prove absence of every access mechanism.' };
    }
    function reviews(previous, source) {
      const comparison = compare(previous, source);
      const previousEdges = previous.edges.filter(e => e.From === source && e.Relationship === 'reviewedInAccessReview');
      const decisionKey = e => JSON.stringify([e.From, e.To, e.State?.resourceId, e.State?.decisionId || 'legacy']);
      const decisions = new Map(previousEdges.map(e => [decisionKey(e), e]));
      for (const e of out.get(source) || []) if (e.Relationship === 'reviewedInAccessReview') decisions.set(decisionKey(e), e);
      return [...decisions.values()].slice(0, 100).map(edge => {
        const state = edge.State || {};
        const resource = [...nodes.values()].find(n => n.Id === state.resourceId);
        let result = 'Unable to verify';
        let explanation = 'The decision must be Deny, identify an exact resource, and have application and chronological assignment evidence.';
        if (state.decision === 'Deny' && ['New', 'NotApplied'].includes(state.applyResult)) {
          result = 'Decision pending application';
          explanation = `Collected apply result: ${state.applyResult || 'missing'}. No removal is confirmed.`;
        } else if (state.decision === 'Deny' && resource && Number.isFinite(Date.parse(state.appliedDateTime)) && Date.parse(state.appliedDateTime) < at) {
          const removed = comparison.conclusions.filter(c => JSON.parse(c.entitlement)[0] === resource.Key);
          const earlierPaths = createAccessAnalysis(previous).routes(source).paths.filter(p => p.target === resource.Key);
          // A review resource alone does not identify one of several app roles. Do not guess.
          if (removed.length === 1 && earlierPaths.filter(p => p.edgeKeys.length === 1).length === 1 &&
              earlierPaths.find(p => p.description === removed[0].path)?.edgeKeys.length === 1 &&
              Date.parse(state.appliedDateTime) > Date.parse(previous.manifest.generatedAtUtc) &&
              collectedAfter(Date.parse(state.appliedDateTime)) &&
              removed[0].result === 'Collected path removed' && proof(edge)) {
            result = removed[0].alternatives.length ? 'Alternative path remains' : 'Reviewed path removed';
            explanation = `${removed[0].path}. ${removed[0].eligible.length ? 'Eligible PIM routes remain.' : 'No eligible route observed by the supported search.'}`;
          }
        }
        return { review: label(edge.To), resource: resource?.DisplayName || state.resourceId || 'Missing resource', result, explanation, state, evidenceIds: edge.EvidenceIds };
      });
    }
    function dynamic(group, person) {
      const rule = nodes.get(group)?.Properties?.membershipRule;
      const subject = nodes.get(person);
      const observed = (out.get(person) || []).some(e => e.Relationship === 'memberOf' && e.To === group);
      const conditions = [];
      if (typeof rule !== 'string' || rule.length > 4096 || !['user', 'guestUser'].includes(subject?.Kind)) return { result: 'Unevaluated', observed, conditions };
      // Deliberately limited grammar. No eval, regex operators, collection operators or guessed attributes.
      const tokenPattern = /\s*(\(|\)|-and\b|-or\b|user\.[a-zA-Z]+|-(?:eq|ne)\b|true\b|false\b|null\b|"[^"\\]*")/gy;
      const tokens = [];
      let position = 0;
      while (position < rule.trimEnd().length) {
        tokenPattern.lastIndex = position;
        const match = tokenPattern.exec(rule);
        if (!match) return { rule, result: 'Unevaluated: unsupported expression', observed, conditions: [] };
        tokens.push(match[1]); position = tokenPattern.lastIndex;
        if (tokens.length > 256) return { rule, result: 'Unevaluated: expression limit', observed, conditions: [] };
      }
      let cursor = 0;
      const attributes = ['department', 'accountEnabled', 'userType', 'jobTitle', 'companyName', 'country', 'city', 'officeLocation', 'userPrincipalName'];
      function atom(depth) {
        if (depth > 20) throw new Error('Expression limit');
        if (tokens[cursor] === '(') { cursor++; const value = expression(depth + 1); if (tokens[cursor++] !== ')') throw new Error('Unbalanced expression'); return value; }
        const attribute = tokens[cursor++]?.replace(/^user\./, '');
        const operator = tokens[cursor++];
        const literal = tokens[cursor++];
        if (!attributes.includes(attribute) || !['-eq', '-ne'].includes(operator) || !/^(true|false|null|"[^"\\]*")$/.test(literal || '')) throw new Error('Unsupported expression');
        const expected = JSON.parse(literal);
        const properties = subject.Properties || {};
        const value = properties[attribute];
        let outcome = null;
        if (Object.hasOwn(properties, attribute)) {
          outcome = typeof value === 'string' && typeof expected === 'string' ? value.toLowerCase() === expected.toLowerCase() : value === expected;
          if (operator === '-ne') outcome = !outcome;
        }
        conditions.push({ attribute, operator, expected, collected: value === undefined ? 'Not collected' : value, outcome });
        return outcome;
      }
      function and(depth) { let value = atom(depth); while (tokens[cursor] === '-and') { cursor++; const right = atom(depth); value = value === false || right === false ? false : value === null || right === null ? null : true; } return value; }
      function expression(depth) { let value = and(depth); while (tokens[cursor] === '-or') { cursor++; const right = and(depth); value = value === true || right === true ? true : value === null || right === null ? null : false; } return value; }
      try {
        const value = expression(0);
        if (cursor !== tokens.length) throw new Error('Unsupported expression');
        return { rule, result: value === null ? 'Unevaluated: missing attributes' : value ? 'Calculated match' : 'Calculated non-match', observed, conditions,
          downstream: routes(person).paths.filter(p => p.edgeKeys.some(k => (out.get(person) || []).some(e => e.Key === k && e.To === group))) };
      } catch { return { rule, result: 'Unevaluated: unsupported expression', observed, conditions: [] }; }
    }
    function pim(role) {
      const rows = [];
      const roleEdges = incomingIndex.get(role) || [];
      let limited = roleEdges.length > 500;
      for (const edge of roleEdges.slice(0, 500)) {
        if (rows.length >= 500) { limited = true; break; }
        if (!['assignedRole', 'eligibleRole'].includes(edge.Relationship)) continue;
        const state = edge.State || {};
        const instances = state.scheduleInstances || [];
        const current = instances.filter(s => timing(s) === 'Observed');
        const category = edge.Relationship === 'eligibleRole' ? `Eligible: ${timing(state)}` : current.some(s => s.assignmentType === 'Assigned') ? 'Standing active assignment' : current.some(s => s.assignmentType === 'Activated') ? 'PIM activation' : 'Active assignment: standing or activated unknown';
        const row = { principal: label(edge.From), principalKey: edge.From, category, scope: state.directoryScopeId || 'Missing scope', appScope: state.appScopeId || null, expiry: state.endDateTime || current.map(s => s.endDateTime || 'No end date').join(', ') || 'Not collected', complete: proof(edge), evidenceIds: edge.EvidenceIds };
        rows.push(row);
        if (nodes.get(edge.From)?.Kind === 'group') {
          if ((incomingIndex.get(edge.From) || []).length > 500) limited = true;
          for (const membership of (incomingIndex.get(edge.From) || []).slice(0, 500)) {
            if (rows.length >= 500) { limited = true; break; }
            if (!['user', 'guestUser'].includes(nodes.get(membership.From)?.Kind) || !['memberOf', 'pimActiveMember', 'pimEligibleMember'].includes(membership.Relationship)) continue;
            const eligibleMembership = membership.Relationship === 'pimEligibleMember';
            const membershipTiming = timing(membership.State);
            rows.push({ ...row, principal: label(membership.From), principalKey: membership.From,
              viaGroup: label(edge.From), category: membershipTiming !== 'Observed' ? membershipTiming : eligibleMembership ? 'Eligible: group activation required' : membership.Relationship === 'pimActiveMember' && category === 'Standing active assignment' ? 'Group active membership: standing or activated unknown' : category,
              complete: row.complete && proof(membership), evidenceIds: [...(row.evidenceIds || []), ...(membership.EvidenceIds || [])] });
            const groupPimCollected = snapshot.manifest.coverage?.collectors?.some(c => c.name === 'pimGroups' && c.status === 'complete');
            const hasPimMembership = (out.get(membership.From) || []).some(e => e.To === edge.From && e.Relationship === 'pimActiveMember');
            if (membership.Relationship === 'memberOf' && rows.at(-1).category === 'Standing active assignment' && (!groupPimCollected || hasPimMembership)) {
              rows.at(-1).category = 'Group membership: standing or activated unknown';
            }
          }
        }
      }
      const policies = nodes.get(role)?.Properties?.pimPolicies || [];
      const requirements = policies.map(p => ({ policyId: p.policyId, scope: p.scopeId, complete: evidence.get(p.evidenceId)?.Completeness === 'complete', evidenceId: p.evidenceId,
        activationRules: (p.rules || []).filter(r => r.target?.caller === 'EndUser' && r.target?.level === 'Assignment').map(r => ({ id: r.id, type: r['@odata.type'], approval: r.setting?.isApprovalRequired, authentication: r.enabledRules, authenticationContext: r.isEnabled ? r.claimValue : undefined, maximumDuration: r.maximumDuration, expirationRequired: r.isExpirationRequired })) }));
      const alternatives = rows.filter(a => a.category.startsWith('Eligible: Observed') || a.category === 'Eligible: group activation required').flatMap(a => rows.filter(b => b.principalKey === a.principalKey && b.scope === a.scope && a.scope !== 'Missing scope' && b.appScope === a.appScope && b.category === 'Standing active assignment' && a.complete && b.complete).map(() => `${a.principal} has eligible and standing active assignments at scope ${a.scope}.`));
      return { rows: rows.slice(0, 500), truncated: limited || rows.length > 500, requirements, alternatives: alternatives.slice(0, 100), warning: 'Missing policy or schedule evidence is unknown, not proof of no protection. Group membership activation policies are not inferred from role policies. Requirements describe configuration, not proof that a particular activation satisfied them.' };
    }
    function preview(group, membershipKey) {
      const membership = snapshot.edges.find(e => e.Key === membershipKey && e.To === group && e.Relationship === 'memberOf');
      if (!membership) throw new Error('Choose an observed direct membership.');
      const before = routes(membership.From);
      const after = routes(membership.From, membershipKey);
      const affected = before.paths.filter(p => p.edgeKeys.includes(membershipKey));
      return { removed: affected, remaining: after.paths.filter(p => affected.some(a => a.entitlement === p.entitlement)),
        policyChanges: (out.get(group) || []).filter(e => ['conditionalAccessIncludes', 'conditionalAccessExcludes'].includes(e.Relationship)).map(e => ({ policy: label(e.To), consequence: e.Relationship === 'conditionalAccessExcludes' ? 'This membership would no longer supply this Conditional Access exclusion.' : 'This membership would no longer supply this Conditional Access inclusion.', evidenceIds: e.EvidenceIds })),
        truncated: before.truncated || after.truncated, warning: 'Local hypothetical change only. No tenant changes. Other policy scopes, nested memberships and live sign-in conditions may change the outcome. Dynamic membership can be restored by rule processing.' };
    }
    function dossier(key) {
      const selected = nodes.get(key);
      const registration = selected?.Kind === 'application' ? selected : [...nodes.values()].find(n => n.Kind === 'application' && n.Properties?.appId && n.Properties.appId === selected?.Properties?.appId);
      const principal = selected?.Kind === 'servicePrincipal' ? selected : [...nodes.values()].find(n => n.Kind === 'servicePrincipal' && n.Properties?.appId && n.Properties.appId === selected?.Properties?.appId);
      const requested = (out.get(registration?.Key) || []).filter(e => e.Relationship === 'requiresApiPermission').map(e => ({ ...nodes.get(e.To)?.Properties, evidenceIds: e.EvidenceIds }));
      const grants = [];
      for (const edge of out.get(principal?.Key) || []) {
        if (edge.Relationship === 'assignedAppRole') {
          const resource = nodes.get(edge.To);
          const permission = resource?.Properties?.appRoles?.find(p => p?.id === edge.State?.appRoleId);
          grants.push({ resourceAppId: resource?.Properties?.appId, resource: label(edge.To), resourceAccessId: edge.State?.appRoleId, permissionType: 'Role', name: permission?.value || edge.State?.appRoleId, description: permission?.description || 'Description not collected', consent: 'Application permission', evidenceIds: edge.EvidenceIds });
        }
        if (edge.Relationship === 'hasDelegatedConsent') {
          const state = edge.State || {};
          const resource = [...nodes.values()].find(n => n.Id === state.resourceId && n.Kind === 'servicePrincipal');
          for (const scope of (state.scope || '').split(/\s+/).filter(Boolean)) {
            const permission = resource?.Properties?.oauth2PermissionScopes?.find(p => p?.value === scope);
            grants.push({ resourceAppId: resource?.Properties?.appId, resource: resource?.DisplayName || state.resourceId, resourceAccessId: permission?.id, permissionType: 'Scope', name: scope, description: permission?.adminConsentDescription || 'Description not collected', consent: state.consentType === 'AllPrincipals' ? 'Tenant-wide delegated consent' : `Individual-user delegated consent: ${state.principalId || 'unresolved'}`, evidenceIds: edge.EvidenceIds });
          }
        }
      }
      const matches = (a, b) => a.resourceAppId && a.resourceAccessId && a.resourceAppId === b.resourceAppId && a.resourceAccessId === b.resourceAccessId && a.permissionType === b.permissionType;
      const context = [registration?.Key, principal?.Key].filter(Boolean).flatMap(k => (out.get(k) || []).filter(e => ['ownedBy', 'hasCredential'].includes(e.Relationship)).map(e => ({ relationship: e.Relationship, name: label(e.To), properties: nodes.get(e.To)?.Properties, evidenceIds: e.EvidenceIds })));
      return { requestedListEvidence: registration ? 'App registration collected; inspect registration coverage before treating omissions as absence.' : 'App registration not collected. Its requested list is unavailable, not empty.',
        delegatedConsentEvidence: snapshot.manifest.coverage?.collectors?.find(c => c.name === 'delegatedConsent')?.status || 'Not collected. Use IncludeConsent during collection.',
      requested: requested.map(r => {
        if (!['Role', 'Scope'].includes(r.permissionType)) return { ...r, result: 'Unevaluated: unsupported permission type', warning: 'Raw permission type retained. No grant matching attempted for this request.' };
        const resource = [...nodes.values()].find(n => n.Kind === 'servicePrincipal' && n.Properties?.appId === r.resourceAppId);
        const definition = (r.permissionType === 'Role' ? resource?.Properties?.appRoles : resource?.Properties?.oauth2PermissionScopes)?.find(p => p?.id === r.resourceAccessId);
        return { ...r, resource: resource?.DisplayName || r.resourceAppId, name: definition?.value || r.resourceAccessId, description: definition?.description || definition?.adminConsentDescription || 'Description not collected', result: grants.some(g => matches(r, g)) ? 'Matching collected grant' : 'No matching collected grant: not proof consent is absent' };
      }),
        grants: grants.map(g => ({ ...g, result: !registration ? 'Requested list unavailable' : !g.resourceAppId || !g.resourceAccessId ? 'Unable to match: resource permission definition missing' : requested.some(r => matches(r, g)) ? 'In requested list' : 'Not matched to current requested list' })), context,
        warning: 'Requested permissions are not grants. Delegated grants operate with a user; application grants do not. Resource-specific grants and application-side authorisation may be outside collection. No permission is automatically described as access to all tenant data. Missing resource definitions prevent exact matching.' };
    }
    return { routes, compare, reviews, dynamic, pim, preview, dossier };
  }

  function renderAnalysisValue(value, depth = 0) {
    const container = makeElement('div', 'analysis-value');
    if (depth > 6) { container.append(makeElement('p', null, 'Nested evidence omitted from this view; inspect the source report.')); return container; }
    if (Array.isArray(value)) {
      if (!value.length) container.append(makeElement('p', 'muted-text', 'None observed in this result.'));
      for (const item of value.slice(0, 100)) container.append(renderAnalysisValue(item, depth + 1));
      if (value.length > 100) container.append(makeElement('p', null, `First 100 of ${value.length} results shown.`));
    } else if (value !== null && typeof value === 'object') {
        const grid = makeElement('dl', 'property-grid');
        const technical = {};
        for (const [key, item] of Object.entries(value)) {
          if (['target', 'principalKey', 'edgeKeys', 'entitlement', 'identity', 'evidenceIds', 'evidenceId', 'resourceAccessId', 'resourceAppId', 'policyId'].includes(key)) { technical[key] = item; continue; }
        grid.append(makeElement('dt', null, key === 'complete' ? 'Relationship evidence complete' : formatPropertyName(key)));
        const cell = makeElement('dd');
        cell.append(item !== null && typeof item === 'object' ? renderAnalysisValue(item, depth + 1) : makeElement('span', null, item == null ? 'Not collected or not applicable' : typeof item === 'boolean' ? item ? 'Yes' : 'No' : String(item)));
        grid.append(cell);
      }
      container.append(grid);
      if (Object.keys(technical).length) {
        const detail = makeElement('details');
        detail.append(makeElement('summary', null, 'Evidence identifiers'), makeElement('pre', null, JSON.stringify(technical, null, 2)));
        container.append(detail);
      }
    } else container.append(makeElement('p', null, String(value)));
    return container;
  }

  function renderAccessAnalysisSection(node) {
    const section = makeElement('section', 'evidence-card');
    const analysis = accessAnalysis || (accessAnalysis = createAccessAnalysis(report));
    const show = (heading, value) => {
      const details = makeElement('details');
      details.append(makeElement('summary', null, heading), renderAnalysisValue(value));
      section.append(details);
    };
    if (node.Kind === 'roleDefinition') show('Is PIM protecting this role?', analysis.pim(node.Key));
    if (['application', 'servicePrincipal'].includes(node.Kind)) show('Application permission dossier', analysis.dossier(node.Key));
    if (node.Kind === 'group') {
      const memberships = (incoming.get(node.Key) || []).filter(e => e.Relationship === 'memberOf').slice(0, 500);
      const select = makeElement('select');
      select.setAttribute('aria-label', 'Choose observed membership for local preview');
      select.append(makeElement('option', null, 'Choose a membership'));
      select.firstChild.value = '';
      for (const e of memberships) { const option = makeElement('option', null, nodesByKey.get(e.From)?.DisplayName || e.From); option.value = e.Key; select.append(option); }
      const output = makeElement('div');
      section.append(makeElement('h3', null, 'Local membership change preview'), makeElement('p', null, 'First 500 observed direct memberships. This does not change the tenant.'), select, output);
      select.addEventListener('change', () => {
        output.replaceChildren();
        if (!select.value) return;
        output.append(renderAnalysisValue(analysis.preview(node.Key, select.value)));
        if (node.Properties?.membershipRule) {
          const member = memberships.find(e => e.Key === select.value);
          output.append(makeElement('h4', null, 'Dynamic rule explanation'), makeElement('p', null, 'Calculated results are separate from observed membership. Collection timing and processing delays can differ.'), renderAnalysisValue(analysis.dynamic(node.Key, member.From)));
        }
      });
      if (node.Properties?.membershipRule) show('Dynamic membership rule', { rule: node.Properties.membershipRule, note: 'Choose a member above. Supported: user attributes with eq/ne, and/or and parentheses. Other expressions remain unevaluated.' });
    }
    if (['user', 'guestUser', 'servicePrincipal', 'application'].includes(node.Kind)) {
      const input = makeElement('input'); input.type = 'file'; input.accept = '.json,application/json';
      input.setAttribute('aria-label', 'Earlier tenant report JSON for access verification');
      const output = makeElement('div'); output.setAttribute('aria-live', 'polite');
      const baselineLabel = makeElement('p', 'muted-text');
      const clearBaseline = makeElement('button', null, 'Clear baseline'); clearBaseline.type = 'button';
      section.append(makeElement('h3', null, 'Verify access removal and review outcomes'), makeElement('p', null, 'Choose data/report.json from an earlier snapshot of this tenant. Processing stays local. This is not a session revocation check.'), input, output);
      input.before(baselineLabel, clearBaseline);
      const renderBaseline = () => {
        output.replaceChildren();
        baselineLabel.textContent = accessBaseline ? `Loaded: ${accessBaseline.name} | ${accessBaseline.report.manifest.generatedAtUtc}. Kept in memory until cleared or this page closes.` : 'No baseline loaded.';
        clearBaseline.disabled = !accessBaseline;
        if (!accessBaseline) return;
        try {
          const source = node.Kind === 'application' ? (outgoing.get(node.Key) || []).find(e => e.Relationship === 'hasServicePrincipal')?.To : node.Key;
          if (!source) throw new Error('A collected service principal is required for this application.');
          const result = analysis.compare(accessBaseline.report, source);
          output.append(makeElement('h4', null, `${result.conclusions.length} path(s) no longer observed`));
          const incomplete = [...new Set([report, accessBaseline.report].flatMap(r => (r.manifest.coverage?.collectors || []).filter(c => c.status !== 'complete').map(c => c.name)))];
          output.append(makeElement('p', 'verification-status', result.verified ? 'Collection coverage and timing checks passed. Inspect each path conclusion below.' : `Removal cannot be fully verified. ${incomplete.length ? `Incomplete collectors: ${incomplete.join(', ')}. ` : ''}Both snapshots need complete matching coverage, later collector timestamps and an untruncated search.`));
          for (const conclusion of result.conclusions) {
            const card = makeElement('section', 'verification-conclusion');
            card.append(makeElement('h4', null, conclusion.path), makeElement('p', null, conclusion.result), renderAnalysisValue({ alternatives: conclusion.alternatives, eligible: conclusion.eligible })); output.append(card);
          }
          output.append(makeElement('p', 'muted-text', result.caveat));
          for (const [title, value] of [['Other collected paths', result.remaining], ['Technical verification details', { verified: result.verified, truncated: result.truncated, searchScope: result.searchScope }], ['Access Review outcome verification', analysis.reviews(accessBaseline.report, source)]]) {
            const detail = makeElement('details'); detail.append(makeElement('summary', null, title), renderAnalysisValue(value)); output.append(detail);
          }
        } catch (error) { output.replaceChildren(makeElement('p', null, error.message)); }
      };
      clearBaseline.addEventListener('click', () => { baselineLoadSequence++; accessBaseline = null; input.value = ''; renderBaseline(); });
      renderBaseline();
      input.addEventListener('change', async () => {
        const sequence = ++baselineLoadSequence;
        try {
          const file = input.files[0];
          if (!file) return;
          if (file.size > 64 * 1024 * 1024) throw new Error('Choose a report JSON smaller than 64 MB.');
          const previous = JSON.parse(await file.text());
          analysis.compare(previous, node.Key);
          if (sequence !== baselineLoadSequence) return;
          accessBaseline = { name: file.name, report: previous };
          if (selectedKey && nodesByKey.has(selectedKey)) renderObjectDetails(nodesByKey.get(selectedKey));
        } catch (error) { if (sequence === baselineLoadSequence) output.replaceChildren(makeElement('p', null, `${error.message} The previously loaded baseline, if any, is unchanged.`)); }
      });
    }
    return section;
  }

  function renderObjectDetails(node) {
    elements.objectDetails.replaceChildren();
    const grid = makeElement('dl', 'property-grid');
    const properties = {
      'Object ID': node.Id,
      Status: node.Status,
      ...node.Properties
    };
    if (['user', 'guestUser'].includes(node.Kind)) {
      properties['Authentication collection'] = authenticationCollectionStatus(node).label;
    }

    for (const [name, value] of Object.entries(properties)) {
      grid.append(
        makeElement('dt', null, formatPropertyName(name)),
        makeElement('dd', null, formatValue(value))
      );
    }

    const relationshipHeading = makeElement('h3', null, 'Relationships');
    const relationshipList = makeElement('div', 'relationship-list');
    const relationships = nodeRelationships(node.Key);

    if (!relationships.length) {
      relationshipList.append(makeElement('p', 'muted-text', 'No collected relationships.'));
    }

    for (const edge of relationships.slice(0, 30)) {
      const outboundDirection = edge.From === node.Key;
      const relatedKey = outboundDirection ? edge.To : edge.From;
      const relatedNode = nodesByKey.get(relatedKey);
      const relationshipButton = makeElement('button', 'relationship-item');
      relationshipButton.type = 'button';
      relationshipButton.dataset.nodeKey = relatedKey;
      relationshipButton.append(
        makeElement(
          'span',
          'relationship-name',
          `${outboundDirection ? formatRelationship(edge.Relationship) : `Is ${formatRelationship(edge.Relationship).toLocaleLowerCase('en-GB')} from`} ${relatedNode ? relatedNode.DisplayName : relatedKey}`
        ),
        makeElement('span', 'relationship-meta', relatedNode ? formatKind(relatedNode.Kind) : 'Unresolved')
      );
      relationshipButton.addEventListener('click', () => selectNode(relatedKey));
      relationshipList.append(relationshipButton);
    }

    const extraSections = [
      renderBlastRadiusSection(node),
      renderConditionalAccessImpactSection(node)
    ].filter(Boolean);

    const dependencies = renderGroupDependenciesSection(node);
    if (dependencies) elements.objectDetails.append(dependencies);
    elements.objectDetails.append(renderAccessAnalysisSection(node), grid, relationshipHeading, relationshipList, ...extraSections);
  }

  function setInspectorTab(tabName) {
    const evidenceSelected = tabName === 'evidence';
    elements.evidenceTab.classList.toggle('selected', evidenceSelected);
    elements.evidenceTab.setAttribute('aria-selected', String(evidenceSelected));
    elements.detailsTab.classList.toggle('selected', !evidenceSelected);
    elements.detailsTab.setAttribute('aria-selected', String(!evidenceSelected));
    elements.explanationPanel.hidden = !evidenceSelected;
    elements.objectDetails.hidden = evidenceSelected;
  }

  function updateSelectionNavigation() {
    const previousKey = selectionHistory.at(-1);
    const previousNode = previousKey ? nodesByKey.get(previousKey) : null;
    elements.selectionBack.hidden = !previousNode;
    elements.selectionBack.textContent = previousNode
      ? `Back to ${previousNode.DisplayName}`
      : 'Back';

    elements.selectionBreadcrumbs.replaceChildren();
    const trail = [...selectionHistory, selectedKey]
      .filter((key, index, keys) => key && nodesByKey.has(key) && (index === 0 || key !== keys[index - 1]))
      .slice(-6);
    elements.selectionBreadcrumbs.hidden = trail.length < 2;

    trail.forEach((key, index) => {
      const node = nodesByKey.get(key);
      if (index > 0) {
        elements.selectionBreadcrumbs.append(makeElement('span', 'breadcrumb-separator', '/'));
      }
      if (index === trail.length - 1) {
        const current = makeElement('span', 'breadcrumb-current', node.DisplayName);
        current.setAttribute('aria-current', 'page');
        elements.selectionBreadcrumbs.append(current);
        return;
      }

      const button = makeElement('button', 'breadcrumb-button', node.DisplayName);
      button.type = 'button';
      button.addEventListener('click', () => {
        const fullTrail = [...selectionHistory, selectedKey];
        const targetIndex = fullTrail.lastIndexOf(key);
        selectionHistory.splice(0, selectionHistory.length, ...fullTrail.slice(0, Math.max(0, targetIndex)));
        selectNode(key, { recordHistory: false });
        elements.objectHeading.focus();
      });
      elements.selectionBreadcrumbs.append(button);
    });
  }

  function selectNode(nodeKey, options = {}) {
    const node = nodesByKey.get(nodeKey);
    if (!node) {
      return;
    }

    if (options.recordHistory !== false && selectedKey && selectedKey !== nodeKey) {
      if (selectionHistory.at(-1) !== selectedKey) {
        selectionHistory.push(selectedKey);
      }
      if (selectionHistory.length > 24) {
        selectionHistory.shift();
      }
    }

    selectedKey = nodeKey;
    currentPath = null;
    updateSelectionNavigation();
    updatePinButton();
    elements.objectKind.textContent = formatKind(node.Kind).toLocaleUpperCase('en-GB');
    elements.objectHeading.textContent = node.DisplayName;
    elements.pageSubtitle.textContent = ['user', 'guestUser', 'application', 'servicePrincipal'].includes(node.Kind)
      ? `Explore why ${node.DisplayName} has collected roles, permissions and group memberships.`
      : `Inspect the collected relationships and evidence for ${node.DisplayName}.`;
    elements.showNeighbours.disabled = false;
    const canExplain = ['user', 'guestUser', 'application', 'servicePrincipal'].includes(node.Kind);
    elements.explainAccess.disabled = !canExplain;
    elements.headerExplainAccess.disabled = !canExplain;
    elements.copyObjectId.disabled = false;
    elements.copyObjectId.dataset.objectId = node.Id;
    elements.objectSummary.replaceChildren();
    const principalName = node.Properties.userPrincipalName || node.Properties.appId || formatKind(node.Kind);
    elements.objectSummary.append(
      makeElement('span', null, formatKind(node.Kind)),
      makeElement('strong', null, formatValue(principalName)),
      makeElement('span', null, 'Object ID'),
      makeElement('code', null, node.Id)
    );
    renderObjectDetails(node);
    renderNeighbourGraph(nodeKey);
    setInspectorTab('details');
    elements.objectDetails.scrollTop = 0;
    elements.explanationPanel.scrollTop = 0;
    elements.graphCanvas.scrollTo({ top: 0, left: 0 });

    for (const button of elements.searchResults.querySelectorAll('[data-node-key]')) {
      button.classList.toggle('selected', button.dataset.nodeKey === nodeKey);
      if (button.dataset.nodeKey === nodeKey) {
        elements.searchResults.prepend(button.parentElement);
      }
    }
  }

  function clearSelection(message) {
    selectedKey = null;
    selectionHistory.length = 0;
    updateSelectionNavigation();
    updatePinButton();
    elements.objectKind.textContent = 'NO OBJECT SELECTED';
    elements.objectHeading.textContent = viewLabels[activeView].title;
    elements.objectSummary.textContent = message;
    elements.objectDetails.replaceChildren(makeElement('p', 'muted-text', message));
    elements.showNeighbours.disabled = true;
    elements.explainAccess.disabled = true;
    elements.headerExplainAccess.disabled = true;
    elements.copyObjectId.disabled = true;
    elements.copyObjectId.dataset.objectId = '';
    elements.pathList.replaceChildren();
    elements.pathDetail.replaceChildren();
    setInspectorTab('details');
    renderGraph([], [], 'No relationships to display');
  }

  function coverageDiagnosticFor(warning) {
    const retryCommand = [
      'Import-Module .\\IdentityAtlas.psd1 -Force',
      'Connect-IdentityAtlas -UseDeviceCode',
      'Invoke-IdentityAtlas -OutputPath .\\Output\\DevTenant -OpenReport'
    ].join('\n');
    const matchingNode = report.nodes
      .filter((node) => warning.toLocaleLowerCase('en-GB').includes(node.DisplayName.toLocaleLowerCase('en-GB')))
      .sort((left, right) => right.DisplayName.length - left.DisplayName.length)[0] || null;

    if (/authentication method/i.test(warning) || /\b403\b/i.test(warning)) {
      return {
        title: 'Authentication method collection was blocked',
        warning,
        endpoint: '/v1.0/users/{id}/authentication/methods',
        check: 'Check UserAuthenticationMethod.Read.All consent and that the signed-in account has a supported Microsoft Entra role.',
        explanation: 'Microsoft Graph rejected at least one authentication-method request. Other objects can still be complete, but authentication hygiene and access-path results for the affected user have reduced confidence.',
        matchingNode,
        retryCommand
      };
    }

    if (/role definition/i.test(warning)) {
      return {
        title: 'A referenced role definition was not returned',
        warning,
        endpoint: '/v1.0/roleManagement/directory/roleDefinitions',
        check: 'Check RoleManagement.Read.Directory consent. The assignment may also reference a deleted or unavailable role definition.',
        explanation: 'The report contains an assignment whose role definition could not be resolved. Paths that depend on that definition are retained as partial evidence rather than silently removed.',
        matchingNode,
        retryCommand
      };
    }

    return {
      title: 'Collector warning needs review',
      warning,
      endpoint: 'See the collector warning and evidence records',
      check: 'Check Graph consent, Microsoft Entra role requirements, licensing and the affected object, then collect the report again.',
      explanation: 'This warning reduces confidence only for the affected collector or object. Collected evidence from other endpoints remains available.',
      matchingNode,
      retryCommand
    };
  }

  function renderCoverageDetails() {
    const manifest = report.manifest;
    const collectors = manifest.coverage.collectors || [];
    const warnings = manifest.coverage.warnings || [];
    selectedKey = null;
    currentPath = null;
    selectionHistory.length = 0;
    updateSelectionNavigation();
    updatePinButton();
    elements.objectKind.textContent = 'REPORT COVERAGE';
    elements.objectHeading.textContent = 'Collection coverage';
    elements.objectSummary.textContent = `${manifest.counts.nodes} objects, ${manifest.counts.edges} relationships and ${manifest.counts.evidence} evidence records.`;
    const details = makeElement('div', 'relationship-list');
    const statusGrid = makeElement('div', 'coverage-status-grid');
    const completeCount = collectors.filter((collector) => collector.status === 'complete').length;
    const partialCount = collectors.filter((collector) => collector.status !== 'complete').length;
    for (const [label, value] of [
      ['Complete collectors', completeCount],
      ['Partial collectors', partialCount],
      ['Warnings', warnings.length]
    ]) {
      const status = makeElement('section', 'coverage-status-card');
      status.append(makeElement('span', 'coverage-status-value', String(value)), makeElement('span', null, label));
      statusGrid.append(status);
    }
    details.append(statusGrid);

    const collectorHeading = makeElement('h3', null, 'Collector status');
    details.append(collectorHeading);
    for (const collector of collectors) {
      const item = makeElement('section', 'evidence-card');
      const heading = makeElement('div', 'diagnostic-heading');
      heading.append(
        makeElement('h5', null, collector.name || 'Collector'),
        makeElement(
          'span',
          `coverage-state coverage-state-${collector.status === 'complete' ? 'complete' : 'warning'}`,
          collector.status || 'unknown'
        )
      );
      item.append(
        heading,
        makeElement('p', 'path-narrative', `Metrics: ${formatValue(collector.metrics || collector)}`)
      );
      details.append(item);
    }

    if (warnings.length) {
      const warningHeading = makeElement('h3', null, 'Coverage diagnostics');
      details.append(warningHeading);
      for (const warning of warnings) {
        const diagnostic = coverageDiagnosticFor(warning);
        const card = makeElement('section', 'coverage-diagnostic');
        const heading = makeElement('div', 'diagnostic-heading');
        heading.append(
          makeElement('h4', null, diagnostic.title),
          makeElement('span', 'coverage-state coverage-state-warning', 'Warning')
        );
        const facts = makeElement('dl', 'diagnostic-grid');
        facts.append(
          makeElement('dt', null, 'Collector message'),
          makeElement('dd', null, diagnostic.warning),
          makeElement('dt', null, 'Graph endpoint'),
          makeElement('dd', null, diagnostic.endpoint),
          makeElement('dt', null, 'Check'),
          makeElement('dd', null, diagnostic.check),
          makeElement('dt', null, 'Coverage effect'),
          makeElement('dd', null, diagnostic.explanation)
        );
        const command = makeElement('pre', 'remediation-snippet');
        command.append(makeElement('code', null, diagnostic.retryCommand));
        const actions = makeElement('div', 'diagnostic-actions');
        const copyButton = makeElement('button', 'secondary-button', 'Copy retry command');
        copyButton.type = 'button';
        copyButton.addEventListener('click', async () => {
          if (!navigator.clipboard) {
            return;
          }
          await navigator.clipboard.writeText(diagnostic.retryCommand);
          copyButton.textContent = 'Retry command copied';
          window.setTimeout(() => {
            copyButton.textContent = 'Copy retry command';
          }, 1500);
        });
        actions.append(copyButton);
        if (diagnostic.matchingNode) {
          const openButton = makeElement('button', 'secondary-button', `Open ${diagnostic.matchingNode.DisplayName}`);
          openButton.type = 'button';
          openButton.addEventListener('click', () => selectNode(diagnostic.matchingNode.Key));
          actions.append(openButton);
        }
        card.append(heading, facts, command, actions);
        details.append(card);
      }
    }
    else {
      details.append(makeElement('p', 'coverage-complete-message', 'No coverage warnings were recorded in this report.'));
    }
    elements.objectDetails.replaceChildren(details);
    elements.showNeighbours.disabled = true;
    elements.explainAccess.disabled = true;
    elements.headerExplainAccess.disabled = true;
    elements.copyObjectId.disabled = true;
    elements.relationshipGroups.hidden = true;
    setInspectorTab('details');
    renderGraph([], [], 'Report coverage');
  }

  function outboundRelationships(nodeKey, relationship) {
    return (outgoing.get(nodeKey) || []).filter((edge) => !relationship || edge.Relationship === relationship);
  }

  function inboundRelationships(nodeKey, relationship) {
    return (incoming.get(nodeKey) || []).filter((edge) => !relationship || edge.Relationship === relationship);
  }

  function credentialExpiresSoon(node) {
    if (node.Kind !== 'applicationCredential' || !node.Properties.endDateTime) {
      return false;
    }
    const end = new Date(node.Properties.endDateTime).getTime();
    if (!Number.isFinite(end)) {
      return false;
    }
    const days = (end - Date.now()) / 86400000;
    return days <= 30;
  }

  function daysSince(value) {
    if (!value) {
      return null;
    }
    const time = new Date(value).getTime();
    if (!Number.isFinite(time)) {
      return null;
    }
    return (Date.now() - time) / 86400000;
  }

  function severityClass(severity) {
    return `severity-${String(severity || 'low').toLocaleLowerCase('en-GB')}`;
  }

  function createSeverityBadge(severity) {
    return makeElement('span', `severity-badge ${severityClass(severity)}`, severity);
  }

  function relatedEdgesForNodes(nodes) {
    const keys = new Set(nodes.map((node) => node.Key));
    const edgeKeys = new Set();
    for (const node of nodes) {
      for (const edge of nodeRelationships(node.Key)) {
        if (keys.has(edge.From) || keys.has(edge.To)) {
          edgeKeys.add(edge.Key);
        }
      }
    }
    return Array.from(edgeKeys).map((key) => edgesByKey.get(key)).filter(Boolean);
  }

  function authenticationCollectionStatus(node) {
    const collector = report.manifest.coverage?.collectors?.find((item) => item.name === 'devicesAndAuthentication');
    const entry = collector?.metrics?.authenticationByUser?.[node.Key];
    const labels = {
      complete: 'Collected successfully. Registration evidence does not prove MFA enforcement.',
      empty: 'Collected successfully: no authentication methods returned.',
      accessDenied: 'Access denied by Microsoft Graph. Authentication methods are unknown.',
      failed: 'Request failed. Authentication methods are unknown.',
      partial: 'Incomplete response. Authentication methods are not fully known.',
      skipped: 'Skipped by request. Authentication methods are unknown.',
      notCollected: 'Per-user collection status is unavailable. Full method coverage is unknown; any existing method evidence is retained.'
    };
    const status = Object.hasOwn(labels, entry?.status) ? entry.status :
      (collector?.metrics?.authenticationMethodsSkipped ? 'skipped' : 'notCollected');
    return { status, label: labels[status], complete: ['complete', 'empty'].includes(status) };
  }

  function nodeHasStrongAuthentication(node) {
    const methods = outboundRelationships(node.Key, 'hasAuthenticationMethod')
      .map((edge) => nodesByKey.get(edge.To))
      .filter(Boolean);
    return methods.some((method) => {
      const haystack = `${method.DisplayName} ${method.Properties.methodType || ''} ${method.Properties.type || ''}`.toLocaleLowerCase('en-GB').replace(/\s+/g, '');
      return ['fido', 'passkey', 'windowshello', 'authenticator', 'temporaryaccesspass', 'certificate'].some((term) => haystack.includes(term));
    });
  }

  function privilegedRoleUsersWithoutStrongAuth() {
    const privilegedUsers = new Set();
    for (const edge of report.edges) {
      if (['assignedRole', 'eligibleRole'].includes(edge.Relationship)) {
        const node = nodesByKey.get(edge.From);
        if (node && ['user', 'guestUser'].includes(node.Kind)) {
          privilegedUsers.add(node);
        }
      }
    }
    return Array.from(privilegedUsers).filter((node) => authenticationCollectionStatus(node).complete && !nodeHasStrongAuthentication(node));
  }

  function isTenantManagedApplication(node, tenantId) {
    if (node.Kind === 'application') return true;
    return node.Kind === 'servicePrincipal' && node.Properties?.servicePrincipalType === 'Application' &&
      Boolean(tenantId) && String(node.Properties?.appOwnerOrganizationId || '').toLowerCase() === String(tenantId).toLowerCase();
  }

  function collectInsights() {
    const staleDeviceCutoffDays = 90;
    return [
      {
        id: 'ownerless-applications',
        title: 'Tenant-owned applications without collected owners',
        severity: 'High',
        description: 'App registrations and tenant-owned application service principals with no collected owner relationship. External publishers and managed identities are excluded. Missing evidence is not proof of missing ownership.',
        why: 'Ownerless applications make change approval, incident response and credential rotation harder.',
        action: 'Verify owner collection coverage and current owners first. Agree accountable owners before making any change.',
        nodes: report.nodes.filter((node) =>
          isTenantManagedApplication(node, report.manifest.tenant.id) &&
          outboundRelationships(node.Key, 'ownedBy').length === 0
        )
      },
      {
        id: 'expiring-credentials',
        title: 'Credentials expiring soon or expired',
        severity: 'Critical',
        description: 'Application credentials whose end date is within 30 days or already past.',
        why: 'Expired credentials can break production workloads. Near-expiry credentials need planned rotation.',
        action: 'Rotate the credential, remove unused credentials and confirm the new secret or certificate is in use.',
        nodes: report.nodes.filter(credentialExpiresSoon)
      },
      {
        id: 'graph-application-permissions',
        title: 'Requested Microsoft Graph application permissions',
        severity: 'High',
        description: 'Required API permissions where the resource app is Microsoft Graph and the permission type is Role. A request is not evidence of admin consent or a granted permission.',
        why: 'Application permissions can grant broad tenant-wide access without a signed-in user.',
        action: 'Confirm admin consent is still required, document the business owner and remove unused permissions.',
        nodes: report.nodes.filter((node) =>
          node.Kind === 'apiPermission' &&
          node.Properties.resourceAppId === '00000003-0000-0000-c000-000000000000' &&
          node.Properties.permissionType === 'Role'
        )
      },
      {
        id: 'eligible-privileged-roles',
        title: 'Eligible privileged role paths',
        severity: 'Medium',
        description: 'Collected PIM eligible directory role relationships.',
        why: 'Eligible privileged access can still become active access when activation controls are weak.',
        action: 'Review PIM settings, require approval where appropriate and verify activation requires strong authentication.',
        nodes: Array.from(new Set(
          report.edges
            .filter((edge) => edge.Relationship === 'eligibleRole')
            .map((edge) => edge.From)
        )).map((key) => nodesByKey.get(key)).filter(Boolean)
      },
      {
        id: 'conditional-access-exclusions',
        title: 'Conditional Access exclusions',
        severity: 'High',
        description: 'Objects explicitly excluded from collected Conditional Access policies.',
        why: 'Exclusions are common break-glass and service-account controls, but stale exclusions weaken policy coverage.',
        action: 'Review every exclusion, record its owner and expiry date, and remove exclusions that are no longer required.',
        nodes: Array.from(new Set(
          report.edges
            .filter((edge) => edge.Relationship === 'conditionalAccessExcludes')
            .map((edge) => edge.From)
        )).map((key) => nodesByKey.get(key)).filter(Boolean)
      },
      {
        id: 'non-compliant-devices',
        title: 'Devices not marked compliant',
        severity: 'High',
        description: 'Collected devices where Microsoft Graph did not report compliant state as yes.',
        why: 'Non-compliant devices should not be treated as a trusted access signal without investigation.',
        action: 'Check the device in Intune or Microsoft Entra ID, then remediate, quarantine or remove stale device records.',
        nodes: report.nodes.filter((node) => node.Kind === 'device' && node.Properties.isCompliant !== true)
      },
      {
        id: 'users-without-authentication-methods',
        title: 'Users with no authentication methods returned',
        severity: 'Medium',
        description: 'Successful per-user collection returned no methods. Failed, denied, skipped and unknown requests are excluded.',
        why: 'An empty registration response needs review in the context of the identity and its authentication provider. It does not prove that MFA is disabled.',
        action: 'Verify the current registration and authentication provider before deciding whether registration changes are needed.',
        nodes: report.nodes.filter((node) =>
          ['user', 'guestUser'].includes(node.Kind) &&
          authenticationCollectionStatus(node).status === 'empty' &&
          outboundRelationships(node.Key, 'hasAuthenticationMethod').length === 0
        )
      },
      {
        id: 'trusted-named-locations',
        title: 'Trusted named locations',
        severity: 'Medium',
        description: 'Named locations marked as trusted in Conditional Access.',
        why: 'Trusted locations reduce Conditional Access friction and must be kept narrow and owned.',
        action: 'Confirm CIDR ownership, remove broad ranges and schedule recurring review.',
        nodes: report.nodes.filter((node) => node.Kind === 'namedLocation' && node.Properties.isTrusted === true)
      },
      {
        id: 'authentication-strength-policies',
        title: 'Policies requiring authentication strength',
        severity: 'Low',
        description: 'Conditional Access policies linked to an authentication strength policy.',
        why: 'Authentication strength is positive evidence, but admins still need to understand scope and exclusions.',
        action: 'Confirm the policy targets the intended users and applications, then review allowed combinations.',
        nodes: Array.from(new Set(
          report.edges
            .filter((edge) => edge.Relationship === 'requiresAuthenticationStrength')
            .map((edge) => edge.From)
        )).map((key) => nodesByKey.get(key)).filter(Boolean)
      },
      {
        id: 'partial-objects',
        title: 'Partial or unresolved objects',
        severity: 'Medium',
        description: 'Objects that were referenced but not fully collected.',
        why: 'Partial objects reduce confidence in access path explanations and blast radius analysis.',
        action: 'Regenerate the report with the missing Microsoft Graph permissions or re-run once transient Graph errors are resolved.',
        nodes: report.nodes.filter((node) => node.Status !== 'complete')
      },
      {
        id: 'stale-devices',
        title: 'Stale devices',
        severity: 'Medium',
        description: `Devices with no approximate sign-in activity in the last ${staleDeviceCutoffDays} days.`,
        why: 'Old device records can keep stale ownership and compliance relationships in access reviews.',
        action: 'Validate ownership, then disable or remove devices that are no longer in use.',
        nodes: report.nodes.filter((node) =>
          node.Kind === 'device' &&
          daysSince(node.Properties.approximateLastSignInDateTime) !== null &&
          daysSince(node.Properties.approximateLastSignInDateTime) > staleDeviceCutoffDays
        )
      },
      {
        id: 'privileged-users-without-strong-auth',
        title: 'Privileged users without strong authentication evidence',
        severity: 'Critical',
        description: 'Users with collected privileged role assignments or eligibility whose successful authentication collection returned no recognised strong method. Unknown collection is excluded. Registration is not proof of enforcement.',
        why: 'Privileged users should use phishing-resistant or strong authentication before role activation or admin sign-in.',
        action: 'Verify the current registration, authentication provider and policy coverage before planning authentication changes.',
        nodes: privilegedRoleUsersWithoutStrongAuth()
      }
    ];
  }

  function insightReviewKey(insight, node) {
    return `insight:${insight.id}:${node.Key}`;
  }

  function remediationForInsight(insight, node) {
    // Only UUIDs enter executable arguments. Tenant display text stays on one comment line.
    const safeId = (value, placeholder) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || '')) ? String(value) : placeholder;
    const objectId = safeId(node.Id, '<object-id>');
    const appId = safeId(node.Properties.appId, '<app-id>');
    const keyId = safeId(node.Properties.keyId, '<key-id>');
    const displayName = String(node.DisplayName || '').replace(/[\r\n\u2028\u2029`]/g, ' ');
    const ownerResource = node.Kind === 'servicePrincipal' ? 'ServicePrincipal' : 'Application';
    const snippets = {
      'ownerless-applications': [
        `# Review owners for ${displayName}`,
        `Get-Mg${ownerResource}Owner -${ownerResource}Id '${objectId}'`,
        `# Add owner after selecting the correct owner object`,
        `New-Mg${ownerResource}OwnerByRef -${ownerResource}Id '${objectId}' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/<owner-object-id>' }`
      ],
      'expiring-credentials': [
        `# Review credentials for ${displayName}`,
        `Get-MgApplication -ApplicationId '<application-object-id>' | Select-Object -ExpandProperty PasswordCredentials`,
        `# Remove the expired credential after confirming replacement`,
        `Remove-MgApplicationPassword -ApplicationId '<application-object-id>' -KeyId '${keyId}'`
      ],
      'graph-application-permissions': [
        `# Find applications requiring ${displayName}`,
        `Get-MgApplication -Filter "appId eq '${appId}'"`,
        `# Review required resource access and admin consent before removing permissions`
      ],
      'eligible-privileged-roles': [
        `# Review eligible directory role access for ${displayName}`,
        `Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "principalId eq '${objectId}'"`
      ],
      'conditional-access-exclusions': [
        `# Review Conditional Access exclusions affecting ${displayName}`,
        `Get-MgIdentityConditionalAccessPolicy | Where-Object { $_.Conditions.Users.ExcludeUsers -contains '${objectId}' -or $_.Conditions.Users.ExcludeGroups -contains '${objectId}' }`
      ],
      'non-compliant-devices': [
        `# Review device compliance for ${displayName}`,
        `Get-MgDevice -DeviceId '${objectId}' | Select-Object DisplayName,IsCompliant,ApproximateLastSignInDateTime,AccountEnabled`
      ],
      'users-without-authentication-methods': [
        `# Review registered authentication methods for ${displayName}`,
        `Get-MgUserAuthenticationMethod -UserId '${objectId}'`
      ],
      'trusted-named-locations': [
        `# Review trusted named locations`,
        `Get-MgIdentityConditionalAccessNamedLocation | Where-Object { $_.Id -eq '${objectId}' }`
      ],
      'authentication-strength-policies': [
        `# Review policies using authentication strength`,
        `Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId '${objectId}'`
      ],
      'partial-objects': [
        `# Re-run Identity Atlas with the missing Microsoft Graph scopes shown in the report coverage panel`,
        `Invoke-IdentityAtlas -OutputPath .\\Output\\DevTenant -OpenReport`
      ],
      'stale-devices': [
        `# Review stale device before disabling or deleting`,
        `Get-MgDevice -DeviceId '${objectId}' | Select-Object DisplayName,ApproximateLastSignInDateTime,AccountEnabled`,
        `# Disable only after owner and business impact checks`,
        `Update-MgDevice -DeviceId '${objectId}' -AccountEnabled:$false`
      ],
      'privileged-users-without-strong-auth': [
        `# Review privileged user's authentication methods`,
        `Get-MgUserAuthenticationMethod -UserId '${objectId}'`,
        `# Review active and eligible directory role assignments`,
        `Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "principalId eq '${objectId}'"`
      ]
    };
    return (snippets[insight.id] || [`# Review ${displayName}`, `Get-MgDirectoryObject -DirectoryObjectId '${objectId}'`]).join('\n');
  }

  function exportInsightEvidence(insight) {
    const visibleNodes = insight.nodes;
    const lines = [
      `# ${insight.title}`,
      '',
      `Severity: ${insight.severity}`,
      `Action: ${insight.action}`,
      `Why: ${insight.why}`,
      `Report generated UTC: ${report.manifest.generatedAtUtc}`,
      `Tenant: ${report.manifest.tenant.displayName}`,
      '',
      '## Review states',
      ''
    ];

    if (!visibleNodes.length) {
      lines.push('No matching objects were found in the collected data.', '');
    }

    for (const node of visibleNodes) {
      lines.push(`- ${node.DisplayName} (${formatKind(node.Kind)}): ${reviewStateFor(insightReviewKey(insight, node))}`);
    }

    lines.push('', '## Objects', '');
    for (const node of visibleNodes) {
      lines.push(`### ${node.DisplayName}`);
      lines.push('');
      lines.push(`Kind: ${formatKind(node.Kind)}`);
      lines.push(`Object ID: ${node.Id}`);
      lines.push(`Status: ${node.Status}`);
      lines.push('');
      lines.push('Suggested remediation:');
      lines.push('```powershell');
      lines.push(remediationForInsight(insight, node));
      lines.push('```');
      lines.push('');
    }

    lines.push('## Relationship evidence', '');
    for (const edge of relatedEdgesForNodes(visibleNodes)) {
      const from = nodesByKey.get(edge.From);
      const to = nodesByKey.get(edge.To);
      lines.push(`### ${from ? from.DisplayName : edge.From} ${formatRelationship(edge.Relationship)} ${to ? to.DisplayName : edge.To}`);
      lines.push('');
      lines.push(`Relationship: ${edge.Relationship}`);
      lines.push(`State: ${formatValue(edge.State)}`);
      for (const evidenceId of edge.EvidenceIds) {
        const evidence = evidenceByKey.get(evidenceId);
        if (!evidence) {
          continue;
        }
        lines.push('');
        lines.push(`Collector: ${evidence.Collector}`);
        lines.push(`Endpoint: ${evidence.Endpoint}`);
        lines.push(`Observed at UTC: ${new Date(evidence.CollectedAtUtc).toISOString()}`);
        lines.push(`Completeness: ${evidence.Completeness}`);
      }
      lines.push('');
    }

    previewEvidenceExport(`${lines.join('\n')}\n`, maskedEvidence(relatedEdgesForNodes(visibleNodes)), `identity-atlas-insight-${insight.id}.md`);
  }

  function renderInsightsDetails() {
    selectedKey = null;
    currentPath = null;
    const insights = collectInsights();
    const total = insights.reduce((sum, insight) => sum + insight.nodes.length, 0);
    elements.objectKind.textContent = 'ADMIN QUESTIONS';
    elements.objectHeading.textContent = 'Insights';
    elements.objectSummary.textContent = `${total} insight result${total === 1 ? '' : 's'} from ${insights.length} checks.`;
    const panel = makeElement('div', 'relationship-list');

    for (const insight of insights) {
      const section = makeElement('section', 'evidence-card');
      const headingRow = makeElement('div', 'insight-heading-row');
      headingRow.append(
        makeElement('h5', null, `${insight.title} (${insight.nodes.length})`),
        createSeverityBadge(insight.severity)
      );
      const exportButton = makeElement('button', 'secondary-button');
      exportButton.type = 'button';
      exportButton.textContent = 'Export evidence';
      exportButton.addEventListener('click', () => exportInsightEvidence(insight));
      section.append(
        headingRow,
        makeElement('p', 'path-narrative', insight.description),
        makeElement('p', 'path-narrative', `Why: ${insight.why}`),
        makeElement('p', 'path-narrative', `Action: ${insight.action}`),
        exportButton
      );
      if (['users-without-authentication-methods', 'privileged-users-without-strong-auth'].includes(insight.id)) {
        const unknownCount = report.nodes.filter((node) => ['user', 'guestUser'].includes(node.Kind) && !authenticationCollectionStatus(node).complete).length;
        section.append(makeElement('p', 'muted-text', `${unknownCount} user(s) have unknown or incomplete authentication collection and are excluded from negative authentication findings. Open a user for its collection status.`));
      }
      if (!insight.nodes.length) {
        section.append(makeElement('p', 'muted-text', 'No matching objects in the collected data.'));
      }
      for (const node of insight.nodes.slice(0, 8)) {
        const item = makeElement('div', 'insight-item');
        const reviewRow = makeElement('div', 'review-row');
        reviewRow.append(
          openNodeButton(node, formatKind(node.Kind)),
          createReviewSelect(insightReviewKey(insight, node))
        );
        item.append(
          reviewRow,
          makeElement('pre', 'remediation-snippet', remediationForInsight(insight, node))
        );
        section.append(item);
      }
      if (insight.nodes.length > 8) {
        section.append(makeElement('p', 'muted-text', `${insight.nodes.length - 8} more result${insight.nodes.length - 8 === 1 ? '' : 's'} available in the evidence export.`));
      }
      panel.append(section);
    }

    elements.objectDetails.replaceChildren(panel);
    elements.showNeighbours.disabled = true;
    elements.explainAccess.disabled = true;
    elements.headerExplainAccess.disabled = true;
    elements.copyObjectId.disabled = true;
    setInspectorTab('details');
    renderGraph([], [], 'Insight results');
  }

  function addTimelineEvent(events, dateValue, title, description, nodeKey, severity) {
    if (!dateValue) {
      return;
    }
    const date = new Date(dateValue);
    if (!Number.isFinite(date.getTime())) {
      return;
    }
    events.push({
      date,
      title,
      description,
      nodeKey,
      severity: severity || 'Low'
    });
  }

  function collectTimelineEvents() {
    const events = [];
    addTimelineEvent(
      events,
      report.manifest.generatedAtUtc,
      'Report generated',
      `${report.nodes.length} objects and ${report.edges.length} relationships collected for ${report.manifest.tenant.displayName}.`,
      null,
      report.manifest.coverage.status === 'complete' ? 'Low' : 'Medium'
    );

    for (const node of report.nodes) {
      if (node.Kind === 'applicationCredential') {
        const days = daysSince(node.Properties.endDateTime);
        addTimelineEvent(
          events,
          node.Properties.endDateTime,
          `Credential expiry: ${node.DisplayName}`,
          days !== null && days > 0 ? 'Credential has expired.' : 'Credential expires on this date.',
          node.Key,
          credentialExpiresSoon(node) ? 'Critical' : 'Medium'
        );
      }
      if (node.Kind === 'device') {
        addTimelineEvent(
          events,
          node.Properties.approximateLastSignInDateTime,
          `Device last sign-in: ${node.DisplayName}`,
          `Compliant state: ${formatValue(node.Properties.isCompliant)}.`,
          node.Key,
          daysSince(node.Properties.approximateLastSignInDateTime) > 90 ? 'Medium' : 'Low'
        );
      }
      if (node.Properties.createdDateTime) {
        addTimelineEvent(
          events,
          node.Properties.createdDateTime,
          `Created: ${node.DisplayName}`,
          `${formatKind(node.Kind)} creation date recorded by Microsoft Graph.`,
          node.Key,
          'Low'
        );
      }
      if (node.Properties.modifiedDateTime) {
        addTimelineEvent(
          events,
          node.Properties.modifiedDateTime,
          `Modified: ${node.DisplayName}`,
          `${formatKind(node.Kind)} modified date recorded by Microsoft Graph.`,
          node.Key,
          'Low'
        );
      }
    }

    for (const edge of report.edges) {
      if (edge.Relationship === 'eligibleRole' && edge.State?.endDateTime) {
        const from = nodesByKey.get(edge.From);
        const to = nodesByKey.get(edge.To);
        addTimelineEvent(
          events,
          edge.State.endDateTime,
          `PIM eligibility ends: ${from ? from.DisplayName : edge.From}`,
          to ? `Eligible role: ${to.DisplayName}.` : 'Eligible role end date recorded.',
          edge.From,
          'Medium'
        );
      }
    }

    return events.sort((left, right) => right.date.getTime() - left.date.getTime()).slice(0, 80);
  }

  function renderTimelineDetails() {
    selectedKey = null;
    currentPath = null;
    const events = collectTimelineEvents();
    elements.objectKind.textContent = 'REPORT TIMELINE';
    elements.objectHeading.textContent = 'Timeline';
    elements.objectSummary.textContent = `${events.length} dated event${events.length === 1 ? '' : 's'} found in this report.`;
    const panel = makeElement('div', 'timeline-list');
    const comparisonInput = makeElement('input');
    comparisonInput.type = 'file';
    comparisonInput.accept = '.json,application/json';
    comparisonInput.setAttribute('aria-label', 'Open comparison JSON for this report');
    const comparisonPanel = makeElement('section', 'evidence-card');
    comparisonPanel.setAttribute('aria-live', 'polite');
    panel.append(makeElement('h4', null, 'Compare snapshots'), makeElement('p', 'muted-text', 'Choose comparison.json generated by Compare-IdentityAtlas, using this report as the later snapshot. The file stays in this browser.'), comparisonInput, comparisonPanel);
    comparisonInput.addEventListener('change', async () => {
      comparisonPanel.replaceChildren();
      try {
        const file = comparisonInput.files[0];
        if (!file || file.size > 64 * 1024 * 1024) throw new Error('Select a comparison JSON file smaller than 64 MB.');
        const comparison = JSON.parse(await file.text());
        if (comparison.tenantId !== report.manifest.tenant.id || comparison.schemaVersion !== report.manifest.schemaVersion || comparison.difference?.generatedAtUtc !== report.manifest.generatedAtUtc) throw new Error('The comparison must match this tenant, schema and later snapshot timestamp.');
        comparisonPanel.append(makeElement('p', null, `Snapshots: ${comparison.reference.generatedAtUtc} to ${comparison.difference.generatedAtUtc}. These are observation times, not exact change times.`));
        for (const warning of comparison.coverageWarnings || []) comparisonPanel.append(makeElement('p', 'muted-text', String(warning)));
        for (const [key, title] of [['addedNodes', 'Newly observed objects'], ['removedNodes', 'Removed objects'], ['changedNodes', 'Changed objects'], ['unobservedNodes', 'Objects not observed'], ['addedEdges', 'Newly observed relationships'], ['removedEdges', 'Removed relationships'], ['changedEdges', 'Changed relationships'], ['unobservedEdges', 'Relationships not observed']]) {
          const items = comparison[key] || [];
          if (!Array.isArray(items)) throw new Error('Invalid comparison record list.');
          const section = makeElement('details');
          section.append(makeElement('summary', null, `${title}: ${items.length}`));
          for (const item of items.slice(0, 100)) {
            const value = item.after || item;
            const row = makeElement('section', 'evidence-card');
            row.append(makeElement('p', null, value.displayName || `${value.from} ${formatRelationship(value.relationship || '')} ${value.to}`));
            if (item.beforeProperties || item.afterProperties) row.append(makeElement('pre', null, JSON.stringify({ before: item.beforeProperties, after: item.afterProperties }, null, 2)));
            else if (item.before || item.after) row.append(makeElement('pre', null, JSON.stringify({ before: item.before?.state, after: item.after?.state }, null, 2)));
            if (nodesByKey.has(item.key)) row.append(openNodeButton(nodesByKey.get(item.key), 'Investigate affected object'));
            for (const endpointKey of new Set([value.fromKey, value.toKey])) if (nodesByKey.has(endpointKey)) row.append(openNodeButton(nodesByKey.get(endpointKey), 'Investigate affected endpoint'));
            section.append(row);
          }
          if (items.length > 100) section.append(makeElement('p', null, 'First 100 shown. Full results remain in the comparison file.'));
          comparisonPanel.append(section);
        }
      } catch (error) { comparisonPanel.replaceChildren(makeElement('p', null, error.message)); }
    });

    if (!events.length) {
      panel.append(makeElement('p', 'muted-text', viewLabels.timeline.empty));
    }

    for (const event of events) {
      const item = makeElement('section', 'timeline-item');
      const row = makeElement('div', 'timeline-row');
      row.append(
        makeElement('span', 'timeline-date', event.date.toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })),
        createSeverityBadge(event.severity)
      );
      item.append(
        row,
        makeElement('h5', null, event.title),
        makeElement('p', 'path-narrative', event.description)
      );
      if (event.nodeKey && nodesByKey.has(event.nodeKey)) {
        item.append(openNodeButton(nodesByKey.get(event.nodeKey), 'Open related object'));
      }
      panel.append(item);
    }

    elements.objectDetails.replaceChildren(panel);
    elements.showNeighbours.disabled = true;
    elements.explainAccess.disabled = true;
    elements.headerExplainAccess.disabled = true;
    elements.copyObjectId.disabled = true;
    setInspectorTab('details');
    renderGraph([], [], 'Timeline');
  }

  function createSettingsLink(href, title, description) {
    const link = makeElement('a', 'settings-link');
    link.href = href;
    if (href.startsWith('https://')) {
      link.rel = 'noopener';
    }
    link.append(
      makeElement('span', 'relationship-name', title),
      makeElement('span', 'relationship-meta', description)
    );
    return link;
  }

  function renderSettingsDetails() {
    selectedKey = null;
    currentPath = null;
    elements.objectKind.textContent = 'REPORT SETTINGS';
    elements.objectHeading.textContent = 'Settings';
    elements.objectSummary.textContent = 'Export settings and project links for this local report.';
    const panel = makeElement('div', 'settings-panel');

    const exportSection = makeElement('section', 'evidence-card');
    exportSection.append(
      makeElement('h5', null, 'Exports'),
      makeElement('p', 'path-narrative', 'The visible graph can be exported as Mermaid, SVG or PNG. Evidence can be exported as Markdown.')
    );

    const scaleSection = makeElement('section', 'evidence-card');
    scaleSection.append(
      makeElement('h5', null, 'Scale settings'),
      makeElement('p', 'path-narrative', 'Search is handled by a browser worker with precomputed search text. Visible result lists are capped to keep larger tenant reports responsive.')
    );

    const layoutSection = makeElement('section', 'evidence-card');
    const evidenceFirstKey = `${reportStorageKey}:layout:evidenceFirst`;
    const evidenceFirstToggle = makeElement('input');
    evidenceFirstToggle.type = 'checkbox';
    evidenceFirstToggle.checked = readStoredBoolean(evidenceFirstKey, false);
    evidenceFirstToggle.addEventListener('change', () => {
      writeStoredBoolean(evidenceFirstKey, evidenceFirstToggle.checked);
      applyLayoutSettings();
    });
    const evidenceFirstRow = makeElement('label', 'setting-toggle');
    evidenceFirstRow.append(
      evidenceFirstToggle,
      makeElement('span', 'relationship-name', 'Evidence-first layout'),
      makeElement('span', 'relationship-meta', 'Gives the evidence panel more space for admin review sessions.')
    );
    layoutSection.append(
      makeElement('h5', null, 'Layout'),
      evidenceFirstRow
    );

    const securitySection = makeElement('section', 'evidence-card');
    const securityMetadata = report.manifest.security || {};
    const securityStatus = securityMetadata.readOnlyCollection === true &&
      securityMetadata.tokenDataSerialized === false
      ? 'Read-only collection. Authentication tokens are not included in this report.'
      : 'Security metadata is unavailable for this report version.';
    securitySection.append(
      makeElement('h5', null, 'Security and data handling'),
      makeElement('p', 'path-narrative', securityStatus),
      makeElement('p', 'path-narrative', 'Treat this report as administrative evidence. It contains tenant identifiers and relationships. Keep it on an access-controlled device and delete exports when they are no longer required.')
    );
    const clearBrowserData = makeElement('button', 'secondary-button', 'Clear Identity Atlas browser data');
    clearBrowserData.type = 'button';
    clearBrowserData.addEventListener('click', () => clearIdentityAtlasBrowserData(clearBrowserData));
    securitySection.append(
      makeElement('p', 'path-narrative', 'Clears pins, review states and layout preferences stored by Identity Atlas on this local address.'),
      clearBrowserData
    );

    const supportSection = makeElement('section', 'evidence-card');
    supportSection.append(
      makeElement('h5', null, 'Support and donations'),
      createSettingsLink('mailto:Mark@controlaltdeletetechbits.co.uk', 'Email support', 'Mark@controlaltdeletetechbits.co.uk'),
      createSettingsLink('https://buymeacoffee.com/cadtb', 'Donate', 'Buy Me a Coffee')
    );

    panel.append(exportSection, scaleSection, layoutSection, securitySection, supportSection);
    elements.objectDetails.replaceChildren(panel);
    elements.showNeighbours.disabled = true;
    elements.explainAccess.disabled = true;
    elements.headerExplainAccess.disabled = true;
    elements.copyObjectId.disabled = true;
    setInspectorTab('details');
    renderGraph([], [], 'Settings');
  }

  function showContextMenu(event, nodeKey) {
    event.preventDefault();
    contextKey = nodeKey;
    const node = nodesByKey.get(nodeKey);
    elements.contextExplain.hidden = !node || !['user', 'guestUser', 'application', 'servicePrincipal'].includes(node.Kind);
    elements.contextMenu.hidden = false;
    elements.contextMenu.style.left = `${Math.min(event.clientX, window.innerWidth - 220)}px`;
    elements.contextMenu.style.top = `${Math.min(event.clientY, window.innerHeight - 120)}px`;
    elements.contextOpen.focus();
  }

  function renderSearchResults(keys) {
    elements.searchResults.replaceChildren();
    elements.resultCount.textContent = String(keys.length);

    if (!keys.length) {
      const empty = makeElement('p', 'muted-text empty-results', viewLabels[activeView].empty);
      elements.searchResults.append(empty);
      return;
    }

    for (const key of keys) {
      const node = nodesByKey.get(key);
      if (!node) {
        continue;
      }

      const button = makeElement('button', 'result-item');
      button.type = 'button';
      button.dataset.nodeKey = key;
      const iconTile = makeElement('span', 'result-icon');
      iconTile.setAttribute('aria-hidden', 'true');
      iconTile.append(makeElement('span', `icon ${kindIconClass(node.Kind)}`));
      const resultCopy = makeElement('span', 'result-copy');
      resultCopy.append(
        makeElement('span', 'result-name', node.DisplayName),
        makeElement('span', 'result-kind', formatKind(node.Kind))
      );
      button.append(iconTile, resultCopy);
      button.addEventListener('click', () => selectNode(key));
      button.addEventListener('contextmenu', (event) => showContextMenu(event, key));
      const listItem = makeElement('div', 'result-entry');
      listItem.setAttribute('role', 'listitem');
      listItem.append(button);
      elements.searchResults.append(listItem);
    }
  }

  async function updateSearch() {
    searchSequence += 1;
    const currentSearch = searchSequence;
    const keys = await requestWorker('search', {
      query: elements.globalSearch.value,
      kind: elements.kindFilter.value
    });
    if (currentSearch !== searchSequence) {
      return;
    }
    renderSearchResults(keys);
  }

  function scheduleSearch() {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(updateSearch, 90);
  }

  function setActiveView(viewName, preferredKey = null) {
    const generation = ++viewGeneration;
    if (adminWorkspace) adminWorkspace.hide();
    const nextView = viewLabels[viewName] ? viewName : 'access';
    activeView = nextView;
    selectedKey = null;
    selectionHistory.length = 0;
    updateSelectionNavigation();
    updatePinButton();
    const selectedNavItem = elements.navItems.find((item) => item.dataset.view === nextView);
    const nextKind = selectedNavItem ? selectedNavItem.dataset.kind : '';

    for (const item of elements.navItems) {
      const selected = item.dataset.view === nextView;
      item.classList.toggle('selected', selected);
      if (selected) {
        item.setAttribute('aria-current', 'page');
      }
      else {
        item.removeAttribute('aria-current');
      }
    }

    elements.kindFilter.value = nextKind;
    elements.globalSearch.value = '';
    document.querySelector('.page-heading .eyebrow').textContent = viewLabels[nextView].eyebrow;
    document.querySelector('.page-heading h2').textContent = viewLabels[nextView].title;
    elements.pageSubtitle.textContent = viewLabels[nextView].subtitle;
    updateSearch().then(() => {
      if (activeView !== nextView || generation !== viewGeneration) {
        return;
      }
      if (nextView === 'overview') {
        if (adminWorkspace) adminWorkspace.home();
        else renderCoverageDetails();
        return;
      }
      if (nextView === 'insights') {
        renderInsightsDetails();
        return;
      }
      if (nextView === 'timeline') {
        renderTimelineDetails();
        return;
      }
      if (nextView === 'settings') {
        renderSettingsDetails();
        return;
      }
      const firstResult = elements.searchResults.querySelector('[data-node-key]');
      if (preferredKey && nodesByKey.has(preferredKey)) {
        selectNode(preferredKey);
      }
      else if (firstResult) {
        selectNode(firstResult.dataset.nodeKey);
      }
      else {
        clearSelection(viewLabels[nextView].empty);
      }
    });
  }

  function graphLabel(node) {
    const maximumLength = 24;
    return node.DisplayName.length > maximumLength
      ? `${node.DisplayName.slice(0, maximumLength - 1)}…`
      : node.DisplayName;
  }

  function renderGraph(nodeKeys, edgeKeys, summary) {
    const namespace = 'http://www.w3.org/2000/svg';
    const nodes = nodeKeys.map((key) => nodesByKey.get(key)).filter(Boolean);
    const relationshipFilter = elements.relationshipFilter.value;
    const edges = edgeKeys
      .map((key) => edgesByKey.get(key))
      .filter(Boolean)
      .filter((edge) => !relationshipFilter || edge.Relationship === relationshipFilter);
    currentGraph = { nodeKeys, sourceEdgeKeys: edgeKeys, edgeKeys: edges.map((edge) => edge.Key), summary };
    elements.exportMermaid.disabled = !edges.length;
    elements.exportSvg.disabled = !nodes.length;
    currentPngDataUrl = '';
    pngRenderSequence += 1;
    elements.exportPng.disabled = true;
    elements.exportEvidence.disabled = !edges.length;
    elements.graph.replaceChildren();
    elements.graphTextAlternative.replaceChildren();

    if (!nodes.length) {
      elements.relationshipGroups.hidden = true;
      elements.graphSummary.textContent = 'No relationships to display';
      elements.graphDescription.textContent = 'No relationship graph is currently displayed.';
      return;
    }

    const selectedNode = nodes.find((node) => node.Key === selectedKey);
    const hubLayout = Boolean(
      selectedNode &&
      nodes.length > 4 &&
      edges.length &&
      edges.every((edge) => edge.From === selectedNode.Key || edge.To === selectedNode.Key)
    );
    let width = 640;
    let height = 720;
    const positions = new Map();

    if (hubLayout) {
      width = 760;
      const relatedNodes = nodes.filter((node) => node.Key !== selectedNode.Key);
      const neighbourTop = 315;
      const rowGap = 142;
      const rowCount = Math.ceil(relatedNodes.length / 2);
      height = Math.max(720, neighbourTop + ((rowCount - 1) * rowGap) + 90);
      positions.set(selectedNode.Key, { x: width / 2, y: 130 });
      relatedNodes.forEach((node, index) => {
        positions.set(node.Key, {
          x: index % 2 === 0 ? 210 : 550,
          y: neighbourTop + (Math.floor(index / 2) * rowGap)
        });
      });
    }
    else {
      const top = nodes.length === 1 ? height / 2 : 150;
      const gap = nodes.length > 1 ? 138 : 0;
      height = Math.max(720, top + ((nodes.length - 1) * gap) + 100);
      nodes.forEach((node, index) => {
        positions.set(node.Key, { x: width / 2, y: top + (gap * index) });
      });
    }

    elements.graph.setAttribute('viewBox', `0 0 ${width} ${height}`);
    elements.graph.style.height = `${height}px`;
    elements.graph.setAttribute('preserveAspectRatio', 'xMidYMin meet');

    for (const edge of edges) {
      const from = positions.get(edge.From);
      const to = positions.get(edge.To);
      if (!from || !to) {
        continue;
      }
      const labelText = formatRelationship(edge.Relationship);
      const labelWidth = Math.max(84, labelText.length * 7.2);
      let labelX = width / 2;
      let labelY = (from.y + to.y) / 2;

      if (hubLayout) {
        const relatedKey = edge.From === selectedNode.Key ? edge.To : edge.From;
        const related = positions.get(relatedKey);
        const root = positions.get(selectedNode.Key);
        const relatedIsLeft = related.x < root.x;
        const endX = related.x + (relatedIsLeft ? 150 : -150);
        const outerX = relatedIsLeft ? 24 : width - 24;
        const path = document.createElementNS(namespace, 'path');
        path.setAttribute(
          'd',
          `M ${root.x} ${root.y + 46} C ${root.x} ${root.y + 110}, ${outerX} ${related.y}, ${endX} ${related.y}`
        );
        path.setAttribute('class', 'graph-edge');
        elements.graph.append(path);
        labelX = related.x;
        labelY = related.y - 66;
      }
      else {
        const line = document.createElementNS(namespace, 'line');
        const fromComesFirst = from.y <= to.y;
        line.setAttribute('x1', from.x);
        line.setAttribute('y1', from.y + (fromComesFirst ? 46 : -46));
        line.setAttribute('x2', to.x);
        line.setAttribute('y2', to.y + (fromComesFirst ? -46 : 46));
        line.setAttribute('class', 'graph-edge');
        elements.graph.append(line);
      }

      const labelBackground = document.createElementNS(namespace, 'rect');
      labelBackground.setAttribute('x', labelX - (labelWidth / 2));
      labelBackground.setAttribute('y', labelY - 15);
      labelBackground.setAttribute('width', labelWidth);
      labelBackground.setAttribute('height', 30);
      labelBackground.setAttribute('rx', 15);
      labelBackground.setAttribute('class', 'graph-edge-label-bg');
      elements.graph.append(labelBackground);

      const label = document.createElementNS(namespace, 'text');
      label.setAttribute('x', labelX);
      label.setAttribute('y', labelY + 4);
      label.setAttribute('class', 'graph-edge-label');
      label.textContent = labelText;
      elements.graph.append(label);
    }

    for (const node of nodes) {
      const position = positions.get(node.Key);
      const group = document.createElementNS(namespace, 'g');
      group.setAttribute(
        'class',
        `graph-node graph-node-${node.Kind}${node.Key === selectedKey ? ' selected' : ''}`
      );
      group.setAttribute('tabindex', '0');
      group.setAttribute('role', 'button');
      group.setAttribute('aria-label', `Open ${node.DisplayName}, ${formatKind(node.Kind)}`);
      group.addEventListener('click', () => selectNode(node.Key));
      group.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          selectNode(node.Key);
        }
      });

      const rect = document.createElementNS(namespace, 'rect');
      rect.setAttribute('x', position.x - 150);
      rect.setAttribute('y', position.y - 46);
      rect.setAttribute('width', 300);
      rect.setAttribute('height', 92);
      rect.setAttribute('rx', 8);
      rect.setAttribute('class', 'node-card');

      const iconTile = document.createElementNS(namespace, 'rect');
      iconTile.setAttribute('x', position.x - 130);
      iconTile.setAttribute('y', position.y - 28);
      iconTile.setAttribute('width', 56);
      iconTile.setAttribute('height', 56);
      iconTile.setAttribute('rx', 8);
      iconTile.setAttribute('class', 'graph-icon-tile');

      const iconImage = document.createElementNS(namespace, 'image');
      iconImage.setAttribute('href', graphIconHref(node.Kind));
      iconImage.setAttribute('x', position.x - 115);
      iconImage.setAttribute('y', position.y - 13);
      iconImage.setAttribute('width', 26);
      iconImage.setAttribute('height', 26);
      iconImage.setAttribute('class', 'graph-node-image');

      const label = document.createElementNS(namespace, 'text');
      label.setAttribute('x', position.x - 58);
      label.setAttribute('y', position.y - 5);
      label.setAttribute('class', 'graph-node-label');
      label.textContent = graphLabel(node);

      const kindLabel = document.createElementNS(namespace, 'text');
      kindLabel.setAttribute('x', position.x - 58);
      kindLabel.setAttribute('y', position.y + 18);
      kindLabel.setAttribute('class', 'graph-node-kind');
      kindLabel.textContent = formatKind(node.Kind);

      group.append(rect, iconTile, iconImage, label, kindLabel);
      elements.graph.append(group);
    }

    elements.graphSummary.textContent = summary;
    elements.graphDescription.textContent =
      `${summary}. ${nodes.map((node) => `${node.DisplayName}, ${formatKind(node.Kind)}`).join('; ')}.`;

    const list = makeElement('ol', 'graph-path-list');
    for (const edge of edges) {
      const from = nodesByKey.get(edge.From);
      const to = nodesByKey.get(edge.To);
      if (from && to) {
        list.append(makeElement('li', null, `${from.DisplayName} ${edge.Relationship} ${to.DisplayName}`));
      }
    }
    elements.graphTextAlternative.append(list);
    prepareCurrentPng(pngRenderSequence);
  }

  const relationshipGroupOrder = [
    'Roles',
    'Policies',
    'Governance',
    'External access',
    'Applications',
    'Groups',
    'Devices',
    'Authentication methods',
    'Identities',
    'Other'
  ];

  function relationshipGroupFor(edge, nodeKey) {
    const relatedKey = edge.From === nodeKey ? edge.To : edge.From;
    const kind = nodesByKey.get(relatedKey)?.Kind;
    if (kind === 'roleDefinition') {
      return 'Roles';
    }
    if (['conditionalAccessPolicy', 'conditionalAccessScope', 'namedLocation', 'authenticationStrength'].includes(kind)) {
      return 'Policies';
    }
    if (['applicationManagementPolicy'].includes(kind)) {
      return 'Policies';
    }
    if (['administrativeUnit', 'accessPackageCatalog', 'accessPackage', 'accessPackageAssignmentPolicy', 'entitlementResource', 'entitlementSubject', 'accessReviewDefinition', 'accessReviewInstance', 'accessReviewReviewerScope'].includes(kind)) {
      return 'Governance';
    }
    if (['crossTenantAccessPolicy', 'externalTenant'].includes(kind)) {
      return 'External access';
    }
    if (['servicePrincipal', 'application', 'applicationCredential', 'apiPermission', 'oauth2PermissionGrant'].includes(kind)) {
      return 'Applications';
    }
    if (kind === 'group') {
      return 'Groups';
    }
    if (kind === 'device') {
      return 'Devices';
    }
    if (kind === 'authenticationMethod') {
      return 'Authentication methods';
    }
    if (['user', 'guestUser'].includes(kind)) {
      return 'Identities';
    }
    return 'Other';
  }

  function renderRelationshipGroupControls(nodeKey, groups, activeGroups, totalRelationships) {
    elements.relationshipGroups.replaceChildren();
    const groupNames = relationshipGroupOrder.filter((name) => groups.has(name));
    if (totalRelationships <= 6 || groupNames.length < 2) {
      elements.relationshipGroups.hidden = true;
      return;
    }

    const heading = makeElement('div', 'relationship-groups-heading');
    heading.append(
      makeElement('strong', null, 'Relationship groups'),
      makeElement('span', null, `${activeGroups.size} of ${groupNames.length} shown`)
    );
    const controls = makeElement('div', 'relationship-group-buttons');
    for (const name of groupNames) {
      const button = makeElement('button', 'relationship-group-button', `${name} ${groups.get(name).length}`);
      button.type = 'button';
      button.setAttribute('aria-pressed', String(activeGroups.has(name)));
      button.addEventListener('click', () => {
        if (activeGroups.has(name)) {
          activeGroups.delete(name);
        }
        else {
          activeGroups.add(name);
        }
        relationshipGroupState.set(nodeKey, activeGroups);
        renderNeighbourGraph(nodeKey);
      });
      controls.append(button);
    }

    const allButton = makeElement(
      'button',
      'relationship-group-reset',
      activeGroups.size === groupNames.length ? 'Clear groups' : 'Show all'
    );
    allButton.type = 'button';
    allButton.addEventListener('click', () => {
      if (activeGroups.size === groupNames.length) {
        activeGroups.clear();
      }
      else {
        activeGroups.clear();
        groupNames.forEach((name) => activeGroups.add(name));
      }
      relationshipGroupState.set(nodeKey, activeGroups);
      renderNeighbourGraph(nodeKey);
    });
    controls.append(allButton);
    elements.relationshipGroups.append(heading, controls);
    elements.relationshipGroups.hidden = false;
  }

  function renderNeighbourGraph(nodeKey) {
    currentPath = null;
    const allRelationships = nodeRelationships(nodeKey);
    const groups = new Map();
    for (const edge of allRelationships) {
      const group = relationshipGroupFor(edge, nodeKey);
      if (!groups.has(group)) {
        groups.set(group, []);
      }
      groups.get(group).push(edge);
    }

    const groupNames = relationshipGroupOrder.filter((name) => groups.has(name));
    let activeGroups = relationshipGroupState.get(nodeKey);
    if (!activeGroups) {
      activeGroups = new Set(groupNames);
      relationshipGroupState.set(nodeKey, activeGroups);
    }
    for (const name of Array.from(activeGroups)) {
      if (!groups.has(name)) {
        activeGroups.delete(name);
      }
    }

    const selectedGroupEdges = groupNames
      .filter((name) => activeGroups.has(name))
      .map((name) => [...groups.get(name)]);
    const relationships = [];
    while (relationships.length < 24 && selectedGroupEdges.some((items) => items.length)) {
      for (const items of selectedGroupEdges) {
        if (items.length && relationships.length < 24) {
          relationships.push(items.shift());
        }
      }
    }

    renderRelationshipGroupControls(nodeKey, groups, activeGroups, allRelationships.length);
    const nodeKeys = [nodeKey];
    const edgeKeys = [];

    for (const edge of relationships) {
      edgeKeys.push(edge.Key);
      nodeKeys.push(edge.From === nodeKey ? edge.To : edge.From);
    }

    renderGraph(
      Array.from(new Set(nodeKeys)),
      edgeKeys,
      relationships.length === allRelationships.length
        ? `${allRelationships.length} collected relationship${allRelationships.length === 1 ? '' : 's'}`
        : `${allRelationships.length} collected relationships, ${relationships.length} shown`
    );
  }

  function createNarrative(path) {
    const nodes = path.nodeKeys.map((key) => nodesByKey.get(key));
    const edges = path.edgeKeys.map((key) => edgesByKey.get(key));
    if (edges.length === 1) {
      if (['pimActiveOwner', 'pimEligibleOwner'].includes(edges[0].Relationship)) {
        return `${nodes[0].DisplayName} has ${formatRelationship(edges[0].Relationship)} status for ${nodes[1].DisplayName}. Ownership is not group membership.`;
      }
      if (edges[0].Relationship === 'ownedBy') {
        return `${nodes[0].DisplayName} is owned by ${nodes[1].DisplayName}.`;
      }
      if (edges[0].Relationship === 'hasCredential') {
        return `${nodes[0].DisplayName} has credential ${nodes[1].DisplayName}.`;
      }
      if (edges[0].Relationship === 'requiresApiPermission') {
        return `${nodes[0].DisplayName} requires ${nodes[1].DisplayName}.`;
      }
      if (edges[0].Relationship === 'eligibleRole') {
        return `${nodes[0].DisplayName} is eligible for ${nodes[1].DisplayName}.`;
      }
      if (nodes[1].Kind === 'conditionalAccessPolicy') {
        return `${nodes[0].DisplayName} is included in the ${nodes[1].DisplayName} Conditional Access policy.`;
      }
      if (nodes[1].Kind === 'device') {
        return `${nodes[0].DisplayName} is a registered owner of ${nodes[1].DisplayName}.`;
      }
      if (nodes[1].Kind === 'authenticationMethod') {
        return `${nodes[0].DisplayName} has the ${nodes[1].DisplayName} authentication method.`;
      }
      if (nodes[1].Kind === 'servicePrincipal') {
        const appRoleName = edges[0].State.appRoleDisplayName || 'an app role';
        return `${nodes[0].DisplayName} has a direct assignment to ${appRoleName} on ${nodes[1].DisplayName}.`;
      }
      if (nodes[1].Kind === 'administrativeUnit') {
        return `${nodes[0].DisplayName} ${formatRelationship(edges[0].Relationship).toLocaleLowerCase('en-GB')} ${nodes[1].DisplayName}.`;
      }
      if (nodes[1].Kind === 'accessPackage') {
        return `${nodes[0].DisplayName} has the ${nodes[1].DisplayName} access package.`;
      }
      if (nodes[1].Kind === 'accessReviewInstance') {
        return `${nodes[0].DisplayName} was included in ${nodes[1].DisplayName}.`;
      }
      return `${nodes[0].DisplayName} has a collected ${formatRelationship(edges[0].Relationship).toLocaleLowerCase('en-GB')} relationship to ${nodes[1].DisplayName}.`;
    }
    if (edges.length > 2) {
      const steps = edges.map((edge, index) => `${formatRelationship(edge.Relationship)} ${nodes[index + 1].DisplayName}`);
      return `${nodes[0].DisplayName} reaches ${nodes[nodes.length - 1].DisplayName} through ${steps.join(', then ')}.`;
    }
    if (nodes[1].Kind === 'accessPackage') {
      return `${nodes[0].DisplayName} has the ${nodes[1].DisplayName} access package, which grants ${formatRelationship(edges[1].Relationship).toLocaleLowerCase('en-GB')} on ${nodes[2].DisplayName}.`;
    }
    if (['pimActiveMember', 'pimEligibleMember', 'pimActiveOwner', 'pimEligibleOwner'].includes(edges[0].Relationship)) {
      return `${nodes[0].DisplayName} is connected to ${nodes[1].DisplayName} through ${formatRelationship(edges[0].Relationship).toLocaleLowerCase('en-GB')}. ` +
        `${nodes[1].DisplayName} has ${formatRelationship(edges[1].Relationship).toLocaleLowerCase('en-GB')} to ${nodes[2].DisplayName}.`;
    }
    if (nodes[2].Kind === 'servicePrincipal') {
      const appRoleName = edges[1].State.appRoleDisplayName || 'an app role';
      return `${nodes[0].DisplayName} is a direct member of ${nodes[1].DisplayName}. ` +
        `${nodes[1].DisplayName} has ${appRoleName} on ${nodes[2].DisplayName}.`;
    }
    if (nodes[2].Kind === 'conditionalAccessPolicy') {
      return `${nodes[0].DisplayName} is a direct member of ${nodes[1].DisplayName}. ` +
        `${nodes[1].DisplayName} is included in the ${nodes[2].DisplayName} Conditional Access policy.`;
    }
    return `${nodes[0].DisplayName} is a direct member of ${nodes[1].DisplayName}. ` +
      `${nodes[1].DisplayName} has a collected ${formatRelationship(edges[1].Relationship).toLocaleLowerCase('en-GB')} relationship to ${nodes[2].DisplayName}.`;
  }

  function pathConfidence(path) {
    const details = [];
    let completeEvidence = 0;
    let expectedEvidence = 0;

    for (const edgeKey of path.edgeKeys) {
      const edge = edgesByKey.get(edgeKey);
      if (!edge) {
        details.push('Missing relationship record.');
        continue;
      }
      if (!edge.EvidenceIds || !edge.EvidenceIds.length) {
        details.push(`${formatRelationship(edge.Relationship)} has no evidence record.`);
        continue;
      }
      for (const evidenceId of edge.EvidenceIds) {
        expectedEvidence += 1;
        const evidence = evidenceByKey.get(evidenceId);
        if (evidence && String(evidence.Completeness || '').toLocaleLowerCase('en-GB') === 'complete') {
          completeEvidence += 1;
        }
        else {
          details.push(`${formatRelationship(edge.Relationship)} has partial or missing evidence.`);
        }
      }
    }

    if (!expectedEvidence) {
      return {
        label: 'Evidence unavailable',
        score: 30,
        severity: 'High',
        detail: details.join(' ')
      };
    }

    const score = Math.round((completeEvidence / expectedEvidence) * 100);
    if (score === 100 && !details.length) {
      return {
        label: 'Evidence complete',
        score,
        severity: 'Low',
        detail: 'Every relationship has collected evidence. This does not prove effective authorisation or a successful sign-in.'
      };
    }
    if (score >= 60) {
      return {
        label: 'Evidence partial',
        score,
        severity: 'Medium',
        detail: details.join(' ') || 'Most relationship evidence is complete.'
      };
    }
    return {
      label: 'Evidence partial',
      score,
      severity: 'High',
      detail: details.join(' ') || 'Evidence coverage is limited.'
    };
  }

  function renderPathDetail(path, index) {
    elements.pathDetail.replaceChildren();
    currentPath = path;
    const nodes = path.nodeKeys.map((key) => nodesByKey.get(key));
    const edges = path.edgeKeys.map((key) => edgesByKey.get(key));
    const confidence = pathConfidence(path);

    elements.pathDetail.append(
      makeElement('p', 'path-number', `Path ${index + 1}`),
      makeElement('h3', null, nodes[nodes.length - 1].DisplayName),
      makeElement('span', `confidence-badge ${severityClass(confidence.severity)}`, confidence.label),
      makeElement('p', 'path-narrative', path.classification || 'Collected relationship'),
      makeElement('p', 'path-narrative', `Assignment: ${path.assignmentState || 'Unknown'}`),
      makeElement('p', 'path-narrative', `Report observed at: ${path.observedAt || report.manifest.generatedAtUtc}. Individual evidence timestamps appear below.`),
      makeElement('p', 'path-narrative', createNarrative(path)),
      makeElement('p', 'path-narrative', confidence.detail)
    );
    elements.pageSubtitle.textContent =
      `Explore the collected access relationship between ${nodes[0].DisplayName} and ${nodes[nodes.length - 1].DisplayName}.`;

    const stepsHeading = makeElement('h4', null, 'Evidence');
    const steps = makeElement('div', 'evidence-list');
    elements.pathDetail.append(stepsHeading, steps);

    edges.forEach((edge, edgeIndex) => {
      const from = nodesByKey.get(edge.From);
      const to = nodesByKey.get(edge.To);
      const card = makeElement('section', 'evidence-card');
      card.append(
        makeElement('p', 'evidence-step', `Step ${edgeIndex + 1}`),
        makeElement('h5', null, `${from.DisplayName} ${formatRelationship(edge.Relationship)} ${to.DisplayName}`)
      );

      for (const evidenceId of edge.EvidenceIds) {
        const evidence = evidenceByKey.get(evidenceId);
        if (!evidence) {
          continue;
        }
        const details = makeElement('dl', 'evidence-properties');
        for (const [name, value] of Object.entries({
          Collector: evidence.Collector,
          Endpoint: evidence.Endpoint,
          'Observed at UTC': new Date(evidence.CollectedAtUtc).toISOString(),
          Completeness: evidence.Completeness
        })) {
          details.append(makeElement('dt', null, name), makeElement('dd', null, formatValue(value)));
        }
        card.append(details);
      }
      steps.append(card);
    });

    elements.relationshipGroups.hidden = true;
    renderGraph(path.nodeKeys, path.edgeKeys, `Access path to ${nodes[nodes.length - 1].DisplayName}`);
  }

  function renderPaths(paths) {
    elements.pathList.replaceChildren();
    elements.pathDetail.replaceChildren();
    elements.explanationStatus.textContent =
      paths.length
        ? `${paths.length} collected route${paths.length === 1 ? '' : 's'} found.`
        : 'No supported route was found in the collected data. This is not proof of no access.';
    if (paths.diagnostics?.truncated) elements.explanationStatus.textContent += ` Results limited: ${paths.diagnostics.reason}`;

    paths.forEach((path, index) => {
      const target = nodesByKey.get(path.nodeKeys[path.nodeKeys.length - 1]);
      const button = makeElement('button', 'path-item');
      button.type = 'button';
      button.append(
        makeElement('span', 'path-target', target.DisplayName),
        makeElement('span', 'path-classification', `${path.classification || 'Collected relationship'} | ${pathConfidence(path).label}`)
      );
      button.addEventListener('click', () => {
        for (const sibling of elements.pathList.querySelectorAll('button')) {
          sibling.classList.toggle('selected', sibling === button);
        }
        renderPathDetail(path, index);
      });
      elements.pathList.append(button);
    });

    if (paths.length) {
      const priorityKeys = Array.from(new Set(paths.flatMap((path) => path.nodeKeys)));
      for (const key of priorityKeys.slice().reverse()) {
        const resultButton = elements.searchResults.querySelector(`[data-node-key="${CSS.escape(key)}"]`);
        if (resultButton) {
          elements.searchResults.prepend(resultButton.parentElement);
        }
      }
      const firstButton = elements.pathList.querySelector('button');
      firstButton.classList.add('selected');
      renderPathDetail(paths[0], 0);
    }
  }

  async function explainSelectedAccess() {
    const node = nodesByKey.get(selectedKey);
    if (!node || !['user', 'guestUser', 'application', 'servicePrincipal'].includes(node.Kind)) {
      return;
    }

    setInspectorTab('evidence');
    elements.explanationStatus.textContent = `Tracing access paths for ${node.DisplayName}.`;
    elements.pathList.replaceChildren();
    elements.pathDetail.replaceChildren();
    const messageType = ['application', 'servicePrincipal'].includes(node.Kind)
      ? 'explainApplicationAccess'
      : 'explainUserAccess';
    const paths = await requestWorker(messageType, { startKey: node.Key });
    renderPaths(paths);
    if (window.matchMedia('(max-width: 820px)').matches) {
      elements.explanationPanel.scrollIntoView({ block: 'start', behavior: 'smooth' });
    }
  }

  function downloadTextFile(fileName, content, type) {
    const blob = new Blob([content], { type });
    downloadBlob(fileName, blob);
  }

  function downloadBlob(fileName, blob) {
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = fileName;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  }

  function downloadDataUrl(fileName, dataUrl) {
    const link = document.createElement('a');
    link.href = dataUrl;
    link.download = fileName;
    document.body.append(link);
    link.click();
    link.remove();
  }

  function mermaidSafeLabel(node) {
    return `${node.DisplayName} (${formatKind(node.Kind)})`.replace(/"/g, "'");
  }

  function exportCurrentMermaid() {
    const lines = ['flowchart TD'];
    const graphNodes = new Set();
    for (const edgeKey of currentGraph.edgeKeys) {
      const edge = edgesByKey.get(edgeKey);
      if (edge) {
        graphNodes.add(edge.From);
        graphNodes.add(edge.To);
      }
    }
    for (const nodeKey of graphNodes) {
      const node = nodesByKey.get(nodeKey);
      if (node) {
        lines.push(`  ${CSS.escape(node.Key).replace(/[^a-zA-Z0-9_]/g, '_')}["${mermaidSafeLabel(node)}"]`);
      }
    }
    for (const edgeKey of currentGraph.edgeKeys) {
      const edge = edgesByKey.get(edgeKey);
      if (!edge) {
        continue;
      }
      const fromId = CSS.escape(edge.From).replace(/[^a-zA-Z0-9_]/g, '_');
      const toId = CSS.escape(edge.To).replace(/[^a-zA-Z0-9_]/g, '_');
      lines.push(`  ${fromId} -->|"${formatRelationship(edge.Relationship)}"| ${toId}`);
    }
    downloadTextFile('identity-atlas-graph.mmd', `${lines.join('\n')}\n`, 'text/plain');
  }

  async function currentGraphSvgContent() {
    if (!currentGraph.nodeKeys.length) {
      return '';
    }
    const clone = elements.graph.cloneNode(true);
    clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    clone.setAttribute('width', '640');
    clone.setAttribute('height', '720');
    for (const image of clone.querySelectorAll('image')) {
      const href = image.getAttribute('href');
      const allowed = new Set(report.nodes.map(n => graphIconHref(n.Kind)));
      if (!allowed.has(href) || !/^assets\/icons\/[a-z0-9-]+\.svg$/.test(href)) { image.remove(); continue; }
      try {
        const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        for (const attr of ['x', 'y', 'width', 'height']) icon.setAttribute(attr, image.getAttribute(attr));
        icon.setAttribute('viewBox', '0 0 24 24'); icon.setAttribute('fill', 'none'); icon.setAttribute('stroke', '#102033'); icon.setAttribute('stroke-width', '2'); icon.setAttribute('stroke-linecap', 'round'); icon.setAttribute('stroke-linejoin', 'round');
        for (const path of exportIconPaths[href] || exportIconPaths['assets/icons/apps.svg']) { const clean = document.createElementNS('http://www.w3.org/2000/svg', 'path'); clean.setAttribute('d', path); icon.append(clean); }
        image.replaceWith(icon);
      } catch { image.remove(); }
    }
    const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
    title.textContent = currentGraph.summary || 'Identity Atlas graph';
    clone.prepend(title);
    const styles = document.createElementNS('http://www.w3.org/2000/svg', 'style');
    styles.textContent = `
      .graph-edge { fill: none; stroke: #a7b4c2; stroke-width: 2; }
      .graph-edge-label-bg { fill: #ffffff; stroke: #d9e2eb; }
      .graph-edge-label { fill: #425466; font: 600 12px Arial, sans-serif; text-anchor: middle; }
      .node-card { fill: #ffffff; stroke: #cfd9e4; stroke-width: 1.5; }
      .graph-icon-tile { fill: #e9f7f8; }
      .graph-node-label { fill: #102033; font: 700 14px Arial, sans-serif; }
      .graph-node-kind { fill: #5d6c7d; font: 12px Arial, sans-serif; }
      .graph-node.selected .node-card { stroke: #49a4ad; stroke-width: 2.5; }
    `;
    clone.prepend(styles);
    return new XMLSerializer().serializeToString(clone);
  }

  async function exportCurrentSvg() {
    const content = await currentGraphSvgContent();
    if (!content) {
      return;
    }
    downloadTextFile('identity-atlas-graph.svg', content, 'image/svg+xml');
  }

  async function prepareCurrentPng(renderSequence) {
    const content = await currentGraphSvgContent();
    if (!content) {
      return;
    }

    const image = new Image();
    const blobUrl = URL.createObjectURL(new Blob([content], { type: 'image/svg+xml' }));
    image.decoding = 'async';
    const loaded = new Promise((resolve, reject) => {
      image.onload = resolve;
      image.onerror = reject;
    });
    image.src = blobUrl;
    try {
      await loaded;
      if (renderSequence !== pngRenderSequence) {
        return;
      }
      const canvas = document.createElement('canvas');
      canvas.width = 1280;
      canvas.height = 1440;
      const context = canvas.getContext('2d');
      context.fillStyle = '#fbfcfd';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      currentPngDataUrl = canvas.toDataURL('image/png');
      elements.exportPng.disabled = false;
      elements.exportPng.dataset.ready = 'true';
    }
    catch {
      currentPngDataUrl = '';
      elements.exportPng.disabled = true;
      elements.exportPng.dataset.ready = 'false';
    }
    finally {
      URL.revokeObjectURL(blobUrl);
    }
  }

  function exportCurrentPng() {
    if (!currentPngDataUrl) {
      return;
    }
    downloadDataUrl('identity-atlas-graph.png', currentPngDataUrl);
  }

  function exportCurrentEvidence() {
    const edgeKeys = currentPath ? currentPath.edgeKeys : currentGraph.edgeKeys;
    const lines = [
      '# Identity Atlas evidence export',
      '',
      `Generated from local report: ${report.manifest.generatedAtUtc}`,
      `Tenant: ${report.manifest.tenant.displayName}`,
      `Coverage: ${report.manifest.coverage.status}`,
      ''
    ];
    for (const edgeKey of edgeKeys) {
      const edge = edgesByKey.get(edgeKey);
      if (!edge) {
        continue;
      }
      const from = nodesByKey.get(edge.From);
      const to = nodesByKey.get(edge.To);
      lines.push(`## ${from ? from.DisplayName : edge.From} ${formatRelationship(edge.Relationship)} ${to ? to.DisplayName : edge.To}`);
      lines.push('');
      lines.push(`Relationship: ${edge.Relationship}`);
      lines.push(`State: ${formatValue(edge.State)}`);
      for (const evidenceId of edge.EvidenceIds) {
        const evidence = evidenceByKey.get(evidenceId);
        if (!evidence) {
          continue;
        }
        lines.push('');
        lines.push(`Collector: ${evidence.Collector}`);
        lines.push(`Endpoint: ${evidence.Endpoint}`);
        lines.push(`Observed at UTC: ${new Date(evidence.CollectedAtUtc).toISOString()}`);
        lines.push(`Completeness: ${evidence.Completeness}`);
      }
      lines.push('');
    }
    if (currentPath) lines.push(`Interpretation: ${currentPath.classification || 'Collected relationship'}`, 'Collected evidence does not prove effective authorisation.');
    previewEvidenceExport(`${lines.join('\n')}\n`, maskedEvidence(edgeKeys.map((key) => edgesByKey.get(key)).filter(Boolean)), 'identity-atlas-evidence.md');
  }

  function maskedEvidence(edges) {
    // Deliberate allowlist: no tenant strings, identifiers, state, endpoints,
    // descriptions or remediation commands enter a masked export.
    const aliases = new Map();
    const alias = (key) => { if (!aliases.has(key)) aliases.set(key, `Object ${aliases.size + 1}`); return aliases.get(key); };
    const allowed = new Set(['memberOf', 'assignedRole', 'eligibleRole', 'assignedAppRole', 'ownedBy', 'hasCredential', 'requiresApiPermission', 'registeredDevice', 'hasAuthenticationMethod', 'conditionalAccessIncludes', 'conditionalAccessExcludes', 'pimActiveMember', 'pimEligibleMember', 'pimActiveOwner', 'pimEligibleOwner', 'hasDelegatedConsent', 'grantsDelegatedScopes']);
    const lines = ['# Identity Atlas masked evidence', '', 'Identifiers, names, free text and remediation commands omitted. Relationship structure can still be sensitive. Review before sharing.', 'Evidence is not proof of effective authorisation.', ''];
    for (const edge of edges) lines.push(`${alias(edge.From)} > ${allowed.has(edge.Relationship) ? formatRelationship(edge.Relationship) : 'Collected relationship'} > ${alias(edge.To)}`);
    return lines.join('\n');
  }

  function previewEvidenceExport(fullText, maskedText, fileName) {
    const dialog = makeElement('dialog', 'evidence-export-dialog');
    const heading = makeElement('h3', null, 'Review evidence before exporting');
    heading.id = 'evidence-export-heading';
    dialog.setAttribute('aria-labelledby', heading.id);
    const label = makeElement('label', null, ' Mask tenant fields');
    const mask = makeElement('input');
    mask.type = 'checkbox'; mask.checked = true; label.prepend(mask);
    const preview = makeElement('pre', null, maskedText);
    const save = makeElement('button', null, 'Download reviewed evidence'); save.type = 'button';
    const close = makeElement('button', null, 'Cancel'); close.type = 'button';
    mask.addEventListener('change', () => { preview.textContent = mask.checked ? maskedText : fullText; });
    save.addEventListener('click', () => { downloadTextFile(fileName, mask.checked ? maskedText : fullText, 'text/markdown'); dialog.close(); });
    close.addEventListener('click', () => dialog.close());
    dialog.addEventListener('close', () => dialog.remove());
    dialog.append(heading, makeElement('p', null, 'Full evidence contains sensitive tenant data. Masking reduces disclosure; it does not guarantee anonymity.'), label, preview, save, close);
    document.body.append(dialog); dialog.showModal();
  }

  function populateRelationshipFilter() {
    const relationships = Array.from(new Set(report.edges.map((edge) => edge.Relationship))).sort();
    for (const relationship of relationships) {
      const option = makeElement('option', null, formatRelationship(relationship));
      option.value = relationship;
      elements.relationshipFilter.append(option);
    }
  }

  elements.globalSearch.addEventListener('input', scheduleSearch);
  elements.kindFilter.addEventListener('change', updateSearch);
  elements.relationshipFilter.addEventListener('change', () => {
    renderGraph(currentGraph.nodeKeys, currentGraph.sourceEdgeKeys, currentGraph.summary);
  });
  elements.exportMermaid.addEventListener('click', exportCurrentMermaid);
  elements.exportSvg.addEventListener('click', exportCurrentSvg);
  elements.exportPng.addEventListener('click', exportCurrentPng);
  elements.exportEvidence.addEventListener('click', exportCurrentEvidence);
  for (const item of elements.navItems) {
    item.addEventListener('click', () => setActiveView(item.dataset.view));
  }
  elements.showNeighbours.addEventListener('click', () => {
    if (selectedKey) {
      renderNeighbourGraph(selectedKey);
    }
  });
  elements.explainAccess.addEventListener('click', explainSelectedAccess);
  elements.headerExplainAccess.addEventListener('click', explainSelectedAccess);
  elements.closeExplanation.addEventListener('click', () => {
    setInspectorTab('details');
    elements.explainAccess.focus();
  });
  elements.detailsTab.addEventListener('click', () => setInspectorTab('details'));
  elements.selectionBack.addEventListener('click', () => {
    const previousKey = selectionHistory.pop();
    if (previousKey) {
      selectNode(previousKey, { recordHistory: false });
      elements.objectHeading.focus();
    }
  });
  elements.pinObject.addEventListener('click', () => {
    if (!selectedKey) {
      return;
    }
    if (pinnedKeys.has(selectedKey)) {
      pinnedKeys.delete(selectedKey);
    }
    else {
      pinnedKeys.add(selectedKey);
    }
    savePinnedKeys();
    renderPinnedObjects();
    updatePinButton();
  });
  elements.evidenceTab.addEventListener('click', () => {
    if (elements.pathDetail.childElementCount) {
      setInspectorTab('evidence');
    }
    else {
      explainSelectedAccess();
    }
  });
  elements.copyObjectId.addEventListener('click', async () => {
    const objectId = elements.copyObjectId.dataset.objectId;
    if (!objectId || !navigator.clipboard) {
      return;
    }
    await navigator.clipboard.writeText(objectId);
    elements.copyObjectId.setAttribute('aria-label', 'Object ID copied');
    window.setTimeout(() => elements.copyObjectId.setAttribute('aria-label', 'Copy object ID'), 1500);
  });
  function setGraphZoom(nextZoom) {
    graphZoom = Math.max(0.8, Math.min(1.4, nextZoom));
    elements.graph.style.setProperty('--graph-zoom', graphZoom);
    elements.zoomValue.textContent = `${Math.round(graphZoom * 100)}%`;
  }
  elements.fitGraph.addEventListener('click', () => setGraphZoom(1));
  elements.graphSettings.addEventListener('click', () => setActiveView('settings'));
  elements.zoomOut.addEventListener('click', () => setGraphZoom(graphZoom - 0.1));
  elements.zoomIn.addEventListener('click', () => setGraphZoom(graphZoom + 0.1));
  elements.viewAllObjects.addEventListener('click', () => {
    elements.globalSearch.value = '';
    elements.kindFilter.value = '';
    updateSearch().then(() => elements.globalSearch.focus());
  });
  elements.contextOpen.addEventListener('click', () => {
    elements.contextMenu.hidden = true;
    if (contextKey) {
      selectNode(contextKey);
    }
  });
  elements.contextExplain.addEventListener('click', async () => {
    elements.contextMenu.hidden = true;
    if (contextKey) {
      selectNode(contextKey);
      await explainSelectedAccess();
    }
  });
  document.addEventListener('click', (event) => {
    if (!elements.contextMenu.contains(event.target)) {
      elements.contextMenu.hidden = true;
    }
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      elements.contextMenu.hidden = true;
    }
  });
  applyLayoutSettings();
  adminWorkspace = window.IdentityAtlasAdmin.mount(report, {
    viewChanged: title => { viewGeneration++; elements.headerExplainAccess.disabled = true; document.querySelector('.page-heading .eyebrow').textContent = 'ADMINISTRATION'; elements.pageSubtitle.textContent = 'Local administration views from collected evidence. Tenant changes are made separately in Microsoft Entra.'; for (const item of elements.navItems) { item.classList.toggle('selected', title === 'Tenant administration' && item.dataset.view === 'overview'); item.removeAttribute('aria-current'); } },
    open: key => setActiveView('access', key),
    coverage: () => renderCoverageDetails(),
    dossier: key => { if (!accessAnalysis) accessAnalysis = createAccessAnalysis(report); return accessAnalysis.dossier(key); },
    download: downloadTextFile,
    graph: (keys, edges) => { selectedKey = null; renderGraph(keys, edges, 'Combined collected relationships'); }
  });
  const directoryButton = makeElement('button', 'nav-item');
  const directoryLabel = makeElement('span');
  directoryLabel.append(makeElement('strong', null, 'Object directory'), makeElement('small', null, 'Tables and administration'));
  directoryButton.append(makeElement('span', 'icon icon-list-details'), directoryLabel);
  directoryButton.type = 'button';
  directoryButton.addEventListener('click', () => adminWorkspace.directory());
  document.querySelector('.product-nav nav').append(directoryButton);
  renderCoverage();
  renderSummaryCards();
  renderPinnedObjects();
  updatePinButton();
  populateRelationshipFilter();
  requestWorker('initialise', { nodes: report.nodes, edges: report.edges, observedAt: report.manifest.generatedAtUtc })
    .then(updateSearch)
    .then(() => {
      setActiveView('overview');
      return null;
    })
    .catch((error) => {
      elements.coverageBanner.classList.add('coverage-error');
      elements.coverageBanner.textContent = `The graph engine could not start: ${error.message}`;
    });
})();
