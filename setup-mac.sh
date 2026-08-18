#!/usr/bin/env bash
#
# First-run setup for MoneyPrinterTurbo on macOS.
#
# Installs dependencies, creates config.toml, collects the two API keys the
# pipeline needs, and optionally generates a first video.
#
# Usage:  sh setup-mac.sh

set -euo pipefail

cd "$(dirname "$0")"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[ -f cli.py ] || fail "run this from the MoneyPrinterTurbo folder"

bold "MoneyPrinterTurbo setup"
echo

# --- 1. uv ------------------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  info "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # The installer drops uv in one of these; pick up whichever exists.
  for d in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
    [ -x "$d/uv" ] && PATH="$d:$PATH"
  done
  export PATH
  command -v uv >/dev/null 2>&1 || fail "uv installed but not on PATH; open a new Terminal and re-run"
fi
info "uv: $(command -v uv)"

# --- 2. Python + dependencies ----------------------------------------------
info "Installing Python 3.11 and dependencies (a few minutes the first time)..."
uv python install 3.11
uv sync --frozen
echo

# --- 3. config.toml ---------------------------------------------------------
[ -f config.toml ] || cp config.example.toml config.toml
info "config file: $(pwd)/config.toml"
echo

bold "API keys"
info "Both are free and neither needs a credit card."
info "Groq   (writes the script) -> https://console.groq.com/keys"
info "Pexels (finds the footage) -> https://www.pexels.com/api/"
info "Input is hidden while you paste. Press Return to keep an existing key."
echo

read -rsp "  Groq API key:   " GROQ_KEY; echo
read -rsp "  Pexels API key: " PEXELS_KEY; echo
echo

GROQ_KEY="$GROQ_KEY" PEXELS_KEY="$PEXELS_KEY" uv run python - <<'PY'
import os, pathlib, re, sys, tomllib

path = pathlib.Path("config.toml")
text = path.read_text(encoding="utf-8")

def set_scalar(src, key, value):
    pattern = rf'^{re.escape(key)} = .*$'
    if not re.search(pattern, src, re.M):
        sys.exit(f"could not find '{key}' in config.toml")
    return re.sub(pattern, f'{key} = "{value}"', src, count=1, flags=re.M)

def set_list(src, key, value):
    pattern = rf'^{re.escape(key)} = .*$'
    if not re.search(pattern, src, re.M):
        sys.exit(f"could not find '{key}' in config.toml")
    return re.sub(pattern, f'{key} = ["{value}"]', src, count=1, flags=re.M)

groq = os.environ.get("GROQ_KEY", "").strip()
pexels = os.environ.get("PEXELS_KEY", "").strip()

# A blank answer keeps whatever is already saved, so re-running is safe.
text = set_scalar(text, "llm_provider", "groq")
if groq:
    if not groq.startswith("gsk_"):
        print("  Note: Groq keys normally start with 'gsk_'. Saving it anyway.")
    text = set_scalar(text, "groq_api_key", groq)
if pexels:
    if pexels.startswith("gsk_"):
        sys.exit("  That looks like a Groq key, not a Pexels key. Re-run and paste the Pexels one.")
    text = set_list(text, "pexels_api_keys", pexels)

path.write_text(text, encoding="utf-8")

# Fail loudly now rather than mid-render.
cfg = tomllib.loads(text)["app"]
missing = [n for n, v in (("Groq", cfg.get("groq_api_key")),
                          ("Pexels", cfg.get("pexels_api_keys"))) if not v]
if missing:
    sys.exit("  Still missing: " + ", ".join(missing) + " — re-run this script to add them.")
print("  Keys saved to config.toml (git-ignored, stays on this Mac).")
PY
echo

# --- 4. First video ---------------------------------------------------------
bold "Setup complete"
info "Make a video:  uv run python cli.py --video-subject \"your topic\""
info "Browser UI:    sh webui.sh"
echo

read -rp "  Generate a first video now? [Y/n] " REPLY
case "${REPLY:-Y}" in
  [Nn]*) info "Skipped. Run the command above whenever you're ready." ;;
  *)
    read -rp "  Topic [Why coffee wakes you up]: " SUBJECT
    SUBJECT="${SUBJECT:-Why coffee wakes you up}"
    echo
    info "Generating. First run also downloads ffmpeg, so give it a few minutes."
    echo
    uv run python cli.py --video-subject "$SUBJECT"
    echo
    info "Done. Your video is in the storage/tasks folder:"
    find storage/tasks -name '*.mp4' -maxdepth 2 2>/dev/null | tail -5
    ;;
esac
