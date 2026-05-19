#!/usr/bin/env python3
"""
Waybar custom/media module — outputs JSON with current playing track info.
Requires: playerctl
"""
import json
import subprocess
import sys


def get_players():
    try:
        out = subprocess.run(
            ["playerctl", "-l"],
            capture_output=True, text=True, timeout=2
        )
        return [p.strip() for p in out.stdout.strip().split("\n") if p.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def get_metadata(player):
    try:
        status = subprocess.run(
            ["playerctl", "-p", player, "status"],
            capture_output=True, text=True, timeout=1
        ).stdout.strip()

        title = subprocess.run(
            ["playerctl", "-p", player, "metadata", "title"],
            capture_output=True, text=True, timeout=1
        ).stdout.strip()

        artist = subprocess.run(
            ["playerctl", "-p", player, "metadata", "artist"],
            capture_output=True, text=True, timeout=1
        ).stdout.strip()

        return status, title, artist
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return "", "", ""


def main():
    players = get_players()

    for player in players:
        status, title, artist = get_metadata(player)
        if status == "Playing" and title:
            text = f"{artist} - {title}" if artist else title
            return json.dumps({
                "text": text,
                "class": f"custom-{player}",
                "alt": player,
                "tooltip": f"{player}\n{artist}\n{title}"
            })

    # Check for any paused player
    for player in players:
        status, title, artist = get_metadata(player)
        if status == "Paused" and title:
            text = f"(paused) {artist} - {title}" if artist else f"(paused) {title}"
            return json.dumps({
                "text": text,
                "class": f"custom-{player}",
                "alt": player,
                "tooltip": f"{player}\n{artist}\n{title}"
            })

    # Nothing playing
    return json.dumps({"text": "", "class": "custom-none"})


if __name__ == "__main__":
    print(main())
    sys.stdout.flush()
