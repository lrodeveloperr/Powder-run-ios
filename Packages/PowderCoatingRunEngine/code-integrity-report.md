# Code integrity review — 2026-09-23

An independent code breaker inspected the source and supplied adversarial cases. This is a source-level review, not a successful compilation, fuzz run, mutation score, or penetration test.

| Finding | Severity | Response / remaining limit |
| --- | --- | --- |
| Forged accepted archive with no measurements, inspection or batch could restore. | Critical | Strengthened run event/readings/dwell/inspection validation and ledger batch links; a forged missing-measurements regression is authored. JSON is not cryptographically authenticated. |
| Two repository actors sharing a URL lost one actor's updates. | High | Added advisory per-file lock and disk reload inside every transaction, backup and snapshot. Two-instance regression authored, not run. |
| File protection error after disk replacement left memory behind. | High | Apply protection on temporary file before POSIX atomic rename; no throwing operation after rename. Crash durability under power loss still needs on-device measurement. |
| Preparation checkpoint could occur after application while still satisfying a configured requirement. | High | Require checkpoint time no later than `markApplied`; regression authored. |
| Generic correction used event UUID as subject and vanished from job PDF. | Medium | Preserve corrected event's subject and include audit rows in PDF. Generic correction remains an addendum. |
| Correction could predate handoff and reopen a completed job. | Medium | Enforce creation/handoff chronology for typed and generic corrections and actions. |
| Truncated or very large-pixel JPEG could reach PDF decode. | Medium | End marker and ImageIO completeness; cap each dimension at 12,000 and pixels at 40 million on Apple platforms. Verify ImageIO acceptance and memory on iPhone. |
| Run revision `Int.max` could overflow. | Medium | Reject exhausted revision in validation and before applying an action. |
| 10,000 isolated runs do not establish cumulative archive performance. | High | Open release gate; JSON and media storage architecture need measured redesign. |
| A post-delivery correction could clear `closedAt`, erase released counts and leave physically delivered parts in a fictional rework path. | High | Keep the historical handoff and delivered count, flag a post-handoff quality alert in CSV/PDF, allow documented follow-up and review, and block post-handoff rework or intake quantity edits. Regression authored, not run. |
| A 40 °C thermal cure target could pass recipe validation. | High | Thermal workflow now requires 120–300 °C and validates mutated recipe values when starting a run. Some lower-temperature/UV systems require a different model; lower-target old archives now fail validation. Regression authored, not run. |

## Check status

| Check | Result |
| --- | --- |
| Independent customer/code source review | Completed; findings above |
| Swift package build / XCTest / iOS PDF rendering | Not run: no Swift or Xcode installed here |
| 1,000 synthetic customer and 10,000 run tests | Defined but not executed |
| Device interruption, file protection, lock, image and low-storage behavior | Not run |
| Fuzz, mutation score, warning-free build | Not run |

Do not mark the engine locked on the basis of source inspection. The suite and source need a Mac compile/test pass and iPhone validation; media scaling remains a known blocker.
