# Halo — Piano di lancio Bocconi (unificato)

Checklist unica orientata a **un obiettivo solo: distribuire Halo a Bocconi con
successo**. Unisce la roadmap di `TODO.md` con l'audit di codice, UX e funnel
della sessione del 2026-07-10. Gli item sono sequenziati e marcati per
criticità di lancio, non per fase tecnica. Per lo storico completo vedi
`PLAN.md`; per i passi operativi di distribuzione vedi `docs/launch/RUNBOOK.md`.

**Stato**: `[ ]` da fare · `[x]` fatto · `[~]` in corso · `[!]` bloccato
**Priorità**: 🚀 blocker di lancio · ⭐ alto impatto sul successo · 🔧 dopo il lancio

**Definition of done**: una matricola Bocconi scarica l'app, verifica
`@studbocconi.it`, entra in un Founder/Event Ring durante l'orientation week,
manda la prima vibe — e noi lo vediamo nel funnel.

---

## 0. Distribuzione — senza questo non si lancia 🚀
*(runbook eseguibile: `docs/launch/RUNBOOK.md`. Gli item con account
Apple/device sono manuali per natura: il repo prepara tutto lo scaffolding.)*

- [ ] Apple Developer account + App ID, capabilities (Sign in with Apple,
      App Groups, Push), provisioning — **manuale**, passi in `RUNBOOK.md §2`
