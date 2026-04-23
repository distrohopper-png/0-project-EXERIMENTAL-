#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, GdkPixbuf, GLib, Gdk
import threading
import requests
import subprocess
import time
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "wallhaven"
WALLPAPER_DIR = Path.home() / "Pictures" / "Wallpapers"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)

CSS = b"""
window {
    background-color: transparent;
}
.toolbar {
    background-color: rgba(10,10,10,0.92);
    border-bottom: 1px solid rgba(255,255,255,0.08);
    padding: 12px 16px;
    border-radius: 16px 16px 0 0;
}
.experimental-label {
    color: rgba(255,255,255,0.25);
    font-size: 10px;
    font-family: "JetBrains Mono";
    letter-spacing: 3px;
}
.search-entry {
    background-color: rgba(255,255,255,0.07);
    color: #e0e0e0;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 20px;
    padding: 6px 14px;
    min-width: 260px;
}
.search-entry:focus {
    border-color: #ffb4aa;
}
scrolledwindow, .flow-area {
    background-color: rgba(10,10,10,0.92);
}
.thumb-card {
    background-color: rgba(255,255,255,0.04);
    border-radius: 10px;
    margin: 4px;
}
.thumb-card:hover {
    background-color: rgba(255,255,255,0.09);
}
.status-bar {
    background-color: rgba(10,10,10,0.92);
    border-top: 1px solid rgba(255,255,255,0.08);
    padding: 6px 16px;
    color: rgba(255,255,255,0.3);
    font-size: 11px;
    border-radius: 0 0 16px 16px;
}
button.clear {
    background-color: transparent;
    border: none;
    color: rgba(255,255,255,0.3);
}
button.clear:hover {
    color: white;
}
"""


