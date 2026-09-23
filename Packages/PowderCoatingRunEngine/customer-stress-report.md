# Customer stress review — 2026-09-23

Scope: an independent reviewer inspected the candidate Swift source against the WorksBien powder coating workbench brief. No customers were recruited, no device workflow was observed, and the source was not compiled in this workspace. The fixture is synthetic.

## 1,000 customer exercise

`testThousandSyntheticCustomerIntakeAndCorrectionScenarios` defines 1,000 distinct customer job references with varying quantity, substrate, finish, lot and booth, and periodically corrects an intake transcription. Each scenario creates and round trips an archive and checks intake and outstanding counts. The test is **authored, not executed**. It covers intake and corrections; it does not establish customer demand or 1,000 complete live production workflows.

`testTenThousandAcceleratedLifecyclesAcrossThousandYears` defines a reproducible xorshift seed `0x5EED_C0A7`, 10,000 independent run sequences, variable recipe thresholds and durations, an early dwell rejection and a valid dwell. Dates advance 36.525 days per iteration, totaling about 1,000 simulated years. The test is **authored, not executed**. It does not simulate 1,000 years of cumulative ledger growth or media storage.

## Operator review findings

| Finding | Severity | Disposition |
| --- | --- | --- |
| A mistaken below-target correction stranded a valid held run. | High | Added documented `resolveHold` after effective dwell readings qualify; regression authored. |
| Jobs, item intake/finish, lots, booths and batch equipment could not be corrected authoritatively. | High | Added typed corrections, retained audit events, and corrected current-value CSV/PDF output. |
| Unload or handoff timestamps could predate run activity. | High | Added chronological guards and regression scenarios. |
| Defect photos lacked run linkage and PDF omitted useful QC and preparation evidence. | Medium | Added photo purpose/run/operator/time, deletion audit, and expanded factual report fields. On-device visual review remains pending. |
| Truncated JPEG passed a minimal header check. | Medium | Added end marker and ImageIO completeness plus dimensions on Apple platforms. ImageIO behavior needs device validation. |
| Plain CLI harness cannot interactively exercise a full shift or restore. | High | Blocked; XCTest definitions and sample CLI do not replace on-device operator acceptance. |
| Embedded JPEGs force full ledger rewrite per action. | High | Blocked; needs separate bounded media store, realistic storage measurements and failure recovery. |
| A later cure correction on delivered parts reopened the job and implied physical rework of parts the customer holds. | High | Preserve the handoff and delivered quantity, log a post-handoff alert and follow-up, and prevent rework of that delivered run. Regression authored, not executed. |

## Decision

**Provisional only.** Before an operational release: run and fix XCTest on a Mac, complete a three-shop observed workflow with operators, test interrupted-run and low-space recovery, and compare competitor task time and willingness to pay. No claim of real customer validation is made.
