(function initialiseDataRuntime(global) {
  'use strict';

  const state = {
    manifest: null,
    nodes: [],
    edges: [],
    evidence: []
  };

  global.IdentityAtlasData = {
    registerManifest(manifest) {
      state.manifest = manifest;
    },
    registerNodes(nodes) {
      state.nodes.push(...nodes);
    },
    registerEdges(edges) {
      state.edges.push(...edges);
    },
    registerEvidence(evidence) {
      state.evidence.push(...evidence);
    },
    snapshot() {
      return {
        manifest: state.manifest,
        nodes: state.nodes.slice(),
        edges: state.edges.slice(),
        evidence: state.evidence.slice()
      };
    }
  };
})(window);
