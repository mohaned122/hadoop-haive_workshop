# Hadoop/Hive Quiz — Static Web Version

The easiest way to run this quiz online with minimal internet resource use is a single-file static HTML app.

## Files
- `index.html` — complete, self-contained quiz app. Embeds all 31 questions and full scoring logic (timer, speed bonus, rating, recap). ~22 KB.

## How to use locally
Just open `index.html` in any modern browser. No server, no build step.

## How to publish online (least bandwidth)
Deploy `index.html` to any static host. Top picks for minimal overhead:

| Host | Free | CDN | Notes |
|---|---|---|---|
| [Cloudflare Pages](https://pages.cloudflare.com/) | Yes | Yes | Drag & drop, auto-gzip/brotli, very fast. |
| [GitHub Pages](https://pages.github.com/) | Yes | Yes | Push to a repo, then enable Pages from `main`/`docs`. |
| [Netlify Drop](https://app.netlify.com/drop) | Yes | Yes | Zero-config drag & drop. |

### Quick deploy (Cloudflare Pages)
1. Go to https://pages.cloudflare.com/
2. "Create a project" → "Upload assets"
3. Drag `index.html` into the uploader
4. Publish. You get a shareable URL.

### Quick deploy (GitHub Pages)
1. Create a new repo and upload `index.html` as `index.html` in the root.
2. Settings → Pages → Deploy from branch → `main` and `/ (root)`.
3. Access via `https://yourusername.github.io/repo-name/`.

## Features
- Shuffles questions (or use a fixed seed)
- Per-question timer with configurable limit; timeout counts as 0
- Correct answer gives `base + speed_bonus*(1 - seconds/limit)` (clamped)
- Final results: score/max, correct/wrong/timeouts, accuracy %, total/avg time, rating, per-question recap
- Fully client-side: works offline after first load. No fonts, no external JS/CSS. One HTTP request if served as-is.
- Still matches the Python version's logic and question set (Hadoop + Hive, 31 questions).
