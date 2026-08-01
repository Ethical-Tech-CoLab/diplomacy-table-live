# Diplomacy Table — Configuration &amp; Teaching Console

**[Open the console](https://ethical-tech-colab.github.io/diplomacy-table-live/)** · An [Ethical Tech CoLab](https://github.com/Ethical-Tech-CoLab) project

A teaching console for designing and running multi-party AI negotiation simulations. It documents
the knobs that change how an AI-mediated negotiation behaves, the tactics a detector can and cannot
see, and the arithmetic behind whether a deal is even possible.

**This build has no backend.** It is published as reference material and is fully usable that way —
most of what it teaches is explanation, not live data. Point it at a running
[DTSF](https://github.com/Ethical-Tech-CoLab) instance to enable the live panels.

---

## What works without a backend

Seven of the ten tabs are complete offline:

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

The console resolves its API base in four steps; the first non-empty value wins.

1. `?api=` on the URL — `…/diplomacy-table-live/?api=https://your-backend`
   Ideal for handing a pre-wired link to a class or a panel.
2. `localStorage['dtsf.apiBase']` — sticky per browser; what the *remember* checkbox writes.
3. `window.DTSF_API_BASE_DEFAULT` — set in `index.html` at publish time (see below).
4. `window.location.origin` — the same-origin case, when DTSF serves the page itself.

Bearer token resolution mirrors it: `?token=` → `localStorage['dtsf.token']` → none.

> **On putting a token in a URL.** It lands in browser history, in any screen-share, and in the
> referrer of any outbound link. Treat a token distributed this way as a short-lived convening
> credential — scoped, rotated after the event — not as a durable secret. The console's Connect tab
> says the same thing at the point of use.

### Publishing a build wired to an instance

`index.html` carries one line not present in the upstream artefact, immediately after `<title>`:

```html
<script>window.DTSF_API_BASE_DEFAULT = '';</script>
```

Empty string means *"there is deliberately no backend at this origin."* The resolver tests for the
**presence** of the property rather than its truthiness, so `''` is a meaningful value: it holds the
page in reference-only mode instead of falling through to `window.location.origin` — which on GitHub
Pages is `github.io`, and would produce a connection error on every live panel.

To wire a build to an instance, set the URL there and republish.

## Why a separate repository

The console is a single self-contained HTML file: no build step, no dependencies, no CDN
references. It runs identically from GitHub Pages, from a local static server, or by double-clicking
it off disk.

The backend it talks to is a much larger private system. Keeping the two apart means the teaching
material can be public and permanently linkable without widening the backend's exposure, and a
published console cannot drift out of reach of the people who need to read it just because a server
is down.

## Maintenance

The upstream artefact lives in the DTSF monorepo at
`twins/packs/diplomacy-table/diplomacy-table-config.html` and is served by the runtime at
`GET /diplomacy-table/config`. To refresh this repo, copy that file over `index.html` and re-add the
one configuration line described above. `sync-from-dtsf.ps1` does exactly that and verifies the
result.

Keeping the two byte-identical apart from that single line is deliberate: it means the console an
instructor reads on Pages is provably the same page an operator sees when connected to a live
instance.

## License

MIT — see [LICENSE](LICENSE).
