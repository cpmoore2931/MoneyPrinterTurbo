"""Point MoneyPrinterTurbo at an ElevenLabs voice and apply caption defaults.

Prompts for an ElevenLabs API key, lists the voices favorited on that account,
writes the chosen one into config.toml, and upgrades the subtitle styling from
the project's Chinese-font defaults to something suited to English shorts.

Usage:  uv run python setup_voice.py
"""

import getpass
import pathlib
import re
import sys

CONFIG = pathlib.Path(__file__).parent / "config.toml"

# Applied alongside the voice: the stock defaults use a Chinese font and place
# captions where phone UI covers them.
CAPTION_DEFAULTS = {
    "font_name": '"BeVietnamPro-Bold.ttf"',
    "font_size": "72",
    "subtitle_position": '"center"',
    "subtitle_background_enabled": "true",
    "rounded_subtitle_background": "true",
}


def section_bounds(text: str, name: str) -> tuple[int, int]:
    """Return the character span of one [section], excluding later sections."""
    start = text.index(f"[{name}]")
    nxt = re.search(r"^\[[a-z_]+\]", text[start + 1 :], re.M)
    return start, (start + 1 + nxt.start()) if nxt else len(text)


def set_key(text: str, section: str, key: str, value: str) -> str:
    """Set key=value inside one section, uncommenting the line if needed.

    Scoping matters: api_key exists under both [elevenlabs] and [chatterbox],
    so an unscoped substitution would write to whichever came first.
    """
    start, end = section_bounds(text, section)
    head, block, tail = text[:start], text[start:end], text[end:]
    pattern = rf"^#?\s*{re.escape(key)} = .*$"
    line = f"{key} = {value}"
    if re.search(pattern, block, re.M):
        block = re.sub(pattern, line, block, count=1, flags=re.M)
    else:
        block = block.rstrip("\n") + f"\n{line}\n\n"
    return head + block + tail


def get_key(text: str, section: str, key: str) -> str:
    start, end = section_bounds(text, section)
    found = re.search(rf'^{re.escape(key)} = "(.*)"$', text[start:end], re.M)
    return found.group(1) if found else ""


def choose(voices: list[str]) -> str:
    if len(voices) == 1:
        print(f"\n  Using your only favorited voice: {voices[0].split(':')[-1]}")
        return voices[0]
    print("\n  Favorited voices:")
    for i, v in enumerate(voices, 1):
        print(f"    {i}. {v.split(':')[-1]}")
    while True:
        answer = input(f"\n  Pick one [1-{len(voices)}]: ").strip()
        if answer.isdigit() and 1 <= int(answer) <= len(voices):
            return voices[int(answer) - 1]
        print("  Not a valid choice.")


def main() -> int:
    if not CONFIG.exists():
        sys.exit("config.toml not found — run setup-mac.sh first.")
    text = CONFIG.read_text(encoding="utf-8")

    existing = get_key(text, "elevenlabs", "api_key")
    prompt = "  ElevenLabs API key [Return to keep current]: " if existing else "  ElevenLabs API key: "
    entered = getpass.getpass(prompt).strip()
    api_key = entered or existing
    if not api_key:
        sys.exit("  No key given. Get one at https://elevenlabs.io/app/settings/api-keys")
    if entered:
        text = set_key(text, "elevenlabs", "api_key", f'"{entered}"')
        CONFIG.write_text(text, encoding="utf-8")

    # Imported after the key is saved so the service reads the updated config.
    from app.services.voice import get_elevenlabs_voices

    print("\n  Fetching your favorited voices...")
    voices = get_elevenlabs_voices(api_key)
    if not voices:
        sys.exit(
            "\n  No voices came back. Two likely causes:\n"
            "    1. The voice isn't favorited. ElevenLabs only returns favorites --\n"
            "       open https://elevenlabs.io/app/voice-lab and star the voice you want.\n"
            "    2. The API key is wrong.\n"
            "  Fix either one and run this again."
        )

    selected = choose(voices)
    text = set_key(text, "ui", "voice_name", f'"{selected}"')
    text = set_key(text, "ui", "tts_server", '"elevenlabs"')
    for key, value in CAPTION_DEFAULTS.items():
        text = set_key(text, "ui", key, value)
    CONFIG.write_text(text, encoding="utf-8")

    print(f"\n  Voice set to: {selected.split(':')[-1]}")
    print("  Captions upgraded: Latin font, larger text, centered, rounded background.")
    print('\n  Next:  uv run python cli.py --video-subject "lions" --paragraph-number 3\n')
    return 0


if __name__ == "__main__":
    sys.exit(main())
