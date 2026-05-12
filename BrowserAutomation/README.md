# BrowserAutomation (develop branch)

**Status:** parked for evaluation. Not shipped in mainline.

This branch holds the speculative alternative path for **option 2** from the original design fork: actually driving forms inside claude.ai (toggling spend limit, auto-reload, plan changes) rather than just deep-linking to the settings pages.

## Why this is parked

- **Fragility:** claude.ai is a React SPA. Any DOM change breaks selectors. Maintenance is per-month at best.
- **ToS exposure:** automating UI on claude.ai may violate the acceptable use policy. Needs legal review before shipping.
- **Session security:** holding refresh tokens in WKWebView storage indefinitely is a different threat model than session-only cookies.
- **Failure modes:** silent failures (form changed but the click missed) are very hard to detect without a deep end-to-end verification harness.

## What lives here

```
BrowserAutomation/
├── README.md              # this file
├── ScriptedFlows/
│   ├── ToggleAutoReload.swift   # TODO: WKWebView-driven JS injection
│   ├── SetSpendLimit.swift      # TODO
│   ├── SwitchPlan.swift         # TODO
│   └── VerifyFlow.swift         # TODO: post-action verification probe
├── SelectorRegistry.swift       # TODO: versioned CSS selectors, fallback chain
└── ChangeDetector.swift         # TODO: scheduled probe to detect UI changes
```

## When to revisit

- After Anthropic publishes a stable account-management REST API (would obsolete this approach)
- If user research shows that opening a browser tab is a hard friction point
- If a controlled-environment customer (e.g. fleet of MacBooks at one org) needs zero-click profile actions

## How to merge if revived

1. Rebase onto main
2. Cherry-pick selector changes from `SelectorRegistry`
3. Wire UI in `LimitsTab` to optionally call BrowserAutomation methods behind an opt-in toggle
4. Add `BrowserAutomationEnabled` flag default-off

For now: do nothing. This branch is a placeholder so the design history is durable.
