#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk
import json
from pathlib import Path

CONFIG = Path.home() / ".config" / "quickshell" / "quotes.json"

DEFAULT_QUOTES = [
    "I use Arch btw",
    "404 motivation not found",
    "works on my machine",
    "git blame yourself",
    "it's not a bug, it's a feature",
    "have you tried turning it off and on again",
    "sudo make me a sandwich",
    "there are 2 types of people",
    "still compiling...",
    "segmentation fault (core dumped)",
    "why is it always DNS",
    "to be or not to be",
    "technically correct is the best kind of correct",
    "rm -rf node_modules",
    "it works on my machine → ship the machine",
    "coffee.exe has stopped responding",
    "undefined is not a function",
    "have you met my friend NaN",
    "while (alive) { eat(); sleep(); code(); }",
    "0 bugs found... in my opinion",
]

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
.title-label {
    color: rgba(255,255,255,0.25);
    font-size: 10px;
    font-family: "JetBrains Mono";
    letter-spacing: 3px;
}
.body {
    background-color: rgba(10,10,10,0.92);
    padding: 16px;
}
.text-area {
    background-color: rgba(255,255,255,0.05);
    color: #e0e0e0;
    border: 1px solid rgba(255,255,255,0.10);
    border-radius: 10px;
    font-family: "JetBrains Mono";
    font-size: 12px;
}
.text-area text {
    background-color: transparent;
    color: #e0e0e0;
}
.hint-label {
    color: rgba(255,255,255,0.25);
    font-size: 10px;
    font-family: "JetBrains Mono";
    margin-bottom: 4px;
}
.interval-label {
    color: rgba(255,255,255,0.6);
    font-family: "JetBrains Mono";
    font-size: 11px;
}
.save-btn {
    background-color: rgba(255,180,170,0.15);
    color: #ffb4aa;
    border: 1px solid rgba(255,180,170,0.3);
    border-radius: 20px;
    padding: 8px 24px;
    font-family: "JetBrains Mono";
    font-size: 11px;
}
.save-btn:hover {
    background-color: rgba(255,180,170,0.28);
}
button.clear {
    background-color: transparent;
    border: none;
    color: rgba(255,255,255,0.3);
}
button.clear:hover {
    color: white;
}
.status-bar {
    background-color: rgba(10,10,10,0.92);
    border-top: 1px solid rgba(255,255,255,0.08);
    padding: 6px 16px;
    color: rgba(255,255,255,0.3);
    font-size: 11px;
    border-radius: 0 0 16px 16px;
    font-family: "JetBrains Mono";
}
spinbutton {
    background-color: rgba(255,255,255,0.07);
    color: #e0e0e0;
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 8px;
    font-family: "JetBrains Mono";
    font-size: 11px;
    min-width: 80px;
}
"""


def _load():
    try:
        d = json.loads(CONFIG.read_text())
        return d.get("quotes", list(DEFAULT_QUOTES)), int(d.get("interval_sec", 300))
    except Exception:
        return list(DEFAULT_QUOTES), 300


def _save(quotes, interval_sec):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(
        json.dumps({"quotes": quotes, "interval_sec": interval_sec}, indent=2) + "\n"
    )


class QuotesEditor(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Quote Editor")
        self.set_default_size(480, 460)
        self.set_decorated(False)
        self._build_ui()

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)

        toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        toolbar.add_css_class("toolbar")
        root.append(toolbar)

        lbl = Gtk.Label(label="QUOTE EDITOR")
        lbl.add_css_class("title-label")
        toolbar.append(lbl)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        toolbar.append(spacer)

        close_btn = Gtk.Button(label="✕")
        close_btn.add_css_class("clear")
        close_btn.connect("clicked", lambda _: self.close())
        toolbar.append(close_btn)

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        body.add_css_class("body")
        body.set_vexpand(True)
        root.append(body)

        hint = Gtk.Label(label="One phrase per line:")
        hint.set_halign(Gtk.Align.START)
        hint.add_css_class("hint-label")
        body.append(hint)

        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        body.append(scroll)

        self.textview = Gtk.TextView()
        self.textview.add_css_class("text-area")
        self.textview.set_wrap_mode(Gtk.WrapMode.NONE)
        self.textview.set_left_margin(12)
        self.textview.set_right_margin(12)
        self.textview.set_top_margin(10)
        self.textview.set_bottom_margin(10)
        scroll.set_child(self.textview)

        interval_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        interval_row.set_halign(Gtk.Align.END)
        body.append(interval_row)

        iv_lbl = Gtk.Label(label="Switch every")
        iv_lbl.add_css_class("interval-label")
        interval_row.append(iv_lbl)

        adj = Gtk.Adjustment(
            value=300, lower=5, upper=86400, step_increment=10, page_increment=60
        )
        self.spin = Gtk.SpinButton(adjustment=adj, climb_rate=1.0, digits=0)
        interval_row.append(self.spin)

        s_lbl = Gtk.Label(label="seconds")
        s_lbl.add_css_class("interval-label")
        interval_row.append(s_lbl)

        save_btn = Gtk.Button(label="Save")
        save_btn.add_css_class("save-btn")
        save_btn.set_halign(Gtk.Align.END)
        save_btn.connect("clicked", self._on_save)
        body.append(save_btn)

        self.status = Gtk.Label(label="Edit your phrases above, then save.")
        self.status.set_halign(Gtk.Align.START)
        self.status.add_css_class("status-bar")
        root.append(self.status)

        quotes, interval = _load()
        self.textview.get_buffer().set_text("\n".join(quotes))
        self.spin.set_value(interval)

    def _on_save(self, _btn):
        buf = self.textview.get_buffer()
        text = buf.get_text(buf.get_start_iter(), buf.get_end_iter(), False)
        quotes = [q.strip() for q in text.splitlines() if q.strip()]
        if not quotes:
            self.status.set_text("No phrases entered — not saved.")
            return
        interval = int(self.spin.get_value())
        _save(quotes, interval)
        self.status.set_text(f"Saved {len(quotes)} phrases · interval {interval}s · takes effect within 30s.")


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="cc.wallhaven.quotes")

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
        win = QuotesEditor(self)
        win.present()


App().run()