class WallpaperPicker(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Wallpaper Picker")
        self.set_default_size(1400, 820)
        self.set_decorated(False)
        self._current_page = 1
        self._current_query = ""
        self._loading = False
        self._build_ui()
        self._fetch(query="", page=1, reset=True)

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)

        # --- Toolbar ---
        toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        toolbar.add_css_class("toolbar")
        root.append(toolbar)

        label = Gtk.Label(label="EXPERIMENTAL")
        label.add_css_class("experimental-label")
        toolbar.append(label)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        toolbar.append(spacer)

        self.search = Gtk.Entry()
        self.search.set_placeholder_text("Search wallhaven.cc...")
        self.search.add_css_class("search-entry")
        self.search.connect("activate", self._on_search)
        toolbar.append(self.search)

        clear_btn = Gtk.Button(label="✕")
        clear_btn.add_css_class("clear")
        clear_btn.connect("clicked", self._on_clear)
        toolbar.append(clear_btn)

        # --- Grid ---
        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_vexpand(True)
        self.scroll.add_css_class("flow-area")
        root.append(self.scroll)

        self.flow = Gtk.FlowBox()
        self.flow.set_max_children_per_line(5)
        self.flow.set_min_children_per_line(2)
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_row_spacing(4)
        self.flow.set_column_spacing(4)
        self.flow.set_margin_top(10)
        self.flow.set_margin_bottom(10)
        self.flow.set_margin_start(10)
        self.flow.set_margin_end(10)
        self.scroll.set_child(self.flow)

        vadj = self.scroll.get_vadjustment()
        vadj.connect("value-changed", self._on_scroll)

        # --- Status bar ---
        self.status = Gtk.Label(label="Loading wallhaven.cc...")
        self.status.set_halign(Gtk.Align.START)
        self.status.add_css_class("status-bar")
        root.append(self.status)

    def _on_scroll(self, adj):
        if self._loading:
            return
        if adj.get_value() >= adj.get_upper() - adj.get_page_size() - 200:
            self._fetch(query=self._current_query,
                        page=self._current_page + 1, reset=False)

    def _on_search(self, entry):
        self._fetch(query=entry.get_text().strip(), page=1, reset=True)

    def _on_clear(self, btn):
        self.search.set_text("")
        self._fetch(query="", page=1, reset=True)

    def _fetch(self, query, page, reset):
        if self._loading:
            return
        self._loading = True
        self._current_query = query
        self._current_page = page
        if reset:
            self.status.set_text("Fetching from wallhaven.cc...")
            while child := self.flow.get_first_child():
                self.flow.remove(child)
        else:
            self.status.set_text(f"Loading page {page}...")
        threading.Thread(
            target=self._fetch_thread, args=(query, page), daemon=True
        ).start()

    def _fetch_thread(self, query, page):
        params = {
            "sorting": "relevance" if query else "hot",
            "order": "desc",
            "atleast": "1920x1080",
            "purity": "100",
            "categories": "111",
            "page": page,
        }
        if query:
            params["q"] = query
        try:
            r = requests.get("https://wallhaven.cc/api/v1/search",
                             params=params, timeout=10)
            wallpapers = r.json().get("data", [])
        except Exception as e:
            GLib.idle_add(self.status.set_text, f"Error: {e}")
            self._loading = False
            return

        for w in wallpapers:
            GLib.idle_add(self._add_card, w)
        GLib.idle_add(self.status.set_text,
                      f"Page {page}  •  wallhaven.cc  •  scroll for more")
        self._loading = False

    def _add_card(self, w):
        wid = w["id"]
        thumb_url = w["thumbs"]["large"]
        thumb_path = CACHE_DIR / f"{wid}_thumb.jpg"

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        card.add_css_class("thumb-card")
        card.set_focusable(True)
        card.set_has_tooltip(False)
        card._wallpaper = w

        picture = Gtk.Picture()
        picture.set_size_request(260, 160)
        picture.set_content_fit(Gtk.ContentFit.COVER)
        picture.set_has_tooltip(False)
        card.append(picture)

        click = Gtk.GestureClick()
        click.connect("released",
                      lambda g, n, x, y, wp=w: threading.Thread(
                          target=self._apply, args=(wp,), daemon=True
                      ).start())
        card.add_controller(click)

        self.flow.append(card)

        threading.Thread(
            target=self._load_thumb,
            args=(thumb_url, thumb_path, picture),
            daemon=True
        ).start()

    def _load_thumb(self, url, path, picture):
        try:
            if not path.exists():
                r = requests.get(url, timeout=15)
                path.write_bytes(r.content)
            GLib.idle_add(picture.set_filename, str(path))
        except Exception:
            pass

    def _apply(self, w):
        url = w["path"]
        ext = url.rsplit(".", 1)[-1]
        dest = WALLPAPER_DIR / f"{w['id']}.{ext}"
        thumb = CACHE_DIR / f"{w['id']}_thumb.jpg"
        try:
            if not dest.exists():
                GLib.idle_add(self.status.set_text, "Downloading...")
                r = requests.get(url, timeout=60, stream=True)
                dest.write_bytes(r.content)
        except Exception as e:
            GLib.idle_add(self.status.set_text, f"Download failed: {e}")
            return

        # symlink so lock screen and other tools always find the current wallpaper
        link = Path.home() / ".cache" / "current-wallpaper"
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(dest)

        # pre-generate blurred version for the lock screen (instant bg, no delay at lock time)
        blur_out = Path.home() / ".cache" / "current-wallpaper-blurred"
        subprocess.Popen(
            ["convert", str(dest),
             "-filter", "Gaussian", "-blur", "0x18",
             "-modulate", "70",
             str(blur_out)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

        # only start daemon if not already running — restarting kills the existing one
        daemon_running = subprocess.run(
            ["pgrep", "-x", "awww-daemon"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        ).returncode == 0
        if not daemon_running:
            subprocess.Popen(["awww-daemon"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            time.sleep(1.0)  # give fresh daemon time to initialize

        subprocess.run(["awww", "img", str(dest),
                        "--resize", "crop",
                        "--transition-type", "fade",
                        "--transition-duration", "0.4"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # invalidate fetch cache now so any terminal opened during matugen
        # rebuilds rather than showing stale colors
        subprocess.run(["rm", "-f", "/tmp/zsh_fastfetch.jsonc", "/tmp/zsh_palette.sh"])
        Path("/tmp/matugen-running").touch()
        GLib.idle_add(self.status.set_text, "Applying color theme…")

        matugen_proc = subprocess.Popen(
            ["matugen", "image", str(dest)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

        def _post_matugen():
            import re, colorsys as _cs
            matugen_proc.wait()

            colors_file = Path.home() / ".config" / "zsh" / "colors.zsh"

            # Find the dominant hue of the wallpaper by counting pixels per hue bucket,
            # ignoring very dark or desaturated pixels so background noise doesn't win.
            def _dominant_hue(path):
                # Prefer thumbnail for speed (already small); fall back to full image
                src = str(thumb) if thumb.exists() else str(path)
                try:
                    out = subprocess.check_output(
                        ["convert", src, "-resize", "60x60!",
                         "-depth", "8", "-colorspace", "sRGB", "txt:-"],
                        text=True, timeout=15
                    )
                    buckets = [0] * 36
                    for line in out.splitlines():
                        m = re.search(r'#([0-9A-Fa-f]{6})', line)
                        if not m:
                            continue
                        c = m.group(1)
                        rv, gv, bv = int(c[0:2],16)/255, int(c[2:4],16)/255, int(c[4:6],16)/255
                        hv, sv, vv = _cs.rgb_to_hsv(rv, gv, bv)
                        if sv > 0.10 and vv > 0.20:
                            buckets[int(hv * 36) % 36] += 1
                    return None if max(buckets) == 0 else buckets.index(max(buckets)) * 10
                except Exception:
                    return None

            dom_hue = _dominant_hue(dest)

            # If matugen's primary color is more than 55° away from the dominant wallpaper
            # hue (e.g. wallpaper is yellow but matugen grabbed a vivid blue accent object),
            # re-run matugen in color mode seeded with the actual dominant hue.
            if dom_hue is not None and colors_file.exists():
                m = re.search(r'ZSH_C1="#([0-9a-fA-F]{6})"', colors_file.read_text())
                if m:
                    c = m.group(1)
                    c1_hue = _cs.rgb_to_hsv(
                        int(c[0:2],16)/255, int(c[2:4],16)/255, int(c[4:6],16)/255
                    )[0] * 360
                    diff = abs(c1_hue - dom_hue)
                    diff = min(diff, 360 - diff)
                    if diff > 55:
                        dr, dg, db = _cs.hsv_to_rgb(dom_hue / 360.0, 0.60, 0.72)
                        dom_hex = f"#{int(dr*255):02x}{int(dg*255):02x}{int(db*255):02x}"
                        subprocess.run(
                            ["matugen", "color", "hex", dom_hex],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            timeout=30
                        )

            # For light achromatic wallpapers (white/grey) matugen amplifies faint
            # undertones into vivid arbitrary colours. Detect with HSL saturation +
            # HSB brightness: only apply neutral palette if the image is both
            # unsaturated AND light (bright). Dark near-black wallpapers also have
            # near-zero saturation but should keep whatever matugen generated.
            try:
                src = str(thumb) if thumb.exists() else str(dest)
                avg_sat_str = subprocess.run(
                    ["convert", src, "-colorspace", "HSL",
                     "-channel", "S", "-separate",
                     "-format", "%[fx:mean]", "info:"],
                    capture_output=True, text=True, timeout=15
                ).stdout.strip()
                avg_sat = float(avg_sat_str) if avg_sat_str else 1.0
            except Exception:
                avg_sat = 1.0

            if avg_sat < 0.12:
                # Achromatic wallpaper — tag colors.zsh so zshrc uses gentle boost
                # (avoids matugen's subtle tints being amplified to vivid blue/pink).
                # Also neutralize kitty background so it doesn't pick up a colour tint.
                if colors_file.exists():
                    content = colors_file.read_text().rstrip('\n')
                    if 'ZSH_ACHROMATIC' not in content:
                        colors_file.write_text(content + '\nZSH_ACHROMATIC=1\n')
                kitty_conf = Path.home() / ".config" / "kitty" / "kitty.conf"
                if kitty_conf.exists():
                    kt = kitty_conf.read_text()
                    kt = re.sub(r'(?m)^background #[0-9a-fA-F]{6}', 'background #0e0e10', kt)
                    kt = re.sub(r'(?m)^foreground #[0-9a-fA-F]{6}', 'foreground #d0d0d0', kt)
                    kitty_conf.write_text(kt)

            # kill cava so it reloads the new gradient config
            subprocess.run(["pkill", "cava"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # reload colors in all running kitty windows (non-blocking)
            subprocess.Popen(["kitty", "@", "set-colors", "--all", "--configured"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # signal terminals that colors are ready
            Path("/tmp/matugen-running").unlink(missing_ok=True)
            # close window now that colors are fully written
            GLib.idle_add(self.close)

        threading.Thread(target=_post_matugen, daemon=True).start()
        # sync wallpaper to SDDM theme (script needs NOPASSWD sudo)
        subprocess.Popen(["sudo", "/usr/local/bin/sddm-bg-update", str(dest)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="cc.wallhaven.picker")

    def do_activate(self):
        existing = self.get_windows()
        if existing:
            existing[0].present()
            return
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        win = WallpaperPicker(self)
        win.present()


App().run()
