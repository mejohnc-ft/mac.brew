---
name: rewst-site-publish
description: Publishes HTML content to Rewst-hosted site pages via the GraphQL API. Use when the user asks to push, publish, or update content on any *.rew.st site or Rewst app page.
---

# Rewst Site Publish

## Authentication

Rewst uses cookie-based browser auth (Auth0 + httpOnly `appSession` cookie).

**To get the cookie:**

```python
import browser_cookie3
cookies = browser_cookie3.chrome(domain_name="rewst.io")
```

Alternatively:
- Check `REWST_COOKIE` env var
- Check `REWST_COOKIE_FILE` env var
- Manual: DevTools → Application → Cookies → rewst.io domain → copy `appSession`

**Treat `appSession` like a password. Never commit, log, or persist it.**

## API

Endpoint: `https://api.rewst.io/graphql`
Auth: Cookie-based (pass via `requests.cookies`)

### Key GraphQL Operations

**List pages for a site:**
```graphql
query {
  pages(where: {siteId: "SITE_ID"}, order: [["name", "asc"]]) {
    id path name siteId orgId
    nodes { id craftId type props parentId }
  }
}
```

**Get page nodes:**
```graphql
query {
  page(where: {id: "PAGE_ID"}) {
    id path name nodes { id craftId props parentId }
  }
}
```

**Update a page node (push HTML):**
```graphql
mutation updatePageNode($id: ID!, $props: JSON!) {
  updatePageNode(id: $id, props: $props) { id props }
}
```
Variables: `{"id": "NODE_ID", "props": {"html": "<full html content>"}}`

**Update page metadata:**
```graphql
mutation updatePage($page: PageInput!, $nodes: [PageNodeInput!]) {
  updatePage(page: $page, nodes: $nodes) { id }
}
```

## Known Sites

| Site | Org ID | Site ID | URL |
|------|--------|---------|-----|
| John's Playground | `01983d3f-ecb7-7b80-9d05-726dbe1a90d0` | `019d077f-521b-77e9-8d0a-75005d9e3c0f` | `centrexit-johns-playground.rew.st` |

### Known Pages (John's Playground)

| Page | Path | Page ID | HTML Node ID |
|------|------|---------|-------------|
| Design System | `/design-system` | `9247d76d-201b-4dc6-a69f-e9ee79cdd8b6` | `019d0f06-17cc-7c34-9a2d-e7fa97817b35` |
| vITM Toolbox | `/home` | `019d077f-5222-7459-b4bd-e48465e3ec2e` | — |
| Request Toolbox Home | `/request-home` | `4a0fab27-c319-4542-9f79-273e41cf6320` | — |
| Request Automation Hub | `/request-automation-hub` | `08dd0448-08a1-4f96-8671-90ac67630bb4` | — |

## Publish Script Pattern

```python
import browser_cookie3
import requests
import json

def publish_to_rewst(html_content, node_id):
    """Push HTML content to a Rewst page node."""
    cookies = browser_cookie3.chrome(domain_name="rewst.io")
    jar = requests.cookies.RequestsCookieJar()
    for c in cookies:
        jar.set(c.name, c.value, domain=c.domain, path=c.path)

    response = requests.post(
        'https://api.rewst.io/graphql',
        json={
            "query": """mutation updatePageNode($id: ID!, $props: JSON!) {
                updatePageNode(id: $id, props: $props) { id }
            }""",
            "variables": {"id": node_id, "props": {"html": html_content}}
        },
        cookies=jar,
        headers={"Content-Type": "application/json"}
    )

    result = response.json()
    if 'errors' in result:
        raise Exception(f"GraphQL error: {result['errors']}")
    return result

# Usage:
# publish_to_rewst(html_string, "019d0f06-17cc-7c34-9a2d-e7fa97817b35")
```

## Gotchas

1. **Cookie expires** — If `browser_cookie3` fails, the user needs to re-login to Rewst in Chrome
2. **Different Chrome profile** — `browser_cookie3.chrome()` reads the default profile. If Rewst is in a different profile, it won't find the cookie
3. **Node structure** — Rewst pages use Craft.js. HTML pages typically have a ROOT node + one child node with `props.html` containing the full HTML string
4. **No headed browsers needed** — Never launch Playwright/Puppeteer headed instances for this. Use `browser_cookie3` to read existing Chrome cookies headlessly
5. **Large payloads** — The GraphQL endpoint handles 500KB+ HTML payloads fine
