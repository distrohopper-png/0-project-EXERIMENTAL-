#!/usr/bin/env python3
import gi, subprocess
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk, GLib

CSS = b"""
* {
    all: unset;
    color: white;
    font-size: 13px;
    font-family: "JetBrains Mono", monospace;
}
window {
    background-color: rgba(8, 8, 8, 0.80);
    border-radius: 12px;
}
.popup-box {
    padding: 6px;
}
button {
    background-color: transparent;
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 10px;
    padding: 9px 14px;
    margin: 2px 0;
    min-width: 160px;
}
button:hover {
    background-color: rgba(255, 255, 255, 0.10);
    border-color: rgba(255, 255, 255, 0.22);
}
button:active {
    background-color: rgba(255, 255, 255, 0.18);
}
"""

ACTIONS = [
    ("⏻   Shutdown",  ["systemctl", "poweroff"]),
    ("   Reboot",    ["systemctl", "reboot"]),
    ("   Log Out",   ["hyprctl", "dispatch", "exit"]),
    ("⏾   Suspend",   ["systemctl", "suspend"]),
]

class PowerPopup(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="powerpopup")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(190, -1)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.add_css_class("popup-box")
        self.set_child(box)

        for label, cmd in ACTIONS:
            btn = Gtk.Button(label=label)
            btn.set_halign(Gtk.Align.FILL)
            btn.connect("clicked", lambda _, c=cmd: self._run(c))
            box.append(btn)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        self.add_controller(key)

        GLib.timeout_add(500, self._arm_focus_close)

    def _arm_focus_close(self):
        self.connect("notify::is-active", self._on_focus_change)
        return False

    def _on_key(self, ctrl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.close()

    def _run(self, cmd):
        self.close()
        GLib.timeout_add(80, lambda: subprocess.Popen(cmd,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) and False)

    def _on_focus_change(self, *_):
        if not self.is_active():
            self.close()


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="arch.powerpopup")

    def do_activate(self):
        existing = self.get_windows()
        if existing:
            existing[0].present()
            return
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
        win = PowerPopup(self)
        win.present()


App().run()
