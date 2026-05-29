# vITM Theme Apply

Apply the centrexIT-Brand theme system to any vITM Toolbox page. This skill standardizes theming across all surfaces with accent colors, dark mode, theme packs, and the parent shell's theme bridge.

## When to Use
- Creating a new page for the vITM Toolbox
- A page is missing theme support or has inconsistent theming
- User asks to "apply theme", "add dark mode", or "fix theming" on a page

## The Canonical Pattern

Every vITM page needs 4 things:

### 1. HTML Tag Attributes
```html
<html lang="en" data-theme-pack="centrexit" data-theme-accent="green" data-btn-style="gradient">
```

### 2. Theme Init IIFE (first `<script>` in `<head>`, before `<style>`)
This MUST run before CSS to prevent flash of unstyled content (FOUC).

```javascript
<script>
(function () {
  var modeKey = "vitm-theme-mode";
  var packKey = "vitm-theme-pack";
  var accentKey = "vitm-theme-accent";
  var buttonStyleKey = "vitm-btn-style";
  var root = document.documentElement;
  var accentVars = ["--brand", "--brand-deep", "--brand-bright", "--brand-soft", "--brand-wash", "--hero-gradient"];
  var accentDefs = {
    green: {
      light: { brand: "#3dae2b", deep: "#0f6a2b", bright: "#4fc43f", soft: "#d8ead7", wash: "rgba(61, 174, 43, .06)", hero: "linear-gradient(135deg, #0a3d1e 0%, #1e7a3a 45%, #3dae2b 100%)" },
      dark: { brand: "#4fc43f", deep: "#d9f2df", bright: "#4fc43f", soft: "#153525", wash: "rgba(79, 196, 63, .08)", hero: "linear-gradient(155deg, #162e22 0%, #234d36 50%, #3a8a4a 100%)" }
    },
    blue: {
      light: { brand: "#0071ce", deep: "#004a8a", bright: "#3a9eef", soft: "#dbeafe", wash: "rgba(0, 113, 206, .08)", hero: "linear-gradient(135deg, #0a1e3d 0%, #1a4a7a 45%, #0071ce 100%)" },
      dark: { brand: "#3a9eef", deep: "#b8d4f0", bright: "#62b4f6", soft: "#0e1e2e", wash: "rgba(58, 158, 239, .10)", hero: "linear-gradient(155deg, #0e1e2e 0%, #1a3550 50%, #2a5a8a 100%)" }
    },
    orange: {
      light: { brand: "#ff8300", deep: "#b05c00", bright: "#ffaa40", soft: "#fff3e0", wash: "rgba(255, 131, 0, .08)", hero: "linear-gradient(135deg, #3d2a0a 0%, #7a5a1a 45%, #ff8300 100%)" },
      dark: { brand: "#ffaa40", deep: "#ffd9a0", bright: "#ffc36b", soft: "#2e1e0e", wash: "rgba(255, 170, 64, .10)", hero: "linear-gradient(155deg, #2e1e0e 0%, #4d3520 50%, #8a6030 100%)" }
    },
    red: {
      light: { brand: "#e1251b", deep: "#9a1a15", bright: "#f06060", soft: "#fde8e8", wash: "rgba(225, 37, 27, .08)", hero: "linear-gradient(135deg, #3d0a0a 0%, #7a1a1a 45%, #e1251b 100%)" },
      dark: { brand: "#f06060", deep: "#f0b8b8", bright: "#ff8a8a", soft: "#2e0e0e", wash: "rgba(240, 96, 96, .10)", hero: "linear-gradient(155deg, #2e0e0e 0%, #4d2020 50%, #8a3030 100%)" }
    }
  };
  function normalizePack(v) { return v === "centrexit" || v === "solarized" ? v : ""; }
  function normalizeButtonStyle(v) { return v === "simple" ? "simple" : "gradient"; }
  function applyAccent(mode, pack, accent) {
    accentVars.forEach(function (k) { root.style.removeProperty(k); });
    if (pack !== "centrexit") return;
    var p = accentDefs[accent] || accentDefs.green;
    var c = p[mode === "dark" ? "dark" : "light"];
    root.style.setProperty("--brand", c.brand);
    root.style.setProperty("--brand-deep", c.deep);
    root.style.setProperty("--brand-bright", c.bright);
    root.style.setProperty("--brand-soft", c.soft);
    root.style.setProperty("--brand-wash", c.wash);
    root.style.setProperty("--hero-gradient", c.hero);
  }
  try {
    var sm = localStorage.getItem(modeKey);
    var mode = sm === "dark" || sm === "light" ? sm : "light";
    var pack = normalizePack(localStorage.getItem(packKey)) || "centrexit";
    var accent = localStorage.getItem(accentKey);
    if (!accentDefs[accent]) accent = "green";
    var bs = normalizeButtonStyle(localStorage.getItem(buttonStyleKey));
    root.setAttribute("data-theme", mode);
    root.setAttribute("data-theme-pack", pack);
    root.setAttribute("data-theme-accent", accent);
    root.setAttribute("data-btn-style", bs);
    applyAccent(mode, pack, accent);
  } catch (_) {
    root.setAttribute("data-theme", "light");
    root.setAttribute("data-theme-pack", "centrexit");
    root.setAttribute("data-theme-accent", "green");
    root.setAttribute("data-btn-style", "gradient");
    applyAccent("light", "centrexit", "green");
  }
  // REPLACE {pageName} with the page's camelCase name (e.g., __financialsApplyTheme)
  window.__{pageName}ApplyTheme = function (p) {
    var mode = p.mode === "dark" ? "dark" : "light";
    var pack = normalizePack(p.pack) || "";
    var accent = accentDefs[p.accent] ? p.accent : "green";
    var bs = normalizeButtonStyle(p.buttonStyle);
    root.setAttribute("data-theme", mode);
    root.setAttribute("data-theme-pack", pack);
    root.setAttribute("data-theme-accent", accent);
    root.setAttribute("data-btn-style", bs);
    applyAccent(mode, pack, accent);
    try { localStorage.setItem(modeKey, mode); localStorage.setItem(packKey, pack); localStorage.setItem(accentKey, accent); localStorage.setItem(buttonStyleKey, bs); } catch (_) {}
  };
})();
</script>
```

