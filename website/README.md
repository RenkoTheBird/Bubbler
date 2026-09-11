# Wubbler website

Public launch site for [wubbler.xyz](https://www.wubbler.xyz): landing page plus hosted legal documents.

## Routes

| Path | Source |
| --- | --- |
| `/` | Landing |
| `/privacy` | `../legaldocs/privacy-policy.md` |
| `/terms` | `../legaldocs/terms-of-service.md` |
| `/community-guidelines` | `../legaldocs/community-guidelines.md` |
| `/contact` | Empty stub |
| `/impressum` | Empty stub |

Stable URLs for mobile clients (signup + Settings):

- `https://www.wubbler.xyz/privacy`
- `https://www.wubbler.xyz/terms`
- `https://www.wubbler.xyz/community-guidelines`

## Develop

```bash
cd website
npm install
npm run dev
```

## Build

```bash
npm run build
npm run preview
```

Deploy the `dist/` output (e.g. Cloudflare Pages / Vercel) with project root `website/`.
