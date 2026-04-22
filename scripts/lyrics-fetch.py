#!/usr/bin/env python3
import sys
import re
import urllib.request
import urllib.parse
import json

def main():
    if len(sys.argv) < 3:
        return
    artist = sys.argv[1]
    title = sys.argv[2]
    duration = 0
    if len(sys.argv) >= 4:
        try:
            duration = int(sys.argv[3]) // 1000000  # microseconds → seconds
        except (ValueError, OverflowError):
            duration = 0

    params = urllib.parse.urlencode({
        "artist_name": artist,
        "track_name": title,
        "duration": duration,
    })
    url = "https://lrclib.net/api/get?" + params
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell-lyrics/1.0"})
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read())
    except Exception:
        return

    lrc = data.get("syncedLyrics") or ""
    if not lrc:
        return

    for line in lrc.split("\n"):
        m = re.match(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)", line)
        if m:
            mins, secs, text = m.groups()
            t = float(mins) * 60 + float(secs)
            text = text.strip()
            if text:
                print(f"{t:.3f}|{text}")
    sys.stdout.flush()

main()
