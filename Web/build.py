"""Prepare the dependency-free static PWA for Cloudflare Pages Direct Upload."""

from hashlib import sha256
from pathlib import Path
from shutil import copy2, rmtree
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"
FILES = ["index.html", "style.css", "app.js", "core.js", "manifest.webmanifest", "_headers"]
ASSETS = ["icon.png", "rest.png", "complete.png", "ended.png", "complete.wav"]

if DIST.exists():
    rmtree(DIST)
(DIST / "assets").mkdir(parents=True)
for name in FILES:
    copy2(ROOT / name, DIST / name)
for name in ASSETS:
    copy2(ROOT / "assets" / name, DIST / "assets" / name)

digest = sha256()
for name in FILES + [f"assets/{name}" for name in ASSETS]:
    digest.update((DIST / name).read_bytes())
digest.update((ROOT / "sw.js").read_bytes())
version = digest.hexdigest()[:12]
service_worker = (ROOT / "sw.js").read_text()
service_worker = service_worker.replace("cycle-timer-v1", f"cycle-timer-{version}")
(DIST / "sw.js").write_text(service_worker)

archive = ROOT / "cycle-timer-pages.zip"
with ZipFile(archive, "w", ZIP_DEFLATED) as output:
    for file in DIST.rglob("*"):
        if file.is_file():
            output.write(file, file.relative_to(DIST))
print(f"Prepared {DIST} and {archive}")