- [x] Build config di produzione centralizzata in `Config/*.xcconfig`
      (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_GROUP_ID`, `HALO_URL_SCHEME`)
- [ ] Prodotto StoreKit `app.halo.plus.monthly` in App Store Connect
      — **manuale**, campi esatti in `RUNBOOK.md §3`
- [~] Supabase **prod** deployato (migrations + edge functions + secrets)
      — **scriptato**: `scripts/deploy-supabase-prod.sh`; resta da eseguire
      con le credenziali prod
- [ ] Build su **TestFlight** + privacy nutrition labels / review prep
      — **manuale**, checklist in `RUNBOOK.md §5`
- [ ] Smoke test end-to-end su device reale (auth → verify → ring → vibe)
      — **manuale**, checklist in `RUNBOOK.md §6`

## 1. Fix prodotto pre-lancio (audit sessione) 🚀
*(bug e buchi di funnel trovati nell'audit: piccoli in rapporto all'impatto,
tutti nel percorso critico dell'orientation week)*

- [x] **QR su universal link https, non `halo://`** — oggi il QR
      dell'orientation week codifica `halo://ring/join/bocconi-orientation-week`:
      chi non ha l'app installata scansiona e non succede nulla. Serve una
      pagina join sulla landing (link https + Associated Domains) che apre
      l'app se presente e altrimenti porta a TestFlight, conservando il token
      del ring. (`web/landing/`, `docs/growth/orientation-week-qr.md`,
      entitlements app)
  - [ ] **Setup reale del QR (manuale, ancora da finire)** — il codice è
        pronto ma il link non è ancora attivo: serve il dominio reale in
        `applinks:` + AASA servito da quel dominio, Team ID/bundle ID reali
        nell'AASA, `TESTFLIGHT_URL` pubblico, e rigenerare il PNG del QR verso
        il link https. Passi in `docs/growth/orientation-week-qr.md`.
- [x] **Token ring/invite sopravvive al signup** — chi arriva dal QR da non
      registrato deve atterrare nel ring dopo auth/verify, non su un'orbita
      vuota. Verificare il percorso `AppState.handle(link:)` → auth →
      `HomeView.syncRoutePresentation`.
- [x] **Quick-drop "scatto"/"audio" nel Pulse pubblicano post vuoti** —
      chiamano `publishQuickDrop(.photo/.audio)` con `mediaPath: nil`, senza
      picker né recorder (`PulseFeedView.swift:270`,
      `FeedViewModel.publishQuickDrop`). Collegare PhotosPicker /
      `AudioRecorderView` (già esistenti nel compose completo) oppure
      rimuovere i due bottoni dal dock per il lancio.

## 2. Cold-start Bocconi — il successo si gioca qui ⭐
*(la strumentazione c'è, manca l'esecuzione; più i fix di comprensione
dall'audit: il first-run deve spiegarsi da solo)*

- [ ] Reclutare i **20 Founder Circle** — `docs/growth/founder-circles-tracker.csv`
      è un template vuoto (tutti gli slot `status=target`, lead vuoti)
- [ ] QR Event Ring stampati/posizionati per l'**orientation week**
      (seed `bocconi-orientation-week` già pronto; dipende dal fix
      universal link in §1)
- [ ] Verificare end-to-end il path **`@studbocconi.it`** su prod
- [ ] Conversione **waitlist → invito** attiva e testata
- [ ] **Vocabolario first-run ridotto a max 3 termini** (Inner, Vibe, Moment)
      — oggi un utente nuovo incontra ~10 nomi propri nei primi minuti
      (Nebula, asteroidi, Pulse, Event Ring, HaloSpace, Memory…): il resto
      va scoperto dopo, in contesto (progressive disclosure)
- [x] **"Invita con link" nello step Initial Inner Circle** accanto alla
      ricerca per handle — per i primi utenti la ricerca è vuota;
      `InvitesService` esteso con invite aperti (invitee al claim,
      migration `20260712100000_open_invite_links.sql`) e riga
      "invita con link" in `InitialInnerCircleView.swift`
- [ ] **Test di comprensione con ~10 studenti** prima del lancio: schermata
      Orbit per 10 secondi (screenshot via `./scripts/demo-screens.sh`),
      domande "cosa fa l'app? cosa toccheresti ora?" — gate: 7/10 rispondono
      sensatamente, altrimenti si aggiusta la schermata che non parla
- [ ] **Landing web allineata al brand dell'app** — oggi usa lime/magenta/blu
      (`web/landing/styles.css`) mentre l'app è cream/bronze su nero: chi
      passa da QR → landing → app deve vedere una storia sola

## 3. Misurazione del lancio (Fase E) ⭐
- [x] Migration tabella eventi (`analytics_events` + RLS)
- [x] `AnalyticsService.track(_:)`
- [x] Strumentare: `signup`, `invite_sent`, `invite_accepted`, `vibe_set`,
      `moment_created`, `ring_joined`, `move_closer`
- [x] Funnel attivazione → target **50% verified → activated**
- [ ] Misurare anche la **comprensione**, non solo l'attivazione:
      time-to-first-vibe e drop-off per step di onboarding

## 4. Performance & coerenza visiva per l'orientation week ⭐
*(dall'audit: reggere il picco di utenti e presentare un brand solo)*

- [ ] **Batch delle chiamate profili** — aggiungere `profiles(ids:)` con
      `.in("id", values:)` a `ProfilesService` e usarlo in
      `HomeViewModel.fetchProfiles` (oggi N richieste parallele, una per
      utente); ridurre i 4-5 round-trip di `FeedViewModel.hydratePersonNode`
      per ogni evento realtime di autori non in cache
- [ ] **`feedPosts()` con `.limit()` e ordinamento server-side** — oggi
      scarica tutti i post vivi e ordina client-side
      (`PostsService.swift:100`); con l'orientation week piena non regge
- [ ] **Widget allineato a cream/bronze** — `WidgetEntryView.swift:5-15` usa
      ancora la palette SWARM operator (lime/viola/magenta su platinum);
      lockscreen/StandBy è la superficie più pubblica del brand

## 5. Monetizzazione — può seguire il lancio 🔧
*(StoreKit Halo+ è già implementato; Events/Clubs usano Stripe via Edge Functions)*

- [x] UI checkout **Halo Events** (4.99 / 29 / 79-99) →
      `stripe-create-checkout-session`
- [x] **Halo Clubs** dashboard/billing (49-149/m)
- [x] Accesso a `stripe-customer-portal` dal profilo

## 6. Qualità & polish 🔧
- [ ] Test sui service principali (Posts, Follows, Vibes, Invites)
      — oggi solo `FriendshipTierTests` e `PostLifespanTests`
- [ ] Test sul **realtime patching di `FeedViewModel`** (dedup reazioni,
      ordering, rollback ottimistico) + logging nei `catch` che oggi
      inghiottono gli errori (`hydratePersonNode`, `reactionTallies`)
- [ ] **Pulse mostra solo l'ultimo post per persona** — `liveEvents` deriva
      da `person.lastPost*`: tre Moment in un'ora → se ne vede uno. Idratare
      gli eventi dai post reali (già in `HomeViewModel.posts`) oppure
      documentare la scelta presence-first
- [ ] **Flag `onboarded` esplicito sul profilo** — l'euristica
      `handle.hasPrefix("halo_") || displayName == "Halo"`
      (`AppState.profileNeedsOnboarding`) intrappola chi si chiama davvero Halo
- [ ] **Reduce Motion / Reduce Transparency** — pausa dei `TimelineView` a
      18-24fps e dei glow permanenti con
      `@Environment(\.accessibilityReduceMotion)` (aiuta anche la batteria)
- [ ] **Micro-tipografia e Dynamic Type** — font a 6.8-8.5pt sotto la soglia
      del brief (min ~9.5); frame fissi (tile 104-118pt) da verificare con
      testo accessibile
- [ ] **Debito di migrazione naming** — rimuovere gli alias legacy
      (`orbitalBlue`, `signalGreen`, `launchAmber`, ridefinizioni
      `orbitStories*` in `HomeView`), spezzare `HomeView.swift` (1649 righe,
      campo orbitale estraibile), allineare il brief dove dichiara
      `warm-black #0F0E10` mentre il codice è su `#000000`
- [ ] Riallineare `PLAN.md` alle checkbox reali (es. StoreKit Halo+ è fatto
      ma segnato `[ ]` in Fase D)

## 7. Bloccato da asset/licenze esterni 🔧
- [!] Font **Satoshi** ufficiale — mapping già nei token, serve il bundle
      `.otf` licenziato (oggi fallback **Inter**, accettabile per il lancio)
- [!] **12 step intermedi** della mono ramp SWARM ufficiali