### 3. CSS Variable Blocks
The page needs `:root` (light) and `[data-theme="dark"]` blocks at minimum. For full support, add centrexit and solarized overrides.

**Minimum (identity-style):**
- `:root { ... }` — light mode defaults (centrexit green)
- `[data-theme="dark"] { ... }` — dark mode overrides
- Accent colors applied at runtime by the IIFE

**Full (device-inventory-style, recommended for new pages):**
- `:root { ... }` — monochrome light
- `:root[data-theme="dark"] { ... }` — monochrome dark
- `:root[data-theme-pack="centrexit"]:not([data-theme="dark"]) { ... }` — centrexit light
- `:root[data-theme-pack="centrexit"][data-theme="dark"] { ... }` — centrexit dark
- `:root[data-theme-pack="solarized"]:not([data-theme="dark"]) { ... }` — solarized light
- `:root[data-theme-pack="solarized"][data-theme="dark"] { ... }` — solarized dark

Reference: `docs/standards/DESIGN-SYSTEM.md` has the complete token matrix.

Key tokens that MUST be present: `--bg`, `--panel`, `--ink`, `--muted`, `--line`, `--brand`, `--brand-deep`, `--brand-bright`, `--brand-soft`, `--brand-wash`, `--hero-gradient`, `--good`, `--warn`, `--bad`, `--info`, `--shadow`, `--shadow-soft`

### 4. Theme Bridge PostMessage Handler (bottom of main `<script>`)
```javascript
window.addEventListener("message", function (event) {
  var data = event.data || {};
  if (data.type !== "vitm-theme-bridge") return;
  // No origin check needed — message type is sufficient. Origin checks block
  // the bridge in Rewst iframe contexts where parent/child origins may not match.
  // REPLACE {pageName} to match the IIFE
  window.__{pageName}ApplyTheme({
    mode: data.mode,
    pack: data.pack,
    accent: data.accent,
    buttonStyle: data.buttonStyle
  });
});
```

## Live-Switch Requirements

The theme must update in real time when the parent shell toggles mode/accent/pack. This requires:

1. **The page's postMessage handler** must call `__applyTheme` which sets data attributes AND inline accent styles
2. **The home shell** re-queries `.workspace-iframe` each time `sendThemeBridge` fires (catches dynamically loaded workspace frames)
3. **The home shell** sends a delayed re-bridge (`setTimeout(sendThemeBridge, 150)`) after theme changes
4. **If the page has its own theme UI** (like device inventory's appearance picker), its `applyThemeState` function must also call the accent logic

If adding a new page to the toolbox home nav:
- If it's a direct iframe: add `postThemeBridge(newFrame)` to the `sendThemeBridge()` function in home.page.html
- If it's in a workspace tab: give the iframe `class="workspace-iframe"` — it's auto-discovered by `sendThemeBridge`

## Checklist for Applying to a Page
1. Add `data-theme-pack="centrexit" data-theme-accent="green" data-btn-style="gradient"` to `<html>` tag
2. Insert IIFE `<script>` in `<head>` before `<style>` — replace `{pageName}` with page name
3. Verify CSS has `:root` and `[data-theme="dark"]` blocks with all required tokens
4. Add `--brand-wash` to CSS blocks if missing
5. Add or verify theme bridge postMessage handler at bottom of main script
6. If the page is a new nav item: register the iframe in home.page.html's `sendThemeBridge` or use `class="workspace-iframe"`
7. Test: toggle dark mode from the home shell — page must update instantly without reload

## Reference Files
- Canonical IIFE example: `apps/identity/identity.page.html` (lines 7-92)
- Full CSS token matrix: `apps/device-inventory/device-inventory.page.html` (lines 76-308)
- Design system spec: `docs/standards/DESIGN-SYSTEM.md`
- Theme bridge sender: `apps/home/home.page.html` (search for `sendThemeBridge`)
- Live-switch pattern: `apps/home/home.page.html` (search for `postThemeBridge`)
