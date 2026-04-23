#!/usr/bin/env python3
# Volume overlay daemon — send SIGUSR1 to update, auto-hides after 1.5s
# Launch: python3 volume-overlay.py &
# Update: pkill -USR1 -f volume-overlay.py || python3 volume-overlay.py &
import os, sys, gi, signal
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell as LayerShell
import subprocess

def get_volume():
    try:
        out = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True)
        muted = "[MUTED]" in out
        val = float(out.split()[1])
        return min(int(val * 100), 100), muted
    except Exception:
        return 0, False

CSS = b"""
window { background: transparent; }
.pill {
    background: rgba(10,10,10,0.92);
    border-radius: 18px;
    border: 1px solid rgba(255,255,255,0.08);
    padding: 0 20px;
    min-height: 36px;
}
.icon {
    font-family: "Symbols Nerd Font";
    font-size: 14px;
    color: rgba(255,255,255,0.7);
}
.muted { color: #ff5555; }
.vol-label {
    font-family: "JetBrains Mono";
    font-size: 11px;
    color: rgba(255,255,255,0.85);
    min-width: 38px;
}
progressbar trough {
    background: rgba(255,255,255,0.15);
    border-radius: 2px;
    min-height: 4px;
    min-width: 300px;
}
progressbar progress {
    background: white;
    border-radius: 2px;
    min-height: 4px;
}
"""

_hide_src  = None
_win       = None
_icon      = None
_bar       = None
_label     = None

def _schedule_hide():
    global _hide_src
    if _hide_src:
        GLib.source_remove(_hide_src)
    _hide_src = GLib.timeout_add(1500, _do_hide)

def _do_hide():
    global _hide_src
    _hide_src = None
    if _win:
        _win.set_visible(False)
    return False

def _refresh(*_):
    vol, muted = get_volume()
    _icon.set_label("󰝟" if muted else "󰕾")
    _icon.set_css_classes(["icon", "muted"] if muted else ["icon"])
    _bar.set_fraction(vol / 100)
    _label.set_label(f"{vol}%")
    _win.set_visible(True)
    _schedule_hide()

def _on_sigusr1(signum, frame):
    GLib.idle_add(_refresh)

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="arch.volume.overlay")

    def do_activate(self):
        global _win, _icon, _bar, _label
        self.hold()

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        _win = win

        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, 48)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
        LayerShell.set_exclusive_zone(win, 0)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("pill")

        _icon = Gtk.Label()
        _icon.add_css_class("icon")

        _bar = Gtk.ProgressBar()

        _label = Gtk.Label()
        _label.add_css_class("vol-label")

        row.append(_icon)
        row.append(_bar)
        row.append(_label)
        win.set_child(row)

        signal.signal(signal.SIGUSR1, _on_sigusr1)
        _refresh()

App().run()
