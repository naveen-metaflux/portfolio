# Naveen Gupi — Data Analyst & BI Developer Portfolio

A single-page portfolio site built with plain HTML/CSS/JS (no build step, no dependencies) —
ready to deploy on GitHub Pages.

## What's inside

```
portfolio/
├── index.html                  # the whole site
├── assets/
│   ├── images/                 # dashboard screenshots (Power BI exports)
│   ├── pbix/                   # downloadable .pbix files
│   └── sql/                    # the 3 SQL project files, plain .sql
└── README.md
```

## 1. Add your resume

Export your resume as a PDF and drop it in `assets/` as:

```
assets/Naveen_Gupi_Resume.pdf
```

The "Download Resume" button on the site already points to that path — nothing else to change.

## 2. Fill in real links

Two placeholders need your real URLs — search `index.html` for `github.com/` and `linkedin.com/`
and swap in your actual profile links (there are a few instances: nav, case study links, and the
contact list at the bottom).

## 3. Push to GitHub

```bash
cd portfolio
git init
git add .
git commit -m "Initial portfolio"
git branch -M main
git remote add origin https://github.com/naveen-metaflux/portfolio.git
git push -u origin main
```

## 4. Turn on GitHub Pages

1. On GitHub, open your repo → **Settings** → **Pages**
2. Under "Build and deployment", set **Source** to `Deploy from a branch`
3. Set **Branch** to `main` and folder to `/ (root)` → **Save**
4. Wait ~1 minute, then your site is live at:
   `https://<your-username>.github.io/<your-repo>/`

If you want it at the root of your GitHub Pages domain (`https://<your-username>.github.io/`),
name the repo exactly `<your-username>.github.io`.

## Notes on the Power BI dashboards

GitHub Pages only serves static files, so the `.pbix` files themselves won't render or be
interactive in the browser — they're included as downloadable files so recruiters can open them
in Power BI Desktop. The site shows exported dashboard screenshots instead. If you want a truly
interactive version online, publish the reports to the web from Power BI Service
(**File → Publish to web**) and swap the "View in GitHub repo" links for the published embed
links.

## Editing content

Everything is in `index.html` — sections are clearly commented (`<!-- ================= WORK ... -->`
etc.). No templating engine, so just edit the HTML directly. The SQL blocks are duplicated inline
for the `<pre>` display but also exist as plain files in `assets/sql/` in case you want to link to
raw files instead.
