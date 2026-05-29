# Rewst Iframe Bridge Pattern

Use these concrete files as the reference implementation.

## Primary Example: viTM Toolbox

Parent:
- `/Users/jchristensen/Git/viTM-Toolbox/home.page.html`
- Key functions:
  - `postThemeBridge(...)`
  - `sendThemeBridge()`
  - `ensureDeviceInventoryFrame()`
- Important detail:
  - Device Inventory is embedded with `srcdoc`, not a routed iframe.

Child:
- `/Users/jchristensen/Git/viTM-Toolbox/device-inventory.page.html`
- Key pattern:
  - `window.addEventListener("message", ...)`
  - `if (data.type !== "vitm-theme-bridge") return;`
  - apply local `applyThemeState(...)` and `applyButtonStyle(...)`

## Status Implementation

Parent shell generator:
- `/Users/jchristensen/Git/Service-Desk-Toolbox/review/request-toolbox-unified-rewst-ready/build_playground_unified_request_home.py`
- Key areas:
  - `status_main(...)`
  - `build_status_embed_html()`
  - `postStatusThemeBridge()`
  - `ensureStatusFrame()`

Prod publisher:
- `/Users/jchristensen/Git/Service-Desk-Toolbox/review/request-toolbox-unified-rewst-ready/publish_service_desk_home.py`

Child page:
- `/Users/jchristensen/Git/Status/pages/status-dashboard.fragment.html`
- Key areas:
  - early embed detection in the first inline script
  - embedded chrome suppression in `configureThemeControls()`
  - theme bridge listener in `window.addEventListener("message", ...)`

## Known Good Rules

- Parent embed should be `srcdoc` when possible.
- Full-page route should remain available for direct navigation.
- Parent should send a dedicated lightweight theme bridge on:
  - theme init
  - theme change
  - iframe `load`
  - delayed retry timers after load
- Child should treat storage hydration as first-paint fallback, not as the primary live bridge.
