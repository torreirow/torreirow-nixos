// ==UserScript==
// @name         Jitsi: open in desktop-app
// @namespace    torreirow-nixos
// @version      1.0.0
// @description  Stuurt https://meet.jit.si/<kamer> door naar jitsi-meet-electron via het jitsi-meet://-schema.
// @match        https://meet.jit.si/*
// @run-at       document-start
// @grant        none
// @downloadURL  file://@HOME@/.local/share/userscripts/jitsi-open-in-app.user.js
// @updateURL    file://@HOME@/.local/share/userscripts/jitsi-open-in-app.user.js
// ==/UserScript==
//
// Bron: home/module/jitsi-open-in-app/ in torreirow-nixos. Niet hier bewerken,
// maar in de repo -- dit bestand is een symlink naar de nix-store.
//
// Waarom dit bestaat: Firefox handelt https zelf af en kent geen per-domein
// externe handler, dus niets zet een meet.jit.si-link om naar de app. De
// onderkant van de keten werkt al: jitsi-meet-electron.desktop is geregistreerd
// voor x-scheme-handler/jitsi-meet, en de app pakt een tweede aanroep op via
// zijn singleInstanceLock. Alleen de omzetting ontbrak.

(function () {
  'use strict';

  var SCHEME = 'jitsi-meet://';
  var BYPASS = 'jitsi-open-in-app:bypass';

  // Paden van precies één segment die tóch geen kamernaam zijn.
  var GEEN_KAMER = [
    'static', 'images', 'libs', 'css', 'fonts', 'sounds', 'lang',
    'v1', 'about', 'privacy', 'terms', 'health', 'health-check'
  ];

  // Eenmalig "toch in de browser": gezet door de knop op de tussenpagina.
  try {
    if (sessionStorage.getItem(BYPASS)) {
      sessionStorage.removeItem(BYPASS);
      return;
    }
  } catch (e) {
    // sessionStorage kan geblokkeerd zijn; dan gewoon doorgaan met omleiden.
  }

  var kamer = kamerNaam(location.pathname);
  if (!kamer) return;

  var doel = SCHEME + location.host + location.pathname + location.search + location.hash;

  // Stoppen vóórdat de SPA start, anders vraagt Firefox óók je camera op en
  // sta je twee keer toestemming te geven voor dezelfde meeting.
  window.stop();

  // Firefox mág een protocol-start zonder gebruikersactie weigeren. Daarom
  // altijd de tussenpagina eronder: die knop is wél een echte klik.
  location.replace(doel);
  toonTussenpagina(kamer, doel);

  // --- hulpfuncties -------------------------------------------------------

  function kamerNaam(pad) {
    // Meerdere segmenten is nooit een kamer. Sluit o.a.
    // /v1/_cdn/auth-static/meet-jit-si/v1/signin.html uit -- daar omleiden
    // breekt de inlogflow van meet.jit.si.
    var m = /^\/([^/]+)\/?$/.exec(pad);
    if (!m) return null;

    var naam = m[1];
    if (GEEN_KAMER.indexOf(naam) !== -1) return null;
    if (naam.indexOf('.') !== -1) return null;  // config.js, favicon.ico, manifest.json
    return naam;
  }

  function toonTussenpagina(kamer, doel) {
    function render() {
      if (!document.documentElement) {
        setTimeout(render, 10);
        return;
      }

      document.documentElement.innerHTML = '<head></head><body></body>';

      var titel = document.createElement('title');
      titel.textContent = kamer + ' — Jitsi';
      document.head.appendChild(titel);

      var body = document.body;
      body.style.cssText = [
        'margin:0', 'min-height:100vh', 'display:flex',
        'align-items:center', 'justify-content:center',
        'font:15px/1.5 system-ui,sans-serif',
        'background:#1a1d21', 'color:#e8e8e8'
      ].join(';');

      var kaart = document.createElement('div');
      kaart.style.cssText = 'text-align:center;max-width:32rem;padding:2rem';

      kaart.appendChild(regel('h1', 'Geopend in de Jitsi-app',
        'margin:0 0 .5rem;font-size:1.35rem;font-weight:600'));
      kaart.appendChild(regel('p', kamer,
        'margin:0 0 1.75rem;color:#9aa0a6;font-family:ui-monospace,monospace;word-break:break-all'));

      var knoppen = document.createElement('div');
      knoppen.style.cssText = 'display:flex;gap:.75rem;justify-content:center;flex-wrap:wrap';

      var opnieuw = knop('Opnieuw openen in de app', true);
      opnieuw.addEventListener('click', function () {
        location.replace(doel);
      });

      var browser = knop('Toch in de browser joinen', false);
      browser.addEventListener('click', function () {
        try {
          sessionStorage.setItem(BYPASS, '1');
        } catch (e) {
          // Zonder sessionStorage zou de reload meteen weer omleiden.
          alert('Kan de browser-modus niet onthouden (sessionStorage geblokkeerd).');
          return;
        }
        location.reload();
      });

      knoppen.appendChild(opnieuw);
      knoppen.appendChild(browser);
      kaart.appendChild(knoppen);

      kaart.appendChild(regel('p', 'Deze tab mag dicht.',
        'margin:1.75rem 0 0;color:#6b7076;font-size:.85rem'));

      body.appendChild(kaart);
    }

    render();
  }

  function regel(tag, tekst, css) {
    var el = document.createElement(tag);
    el.textContent = tekst;
    el.style.cssText = css;
    return el;
  }

  function knop(tekst, primair) {
    var b = document.createElement('button');
    b.textContent = tekst;
    b.style.cssText = [
      'padding:.6rem 1.1rem', 'border-radius:.4rem', 'cursor:pointer',
      'font:inherit', 'border:1px solid ' + (primair ? '#1b6ef3' : '#3c4043'),
      'background:' + (primair ? '#1b6ef3' : 'transparent'),
      'color:' + (primair ? '#fff' : '#e8e8e8')
    ].join(';');
    return b;
  }
})();
