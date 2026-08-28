"""Verify Edge gateway JWT modes with Python's standard TOML parser."""

from pathlib import Path
import tomllib


config_path = Path(__file__).resolve().parents[1] / "config.toml"
with config_path.open("rb") as config_file:
    config = tomllib.load(config_file)

functions = config.get("functions", {})

assert functions.get("invitation-resolve", {}).get("verify_jwt") is False
assert functions.get("invitation-rsvp", {}).get("verify_jwt") is False
assert functions.get("wedding-delete", {}).get("verify_jwt") is True

print("M8.5B function gateway JWT configuration: PASS")
