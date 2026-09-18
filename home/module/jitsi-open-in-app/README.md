# Jitsi: links openen in de desktop-app

Zet `https://meet.jit.si/<kamer>` om naar `jitsi-meet://meet.jit.si/<kamer>`, zodat een
meeting-link uit Outlook Web of Slack in `jitsi-meet-electron` opent in plaats van in
een Firefox-tab.

## Waarom een userscript en niet iets declaratiefs

Firefox handelt `https` altijd zelf af en kent geen per-domein externe handler. Er is
dus geen pref, policy of `handlers.json`-truc die dit kan; de omzetting moet ín de
pagina gebeuren. De rest van de keten was al compleet:

```
Outlook Web (tab)  ─┐
Slack (xdg-open) ──┴─► Firefox-tab: https://meet.jit.si/<kamer>
                              │  dit userscript, @run-at document-start
                              ▼
                       jitsi-meet://meet.jit.si/<kamer>
                              │  policies.Handlers: useSystemDefault, ask=false
                              ▼
                       jitsi-meet-electron.desktop
                              │  MimeType=x-scheme-handler/jitsi-meet
                              ▼  singleInstanceLock -> 'second-instance'
                       draaiende app springt in de kamer
```

## Eenmalig installeren

Userscripts leven in de extensie-opslag van de browser; nix kan ze niet plaatsen.
Na `home-manager switch` staat het bestand klaar op
`~/.local/share/userscripts/jitsi-open-in-app.user.js`.

1. Firefox → `about:addons` → Tampermonkey → tabblad **Permissions and data**
   → onder *Optional* de schakelaar **Access local files on your computer**
   aanzetten. (Heette vroeger *Allow access to file URLs*.) Zonder dit kan
   Tampermonkey niet uit `file://` lezen.
2. Open `file:///home/wtoorren/.local/share/userscripts/jitsi-open-in-app.user.js`.
   Tampermonkey biedt het script ter installatie aan.
3. Installeren. Door de `@updateURL`-header pakt Tampermonkey latere wijzigingen
   uit de repo op na een rebuild (of via *Check for userscript updates*).

Zonder die bestandsrechten kan het ook handmatig: Tampermonkey-dashboard → `+`
→ de inhoud van het `.user.js`-bestand erin plakken → opslaan. Dan vervalt wel
het automatisch bijwerken na een rebuild.

Testen: open `https://meet.jit.si/TestKamerWouter` in Firefox. Je hoort de tab te
zien omslaan naar de tussenpagina terwijl de app de kamer opent.

## Gedrag en randgevallen

- **Alleen paden van één segment** gelden als kamernaam. Dat sluit
  `/v1/_cdn/auth-static/meet-jit-si/v1/signin.html` uit — daar omleiden breekt de
  inlogflow van meet.jit.si.
- **`window.stop()` vóór de SPA laadt**, zodat Firefox niet óók je camera opvraagt.
  Zonder dat geef je twee keer toestemming voor dezelfde meeting.
- **Tussenpagina met twee knoppen.** Firefox mág een protocol-start zonder
  gebruikersactie weigeren; een echte klik werkt altijd. De tweede knop
  (*Toch in de browser joinen*) zet een `sessionStorage`-vlag en herlaadt — nodig
  als je de agenda-tab van meet.jit.si wilt, want die zet de Electron-app
  hardcoded uit (`enableCalendarIntegration: false`).
- **De app opent twee vensters** (hoofdvenster + meeting-venster). Dat is de
  architectuur van jitsi-meet-electron: het hoofdvenster ontvangt het
  protocol-bericht en vraagt pas dán het meeting-venster aan. Niet in te stellen.
  Het aantal groeit niet: een tweede link hergebruikt het bestaande meeting-venster.
