# BYOND change review

Use the existing `dm-mcp` server's `dm_review_code` tool after editing DM code.
It performs a fresh, full-project parse and reports findings for the selected files.
The server is local and requires no paid API or new service.

```json
{
  "dme_path": "J:/daedalusmojave/daedalusdock-master/daedalus.dme",
  "files": ["mojave/structures/doors.dm"],
  "limit": 60
}
```

Omit `files` to use staged, unstaged and untracked DM files. Supply exact paths
for a committed change or another build configuration. Files absent from the
active DME are reported separately; test-only code must also be reviewed using
its test DME. Read `coverage` and `truncated`, not just the findings array.

## Before adding code

1. Trace the actual spawned type, proc overrides, callers and lifecycle. Use
   `dm_search_symbols`, `dm_find_callers`, `dm_get_callees` and `dm_get_proc`.
2. Search for an existing helper or pattern that already solves the problem.
   Prefer fixing the shared implementation over copying guards into its callers.
3. Add the fewest concepts and lines that preserve the required behaviour.
   Avoid forwarding wrappers, redundant state, duplicated algorithms and new
   configuration unless they serve a concrete need. Concise means fewer moving
   parts, not compressed formatting or fewer tests for important behaviour.

## Before finishing

1. Run `dm_review_code` for the files changed by the task and inspect coverage.
   Resolve confirmed new defects; do not churn unrelated historical warnings.
2. For an unused-proc candidate, check callbacks, signals, proc paths, verbs,
   override families, alternate builds and external callers before deleting it.
   The tool never deletes code or labels an entire type or mapper variable dead.
3. For a forwarding wrapper, establish whether it supplies an intentional API,
   callback signature or override before removing it. Preserve evaluation order,
   return values, parent chaining and dispatch.
4. For expensive-loop advisories, inspect collection sizes and invocation rate.
   Prefer existing spatial queries, subsystem queues or registries. Measure when
   claiming a performance improvement; nested loops are not automatically bugs.
5. Compile with BYOND and run the smallest meaningful behavioural check. For
   gameplay changes, boot and inspect fresh runtime logs. A stuck-job guard must
   release claims/resources and resume or choose useful work; returning early
   without progress is not a successful recovery test.
6. Report what was verified, accepted advisories and material coverage gaps.
   If the MCP is unavailable, use source inspection and existing compiler/tests;
   say the automated review did not run, rather than claiming a clean result.

## What the tool can and cannot establish

The checks cover missing active-build inclusion, dreamchecker diagnostics,
unreferenced-proc candidates, thin call-forwarding wrappers, nested iteration
and whole-world iteration in common hot procs or inside another loop. Reference
discovery uses parsed DM, including literal callback names, proc paths, variable
initializers and parameter defaults. Comments are not call sites.

Name matching deliberately retains ambiguous code. It is not a complete reachability
analysis: computed names, reflection, externally called procs, recursion and unused
cycles can escape it. Map placement, configuration and other preprocessor modes
remain part of the manual review. Existing diagnostics and parse failures are
reported; an empty report never proves correctness or completeness.

MCP supplies evidence and workflow instructions. Repository instructions encourage
agents to use it; they are not an unbypassable compiler or CI enforcement mechanism.

## Local maintenance

Source: `C:/Users/Tiger/tools/dm-mcp`.
Build: `cargo build --release --locked --offline --bin dm-mcp-quality` in that checkout.
Protocol regression check:
`python test_quality.py target/release/dm-mcp-quality.exe`.

The separate `dm-mcp-quality.exe` output permits upgrades without replacing the
older running executable. The project MCP configurations select the new binary.
An already-connected client must reconnect/restart its MCP connection to refresh
the tool list. Keep the original executable for rollback.

Verified 29 September 2026: release build succeeded with no errors (six existing
Rust dead-code warnings). `test_quality.py` passed its JSON-RPC and analysis
regressions, including BYOND `TYPE_PROC_REF`, generated globals, input validation
and analysis after editing source on the same connection. The real-project review
parsed 45,453 proc bodies with zero parse errors and inspected 31 selected bodies;
its two remaining findings were existing override hints. The complete project had
780 checker diagnostics, so this is not a claim that the entire game is lint-clean.
Evidence: `data/dm-quality-protocol-final-test.log`,
`data/dm-quality-final-game-review.json`, and `data/dm-quality-callback-build.log`.
