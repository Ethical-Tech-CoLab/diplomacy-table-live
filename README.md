# Diplomacy Table

**[Teaching console](https://ethical-tech-colab.github.io/diplomacy-table-live/)** ·
**[Negotiation app](https://ethical-tech-colab.github.io/diplomacy-table-live/app.html)** ·
An [Ethical Tech CoLab](https://github.com/Ethical-Tech-CoLab) project

Tools for designing and running multi-party AI negotiation simulations. Two pages are published here:

| Page | What it is | Useful without a backend? |
|---|---|---|
| [`index.html`](https://ethical-tech-colab.github.io/diplomacy-table-live/) | **Configuration & Teaching Console.** Documents the knobs that change how an AI-mediated negotiation behaves, the tactics a detector can and cannot see, and the arithmetic behind whether a deal is even possible. | **Yes** — seven of ten tabs are complete offline. |
| [`app.html`](https://ethical-tech-colab.github.io/diplomacy-table-live/app.html) | **Negotiation control surface.** Runs live sessions: rounds, caucuses, coalitions, tactic detection, debrief reports. | **Yes, for recorded runs** — it opens on a gallery of complete recordings that play back with no backend at all. Driving a *new* negotiation needs one. |

**Neither build ships with a backend.** They are published as reference material. Point them at a
running [DTSF](https://github.com/Ethical-Tech-CoLab) instance to enable the live behaviour.

Start with the console. It is the one that teaches; the app is the one that runs.

---

## Recorded negotiations

`app.html` opens on a gallery of complete tick-by-tick recordings of real runs. Pick one and it plays
back in the actual negotiation room — same transcript, same channel tabs, same tactic detections,
same failures — **with no backend, no network and nothing to time out.**

That last part is the point. A live demo in front of a room depends on a server staying up, a model
staying responsive, and a session not expiring while someone asks a question. A recording depends on
nothing. It is also what makes a GitHub Pages deployment more than a screenshot.

| Recording | What it shows |
|---|---|
| **Strait of Hormuz — full 4-round run** | Two AI delegations. Round 1 fails cold: both turns time out and are recorded as placeholders, then rounds 2–4 produce substantive exchanges. The failure replays *as* a failure. |
| **Ceasefire extension — operator view** | Three seats, two AI and one human facilitator. The US and the E3 hold a caucus that Iran is not in, and this log contains it. |
| **Ceasefire extension — as Iran saw it** | The same run, exported to the Iranian delegation's perspective. The caucus is gone. |

### Reading a recording honestly

Every log declares whose eyes it represents, and the app shows that in the replay chip: **red for an
operator view** (unredacted — every channel, including caucus), **purple for a delegation view**.

Two details are deliberate and worth pointing out to a class:

- **The "View As" selector is locked during replay.** Perspective is decided when the log is
  exported, not when it is read. A delegation log simply does not contain what that seat could not
  see, so allowing the picker to move would imply you can reveal more by asking. To see another
  seat, open that seat's recording.
- **Tick numbers are not renumbered when material is withheld.** The gaps in the sequence *are* the
  redaction. You can see that something was said at tick 15 without seeing what — which is a more
  honest artefact than a transcript that quietly closes over its own omissions.

### Adding or refreshing recordings

Recordings are produced from a live DTSF instance and written straight into `runs/`:

```powershell
node scripts/export-diplomacy-run.mjs `
  --session <session-id> --as operator `
  --out C:\path\to\diplomacy-table-live\runs `
  --label "Strait of Hormuz - full 4-round run" --note "One line for the gallery card."
```

`--as` has no default, on purpose: the difference between `operator` and a delegation name is every
caucus in the run. The exporter scans the bytes for secret-shaped strings before writing, and always
rebuilds `runs/index.json` by scanning the directory rather than appending to it — so the manifest
cannot list a run that is not there. `sync-from-dtsf.ps1` re-checks all of it before publish.

---

## What works without a backend

Seven of the console's ten tabs are complete offline:

| Tab | What it gives you |
|---|---|
| **Architecture** | How the pieces fit: table twin, delegation twins, model provider, edge. Hosting options with their trade-offs. |
| **Knobs** | 33 documented parameters — timeouts, temperature, word budgets, procedure style, anti-mirror settings — each with its default, its range, and what actually changes when you move it. |
| **Models** | Which class of model suits which job, and 10 experiments designed to make the differences visible rather than asserted. |
| **Tactics &amp; Goals** | The tactic and lever reference: what each detector rule looks for, and where rule-based detection breaks down. |
| **Scenario** | How to research and structure a negotiation scenario. |
| **ZOPA** | The zone of possible agreement — what it is, and the five inputs required before one can honestly be computed. |
| **Runbook** | A run sheet for convening a live simulation: 14-item preflight, timing, and nine failure modes with their recovery steps. |

The remaining three — **Connect**, **Delegations** and **Bake-off** — need a live instance.

## Connecting to a backend

Both pages resolve their API base the same way, in four steps; the first non-empty value wins.

1. `?api=` on the URL — `…/diplomacy-table-live/app.html?api=https://your-backend`
   Ideal for handing a pre-wired link to a class or a panel.
2. `localStorage['dtsf.apiBase']` — sticky per browser; what the *remember* checkbox writes.
3. `window.DTSF_API_BASE_DEFAULT` — set at publish time (see below).
4. `window.location.origin` — the same-origin case, when DTSF serves the page itself.

Bearer token resolution mirrors it: `?token=` → `localStorage['dtsf.token']` → none.

> **On putting a token in a URL.** It lands in browser history, in any screen-share, and in the
> referrer of any outbound link. Treat a token distributed this way as a short-lived convening
> credential — scoped, rotated after the event — not as a durable secret. The console's Connect tab
> says the same thing at the point of use.

### Publishing a build wired to an instance

Each page carries one line not present in the upstream artefact, immediately after `<title>`:

```html
<script>window.DTSF_API_BASE_DEFAULT = '';</script>
```

Empty string means *"there is deliberately no backend at this origin."* The resolver tests for the
**presence** of the property rather than its truthiness, so `''` is a meaningful value: it holds the
page in reference-only mode instead of falling through to `window.location.origin` — which on GitHub
Pages is `github.io`, and would produce a connection error on every request.

To wire a build to an instance, run the sync script with `-ApiBase` and republish:

```powershell
.\sync-from-dtsf.ps1 -DtsfRoot C:\path\to\dtsf -ApiBase https://dtsf.example.org
```

## Why a separate repository

Both pages are single self-contained HTML files: no build step, no dependencies, no CDN
references. They run identically from GitHub Pages, from a local static server, or by
double-clicking them off disk.

The backend they talk to is a much larger private system. Keeping the two apart means the teaching
material can be public and permanently linkable without widening the backend's exposure, and a
published console cannot drift out of reach of the people who need to read it just because a server
is down.

## Maintenance

The upstream artefacts live in the DTSF monorepo:

| Published | Upstream | Served by the runtime at |
|---|---|---|
| `index.html` | `twins/packs/diplomacy-table/diplomacy-table-config.html` | `GET /diplomacy-table/config` |
| `app.html` | `twins/packs/diplomacy-table/diplomacy-table-app.html` | `GET /_app/diplomacy-table` |
| `runs/*.ndjson` | exported from a live instance via `scripts/export-diplomacy-run.mjs` | `GET /diplomacy-table/sessions/<id>/log?as=<perspective>` |

`sync-from-dtsf.ps1` copies both pages, re-injects the one configuration line, and refuses to publish
a build that fails any of its checks. It does not copy `runs/` — the exporter writes those directly —
but it validates them at the same gate: manifest and directory must agree in both directions, every
run must declare a perspective, and nothing may contain a secret-shaped string.

Keeping each file byte-identical to upstream apart from that single line is deliberate: it means the
console an instructor reads on Pages is provably the same page an operator sees when connected to a
live instance.

One of those checks earns its keep. An end-script tag written literally inside a JavaScript comment
ends the `<script>` element at that point — the HTML tokenizer does not care that it is inside a
comment — silently dropping every line below it. That shipped here once. A string search will not
find it and neither will syntax-checking the extracted block, because the extractor stops at the same
premature tag and hands the checker a truncated fragment that parses cleanly. The script now
splits blocks the way the tokenizer does and parses each one.

## License

MIT — see [LICENSE](LICENSE).
