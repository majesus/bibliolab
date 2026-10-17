(function () {
  'use strict';
  // Resaltado del grafo de la lectura enlazada: compartido por el clic en un nodo, el buscador y el resaltado de comunidades.
  window.wikiHL = (function () {
    var DIM = {background: '#e9e9e9', border: '#e0e0e0', highlight: {background: '#e9e9e9', border: '#e0e0e0'}, hover: {background: '#e9e9e9', border: '#e0e0e0'}};
    var EDIM = {color: '#efefef', highlight: '#efefef', hover: '#efefef'};
    var ESTRONG = {color: '#555555', highlight: '#555555', hover: '#555555'};
    var FOCUS = {duration: 600, easingFunction: 'easeInOutQuad'};
    // visNetwork guarda la instancia de vis.Network en el div interior "graph" + id del widget (propiedad chart).
    function network() {
      var el = document.getElementById('graphwiki_graph');
      if (!el) { var outer = document.getElementById('wiki_graph'); el = outer && outer.querySelector('[id^="graph"]'); }
      return el && el.chart ? el.chart : (window.wikiNet || null);
    }
    function snapshot(net) {
      if (!net.__wk) {
        net.__wk = {n: {}, e: {}};
        net.body.data.nodes.forEach(function (x) { net.__wk.n[x.id] = {label: x.label, full: x.fullLabel, color: x.color, bw: x.borderWidth}; });
        net.body.data.edges.forEach(function (x) { net.__wk.e[x.id] = {color: x.color}; });
      }
      return net.__wk;
    }
    function resetCommunity() {
      var s = document.getElementById('wiki_highlight_community');
      if (s && s.selectize && s.value !== 'none') s.selectize.setValue('none', true);
    }
    function restore(net) {
      var W = snapshot(net), N = net.body.data.nodes, E = net.body.data.edges;
      N.update(N.getIds().map(function (k) { var o = W.n[k]; return {id: k, label: o.label, color: o.color, borderWidth: o.bw}; }));
      E.update(E.getIds().map(function (k) { return {id: k, color: W.e[k].color}; }));
      net.unselectAll();
    }
    function ring(color) {
      var fill = (color && typeof color === 'object') ? color.background : color;
      return {background: fill, border: '#c7281e', highlight: {background: fill, border: '#c7281e'}, hover: {background: fill, border: '#c7281e'}};
    }
    function paint(net, keepNodes, keepEdges, target) {
      var W = snapshot(net), N = net.body.data.nodes, E = net.body.data.edges;
      N.update(N.getIds().map(function (k) {
        var o = W.n[k];
        if (k === target) return {id: k, label: (o.full !== undefined ? o.full : o.label), color: ring(o.color), borderWidth: 4};
        return keepNodes[k] ? {id: k, label: (o.full !== undefined ? o.full : o.label), color: o.color, borderWidth: o.bw} : {id: k, label: '', color: DIM, borderWidth: o.bw};
      }));
      E.update(E.getIds().map(function (k) { return {id: k, color: keepEdges[k] ? ESTRONG : EDIM}; }));
    }
    function node(net, id, emphasize) {
      var keep = {}, inc = {};
      keep[id] = 1;
      net.getConnectedNodes(id).forEach(function (k) { keep[k] = 1; });
      net.getConnectedEdges(id).forEach(function (k) { inc[k] = 1; });
      paint(net, keep, inc, emphasize ? id : null);
      resetCommunity();
    }
    function group(net, g) {
      var keep = {}, inc = {}, ids = [];
      net.body.data.nodes.get().forEach(function (x) { if (Number(x.community) === Number(g)) { keep[x.id] = 1; ids.push(x.id); } });
      net.body.data.edges.get().forEach(function (e) { if (keep[e.from] && keep[e.to]) inc[e.id] = 1; });
      paint(net, keep, inc);
      return ids;
    }
    function reset(net, notify) {
      restore(net);
      resetCommunity();
      if (notify && window.Shiny) window.Shiny.setInputValue('wiki_hl_reset', Date.now(), {priority: 'event'});
    }
    return {network: network, node: node, group: group, reset: reset, restore: restore, focus: FOCUS};
  })();
  function connect() {
    if (!window.Shiny) { window.setTimeout(connect, 100); return; }
    function syncTabAccessibility() {
      document.querySelectorAll('[role="tab"]').forEach(function (tab) {
        var item = tab.closest('li');
        var active = Boolean(item && item.classList.contains('active'));
        if (tab.getAttribute('aria-selected') !== String(active)) tab.setAttribute('aria-selected', String(active));
        if (tab.getAttribute('aria-expanded') !== String(active)) tab.setAttribute('aria-expanded', String(active));
      });
    }
    if (window.jQuery) jQuery(document).on('shown.bs.tab shiny:connected shiny:value', syncTabAccessibility);
    // Shiny 1.x puede actualizar también los tabs anidados cuando cambia el padre.
    // Corregir después de esas mutaciones, sin realimentación al escribir el mismo valor.
    var tabObserver = new MutationObserver(syncTabAccessibility);
    tabObserver.observe(document.body, {subtree:true, childList:true, attributes:true,
      attributeFilter:['class','aria-selected','aria-expanded']});
    syncTabAccessibility();
    document.addEventListener('toggle',function(e){
      if(e.target.matches('.ca-figure-controls'))window.dispatchEvent(new Event('resize'));
    },true);
    // Una nota se envía con su página y huella en el mismo mensaje: nunca se
    // asocia el texto antiguo a la nueva página durante la navegación.
    var wikiTimer = null;
    var wikiPendingDownload = null;
    function saveWikiNote() {
      if (wikiTimer) { clearTimeout(wikiTimer); wikiTimer = null; }
      var editor = document.querySelector('.wiki-note');
      if (editor) Shiny.setInputValue('wiki_note_save', {
        node: editor.dataset.wikiNode, scope: editor.dataset.wikiScope,
        text: editor.value, nonce: Date.now()
      }, {priority:'event'});
    }
    document.addEventListener('input', function(e) {
      if (!e.target.matches('.wiki-note')) return;
      if (wikiTimer) clearTimeout(wikiTimer);
      wikiTimer = setTimeout(saveWikiNote, 350);
      var state = document.getElementById('wiki_pending');
      if (state) state.textContent = 'Cambios pendientes de guardar en esta sesión… ';
    });
    document.addEventListener('click', function(e) {
      var download = e.target.closest('#download_wiki, #download_wiki_notes, #download_zip');
      var editor = document.querySelector('.wiki-note');
      if (download && editor) {
        e.preventDefault();
        wikiPendingDownload = {href:download.href,node:editor.dataset.wikiNode,
          scope:editor.dataset.wikiScope,text:editor.value};
        saveWikiNote();
        return;
      }
      var link = e.target.closest('.wiki-link');
      if (link) { saveWikiNote(); Shiny.setInputValue('wiki_navigate', {node:link.dataset.wikiNode,nonce:Date.now()}, {priority:'event'}); }
      if (e.target.closest('.wiki-note-save')) saveWikiNote();
      if (e.target.closest('#wiki_build')) saveWikiNote();
    });
    document.addEventListener('change', function(e) {
      if (e.target.id === 'wiki_document' || e.target.id === 'wiki_term') saveWikiNote();
    });
    document.addEventListener('focusout', function(e) {
      if (e.target.matches('.wiki-note')) saveWikiNote();
    });
    Shiny.addCustomMessageHandler('wikiNoteSaved', function(message) {
      var editor = document.querySelector('.wiki-note');
      if (message.ok && editor && editor.dataset.wikiNode === message.node &&
          editor.dataset.wikiScope === message.scope && editor.value === message.text) {
        var pending = document.getElementById('wiki_pending');
        if (pending) pending.textContent = '';
      }
      if (wikiPendingDownload && wikiPendingDownload.node === message.node &&
          wikiPendingDownload.scope === message.scope && wikiPendingDownload.text === message.text) {
        var href = wikiPendingDownload.href;
        wikiPendingDownload = null;
        if (message.ok) window.location.assign(href);
      }
    });
    window.addEventListener('beforeunload', function(e) {
      var state = document.querySelector('.wiki-save-state');
      if (state && /pendientes|No se ha guardado/.test(state.textContent)) {e.preventDefault();e.returnValue='';}
    });
    Shiny.addCustomMessageHandler('wikiFocusNode', function (m) {
      var net = window.wikiHL.network();
      if (!net || !net.body.data.nodes.get(m.id)) { if (window.console) console.warn('wikiFocusNode: nodo o grafo no encontrado', m.id); return; }
      window.wikiHL.node(net, m.id, true);
      net.selectNodes([m.id]);
      net.focus(m.id, {scale: 1.15, animation: window.wikiHL.focus});
    });
    Shiny.addCustomMessageHandler('wikiClearHighlight', function (_message) {
      var net = window.wikiHL.network();
      if (net) window.wikiHL.reset(net, false);
    });
    if (window.jQuery) {
      window.jQuery(document).on('change', '#wiki_highlight_community', function () {
        var net = window.wikiHL.network();
        if (!net) return;
        if (!this.value || this.value === 'none') { window.wikiHL.restore(net); return; }
        var ids = window.wikiHL.group(net, this.value);
        net.unselectAll();
        if (ids.length) net.fit({nodes: ids, animation: window.wikiHL.focus});
      });
    }
    Shiny.addCustomMessageHandler('analysisBusy', function (busy) {
      document.body.classList.toggle('analysis-running', busy);
      document.querySelectorAll('.run-analysis').forEach(function (button) {
        button.disabled = busy;
        button.setAttribute('aria-busy', String(busy));
      });
    });
    Shiny.addCustomMessageHandler('copyPrompt', async function (text) {
      var feedback = document.getElementById('copy_feedback');
      try {
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
        } else {
          var field = document.createElement('textarea');
          field.value = text;
          field.style.position = 'fixed';
          field.style.opacity = '0';
          document.body.appendChild(field);
          field.select();
          var copied = document.execCommand('copy');
          field.remove();
          if (!copied) throw new Error('Clipboard unavailable');
        }
        feedback.textContent = 'Prompt copiado. Revisa los datos antes de enviarlo a tu herramienta de IA.';
      } catch (_) {
        feedback.textContent = 'El navegador no permite copiar automáticamente. Descarga el archivo .txt o selecciona el texto del prompt.';
      }
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', connect);
  else connect();
})();
