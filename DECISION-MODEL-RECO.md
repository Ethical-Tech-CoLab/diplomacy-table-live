# Decision-model recommendation: perspective-safe replay annotation

Date: 2026-10-11. Public-source proposal; no runtime change.
Reviewed [README](https://github.com/Ethical-Tech-CoLab/diplomacy-table-live/blob/fd0e708e45f11b9bb97c865804d91b559911a8c7/README.md).
This is a documentation-level assessment of the teaching console and recordings.

## Recommendation

Keep recorded replay fully offline. An optional post-export annotation tool
could assess whether an utterance matches a defined teaching rubric or whether
an analysis claim is supported by visible transcript evidence.

Use present / absent / ambiguous and source tick IDs. Export authorization
must precede the model: a delegation view cannot receive caucus text withheld
from that delegation. A model must not reconstruct withheld turns or fill in
timeout placeholders. Preserve tick gaps and original failure records.

## Trial design

Compare human/rule annotations with a local classifier, Jev,
Microsoft-Decision-1 and Sage on public recordings. The
[bounded-decision guide](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md)
does not supply a backend or authorize processing private transcripts.

Split by negotiation run and perspective. Measure unsupported analysis claims,
tactic-label agreement, unknown handling, calibration, reviewer time and total
cost. Assert that no restricted transcript enters the model context or output;
that is a hard authorization invariant, not an average accuracy metric.

## Go/no-go

No change to recording bytes, perspective lock, replay, feasibility arithmetic
or negotiation control. An API outage must never prevent replay. Start offline
with derived optional annotations; require instructor review before publication.
Exact hosted model checkpoints are not locally available. No savings measured.
