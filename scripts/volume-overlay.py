#!/usr/bin/env python3
import os, sys, gi, signal
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell as LayerShell
import subprocess

def get_volume():
    try:
        out = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True)
        muted = "[MUTED]" in out
        return min(int(float(out.split()[1]) * 100), 100), muted
    except Exception:
        return 0, False

CSS = b"""
window { background: transparent; }
.pill {
    background: rgba(6,6,6,0.60);
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.07);
    padding: 0 18px;
    min-height: 36px;
    min-width: 420px;
}
.icon {
    font-family: "Symbols Nerd Font";
    font-size: 14px;
    color: rgba(255,255,255,0.5);
}
.muted { color: #ff5555; }
.pct {
    font-family: "JetBrains Mono";
    font-size: 10px;
    color: rgba(255,255,255,0.55);
    min-width: 34px;
}
"""

_hide_src = None
_win      = None
_icon     = None
_bar      = None
_pct      = None
_frac     = 0.0

def _draw(area, cr, w, h):
    bh = 3
    y  = (h - bh) / 2
    cr.set_source_rgba(1, 1, 1, 0.12)
    cr.rectangle(0, y, w, bh)
    cr.fill()
    cr.set_source_rgba(1, 1, 1, 0.75)
    cr.rectangle(0, y, w * _frac, bh)
    cr.fill()

def _schedule_hide():
    global _hide_src
    if _hide_src:
        GLib.source_remove(_hide_src)
    _hide_src = GLib.timeout_add(1800, _do_hide)

def _do_hide():
    global _hide_src
    _hide_src = None
    _win.set_visible(False)
    return False

def _refresh(*_):
    global _frac
    vol, muted = get_volume()
    _frac = vol / 100
    _icon.set_label("󰝟" if muted else "󰕾")
    _icon.set_css_classes(["icon", "muted"] if muted else ["icon"])
    _bar.queue_draw()
    _pct.set_label(f"{vol}%")
    _win.set_visible(True)
    _schedule_hide()

def _sig(*_):
    GLib.idle_add(_refresh)

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="arch.volume.overlay")

    def do_activate(self):
        global _win, _icon, _bar, _pct
        self.hold()

        p = Gtk.CssProvider()
        p.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        _win = win

        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, 52)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
        LayerShell.set_exclusive_zone(win, 0)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("pill")
        row.set_valign(Gtk.Align.CENTER)

        _icon = Gtk.Label()
        _icon.add_css_class("icon")
        _icon.set_valign(Gtk.Align.CENTER)

        _bar = Gtk.DrawingArea()
        _bar.set_hexpand(True)
        _bar.set_size_request(-1, 20)
        _bar.set_valign(Gtk.Align.CENTER)
        _bar.set_draw_func(_draw)

        _pct = Gtk.Label()
        _pct.add_css_class("pct")
        _pct.set_valign(Gtk.Align.CENTER)

        row.append(_icon)
        row.append(_bar)
        row.append(_pct)
        win.set_child(row)

        signal.signal(signal.SIGUSR1, _sig)
        _refresh()

App().run()
