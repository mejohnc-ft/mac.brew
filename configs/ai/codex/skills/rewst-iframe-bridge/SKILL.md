---
name: rewst-iframe-bridge
description: Embed one Rewst app page inside another with reliable live theme sync, embedded chrome suppression, and parent-to-child command/search handoff. Use when composing HTMLContainer toolbox pages, Rewst site pages, or iframe/srcdoc app surfaces that must behave like one integrated shell instead of separate pages.
---

# Rewst Iframe Bridge

Use this skill when stitching Rewst app pages together inside a parent shell.

## Core Rules

1. Prefer `srcdoc` over a routed iframe when the embedded child page is also controlled in the repo.
2. Keep the standalone child route for direct navigation and link-out, but do not make the parent shell depend on the routed child for the embedded experience unless there is a hard requirement.
3. Use one dedicated live theme bridge for the embed.
4. Send only `mode`, `pack`, `accent`, and `buttonStyle` in the primary live bridge.
5. Let the child recompute its own theme from that payload. Do not make raw CSS variable payloads the primary live-sync mechanism.
6. Test the real failure path: open the iframe view first, then change the parent theme while the child is already visible.

## Parent Pattern

Build the embedded child from checked-in HTML and inject it with `srcdoc`.

Use this sequence:

1. Keep a full-page child route such as `/s/status` for standalone use.
2. Build an embedded child HTML document from the child fragment or page source.
3. Render the iframe without `src` and set `srcdoc` from the generated embedded HTML.
4. Give the iframe a stable `id` and `name`.
5. On parent theme init, theme changes, and iframe `load`, send a dedicated bridge message to the iframe.
6. Re-send on short delayed timers after load or route activation to cover slow child initialization.

Parent bridge shape:

```js
frame.contentWindow.postMessage({
  type: "vitm-theme-bridge",
  mode: currentMode(),
  pack: currentPack(),
  accent: currentAccent(),
  buttonStyle: currentButtonStyle()
}, "*");
```

If the parent has global search or command palette routing, forward it as a separate explicit message. Do not overload the theme bridge with search state.

## Child Pattern

Mark embedded mode before paint, hide child-only chrome, and listen for the dedicated bridge.

Use this sequence:

1. Detect embed mode in the earliest head script.
2. Set an embed marker like `data-status-embedded="1"` before styles paint.
3. Hide local header, utility row, theme picker, and tab chrome in embedded mode.
4. Keep a standalone theme picker for the full-page route.
5. On `vitm-theme-bridge`, call the child’s own theme setters.

Child listener pattern:

```js
window.addEventListener("message", function (event) {
  var data = event.data || {};
  if (data.type !== "vitm-theme-bridge") return;
  if (EMBED_MODE && event.source !== window.parent) return;
  applyButtonStyle(data.buttonStyle || currentButtonStyle(), { persist: false });
  applyThemeState(data.mode || currentMode(), data.pack || currentPack(), { persist: false });
  applyAccent(data.accent || currentAccent());
});
```

Storage hydration and parent-theme requests are acceptable as fallback for first paint, but they are not the primary live-switch path.

## Route Split

Use this split by default:

- Embedded toolbox tab: `srcdoc`
- Standalone page: routed Rewst page such as `/s/status`
- Right-rail or utility link: open the standalone route in a new tab

This keeps:

- the integrated shell fast
- live theme switching reliable
- full-page deep linking available

## What To Avoid

- Do not assume initial-load theme matching proves the bridge works.
- Do not make routed iframes the default when `srcdoc` is viable.
- Do not stack multiple competing live bridge contracts unless there is a compatibility requirement.
- Do not make raw theme-variable payloads the primary bridge.
- Do not debug only from standalone child behavior; embedded behavior is the actual contract.

## Verification

Always test in this order:

1. Load the parent shell.
2. Navigate to the embedded child view.
3. Confirm the child matches the current parent theme on first paint.
4. Change the parent theme while the child remains visible.
5. Confirm the child updates live without reload.
6. Refresh and repeat once more.

If step 4 fails while step 3 passes, the live bridge is broken even if storage hydration is working.

## Debug Checklist

- Verify the parent sends the dedicated bridge on theme changes and iframe `load`.
- Verify the child listener is attached in embedded mode.
- Verify the child applies local theme setters, not just raw attributes.
- Verify embedded-mode detection runs before paint.
- If the embed uses a routed `src` iframe and live switching is flaky, switch the embed to `srcdoc` before adding more bridge complexity.

## References

Read [references/pattern.md](references/pattern.md) for the concrete viTM and Status file paths that implement this pattern.
