# PDF Tool Installation — Container Environment

Instructions for installing markdown→PDF tooling in this container (Debian 12 / Bookworm, user `developer` with passwordless sudo, `uv` already installed at `~/.local/bin/uv`).

## Preferred Stack

- **`pandoc`** (apt) — markdown parser & document converter
- **`weasyprint`** (via `uv tool install`) — PDF rendering engine (HTML/CSS based, no LaTeX or headless browser required)

Pandoc invokes WeasyPrint directly via `--pdf-engine=weasyprint`. This stack produces good-fidelity PDFs from markdown with minimal install footprint and no Java, Chromium, or TeX Live required.

## Python Tooling Convention

For all Python tools in this environment, **use `uv`** — never `pip install` directly into the system Python.

- Install Python CLIs as isolated tools: `uv tool install <pkg>`
- For project-scoped Python deps: `uv venv` + `uv pip install -r requirements.txt`
- Upgrade a tool: `uv tool upgrade <pkg>`
- List installed tools: `uv tool list`

`uv tool install` puts shims in `~/.local/bin`, which is already on `$PATH`.

## Installation Steps

### 1. System packages (pandoc + WeasyPrint runtime libs)

WeasyPrint links against Pango, Cairo, GDK-Pixbuf, and libffi at runtime. Install them along with pandoc:

```bash
sudo apt-get update
sudo apt-get install -y \
  pandoc \
  libpango-1.0-0 \
  libpangoft2-1.0-0 \
  libharfbuzz0b \
  libcairo2 \
  libgdk-pixbuf-2.0-0 \
  libffi8 \
  shared-mime-info \
  fonts-dejavu \
  fonts-liberation
```

The `fonts-*` packages give WeasyPrint sane default fonts so output is not blank-glyph'd.

### 2. WeasyPrint via uv

```bash
uv tool install weasyprint
```

Verify:

```bash
weasyprint --version
pandoc --version | head -1
```

### 3. Smoke test

```bash
echo '# Hello' | pandoc -f markdown -o /tmp/hello.pdf --pdf-engine=weasyprint
ls -l /tmp/hello.pdf
```

## Usage

Convert a markdown file to PDF:

```bash
pandoc input.md -o output.pdf --pdf-engine=weasyprint
```

Useful flags:

- `--toc` — generate a table of contents
- `--metadata title="My Title"` — set document title
- `-V geometry:margin=1in` — page margins (LaTeX engines only; for WeasyPrint use a CSS file)
- `--css=style.css` — apply custom CSS (WeasyPrint)
- `--standalone` — implied when output is PDF

Example with TOC and custom CSS:

```bash
pandoc input.md \
  -o output.pdf \
  --pdf-engine=weasyprint \
  --toc \
  --css=print.css \
  --metadata title="Report"
```

## Alternative Stacks (not installed by default)

| Stack | Pros | Cons |
|---|---|---|
| `pandoc` + LaTeX (`texlive-xetex`) | Highest typographic quality | ~1+ GB install |
| `pandoc` + `wkhtmltopdf` | Familiar HTML rendering | Unmaintained upstream; older WebKit |
| `markdown-pdf` (npm) | Single tool | Requires Node.js toolchain |
| `uv tool install markdown-pdf` (Python) | Pure Python | Less control over styling |

## Uninstall

```bash
uv tool uninstall weasyprint
sudo apt-get remove -y pandoc
```
