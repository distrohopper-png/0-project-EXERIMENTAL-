#!/usr/bin/env python3
# Volume overlay daemon — send SIGUSR1 to update, auto-hides after 1.5s
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
    background: rgba(8,8,8,0.78);
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.07);
    padding: 0 22px;
    min-height: 38px;
}
.icon {
    font-family: "Symbols Nerd Font";
    font-size: 15px;
    color: rgba(255,255,255,0.55);
}
.muted { color: #ff5555; }
.vol-label {
    font-family: "JetBrains Mono";
    font-size: 11px;
    color: rgba(255,255,255,0.65);
    min-width: 36px;
}
"""

BAR_W = 300
BAR_H = 4

_hide_src  = None
_win       = None
_icon      = None
_bar_area  = None
_label     = None
_vol_frac  = 0.0

def _draw_bar(area, cr, w, h):
    r = BAR_H / 2
    y = (h - BAR_H) / 2
    # track
    cr.set_source_rgba(1, 1, 1, 0.14)
    cr.arc(r, y + r, r, 3.14159/2*3, 3.14159/2)
    cr.arc(w - r, y + r, r, -3.14159/2, 3.14159/2)
    cr.close_path()
    cr.fill()
    # fill
    fill_w = max(BAR_H, w * _vol_frac)
    cr.set_source_rgba(1, 1, 1, 0.82)
    cr.arc(r, y + r, r, 3.14159/2*3, 3.14159/2)
    cr.arc(fill_w - r, y + r, r, -3.14159/2, 3.14159/2)
    cr.close_path()
    cr.fill()

def _schedule_hide():
    global _hide_src
    if _hide_src:
        GLib.source_remove(_hide_src)
    _hide_src = GLib.timeout_add(1800, _do_hide)

def _do_hide():
    global _hide_src
    _hide_src = None
    if _win:
        _win.set_visible(False)
    return False

def _refresh(*_):
    global _vol_frac
    vol, muted = get_volume()
    _vol_frac = vol / 100
    _icon.set_label("󰝟" if muted else "󰕾")
    _icon.set_css_classes(["icon", "muted"] if muted else ["icon"])
    _bar_area.queue_draw()
    _label.set_label(f"{vol}%")
    _win.set_visible(True)
    _schedule_hide()

def _on_sigusr1(signum, frame):
    GLib.idle_add(_refresh)

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="arch.volume.overlay")

    def do_activate(self):
        global _win, _icon, _bar_area, _label
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
        LayerShell.set_anchor(win, LayerShell.Edge.LEFT,   True)
        LayerShell.set_anchor(win, LayerShell.Edge.RIGHT,  True)
        LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, 50)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
        LayerShell.set_exclusive_zone(win, 0)

        # Outer transparent box fills full width; pill centers inside it
        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        outer.set_hexpand(True)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        row.add_css_class("pill")
        row.set_halign(Gtk.Align.CENTER)
        row.set_valign(Gtk.Align.CENTER)
        outer.append(row)

        _icon = Gtk.Label()
        _icon.add_css_class("icon")
        _icon.set_valign(Gtk.Align.CENTER)

        _bar_area = Gtk.DrawingArea()
        _bar_area.set_size_request(BAR_W, 20)
        _bar_area.set_valign(Gtk.Align.CENTER)
        _bar_area.set_draw_func(_draw_bar)

        _label = Gtk.Label()
        _label.add_css_class("vol-label")
        _label.set_valign(Gtk.Align.CENTER)

        row.append(_icon)
        row.append(_bar_area)
        row.append(_label)
        win.set_child(outer)

        signal.signal(signal.SIGUSR1, _on_sigusr1)
        _refresh()

App().run()
