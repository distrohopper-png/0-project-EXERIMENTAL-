#!/usr/bin/env python3
"""Custom Wayland lock screen — gtk4-layer-shell + python-pam"""

import os, sys

# gtk4-layer-shell must be loaded before libwayland — re-exec with LD_PRELOAD if needed
_SO = "/usr/lib/libgtk4-layer-shell.so"
if _SO not in os.environ.get("LD_PRELOAD", ""):
    os.environ["LD_PRELOAD"] = _SO + (":" + os.environ["LD_PRELOAD"] if os.environ.get("LD_PRELOAD") else "")
    os.execv(sys.executable, [sys.executable] + sys.argv)

import gi, subprocess, threading, getpass, signal
from datetime import datetime

try:
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gtk4LayerShell", "1.0")
except ValueError as e:
    sys.exit(f"Missing GI bindings: {e}\nInstall: sudo pacman -S gtk4-layer-shell")

from gi.repository import Gtk, Gdk, GLib
from gi.repository import Gtk4LayerShell as LayerShell

try:
    import pam
except ImportError:
    sys.exit("python-pam not installed\nInstall: sudo pacman -S python-pam")

WALLPAPER  = os.path.expanduser("~/.cache/current-wallpaper")
BLURRED_WP = os.path.expanduser("~/.cache/current-wallpaper-blurred")

CSS = """
* {
    all: unset;
    font-family: "JetBrains Mono", monospace;
}

.fallback-bg  { background-color: #070707; }
.dark-dim     { background-color: rgba(0, 0, 0, 0.58); }

.time-label {
    font-size: 92px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.93);
    letter-spacing: -3px;
}

.date-label {
    font-size: 17px;
    color: rgba(255, 255, 255, 0.46);
    margin-top: 4px;
    margin-bottom: 38px;
}

/* Invisible entry — keyboard capture only */
.pw-entry-hidden {
    opacity: 0;
    min-width: 1px;
    min-height: 1px;
}

/* Visible dot pill */
.pw-dot-pill {
    background-color: rgba(255, 255, 255, 0.07);
    border: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 22px;
    padding: 0 28px;
    min-width: 280px;
    min-height: 44px;
    transition: border-color 200ms ease, background-color 200ms ease;
}

.pw-dot-pill.focused {
    background-color: rgba(255, 255, 255, 0.11);
    border-color: rgba(255, 255, 255, 0.38);
}

.pw-hint {
    color: rgba(255, 255, 255, 0.28);
    font-size: 14px;
}

/* Animated password dot */
.pw-dot {
    background-color: rgba(255, 255, 255, 0.9);
    border-radius: 8px;
    min-width: 11px;
    min-height: 11px;
    transition: min-width  160ms ease,
                min-height 160ms ease,
                opacity    160ms ease;
}

.pw-dot.entering {
    min-width:  2px;
    min-height: 2px;
    opacity: 0;
}

/* Shake on wrong password */
@keyframes pw-shake {
    0%,  100% { transform: translateX(0px);  }
    20%        { transform: translateX(-12px); }
    40%        { transform: translateX( 12px); }
    60%        { transform: translateX( -8px); }
    80%        { transform: translateX(  8px); }
}

.pw-dot-pill.shake {
    animation: pw-shake 340ms ease;
}

.error-label {
    font-size: 12px;
    color: rgba(255, 80, 80, 0.9);
    margin-top: 10px;
}

/* Power button */
.power-btn {
    background-color: rgba(0, 0, 0, 0.40);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 18px;
    color: rgba(255, 255, 255, 0.72);
    font-size: 20px;
    padding: 11px 17px;
    transition: background-color 150ms ease,
                border-color    150ms ease,
                color           150ms ease;
}

.power-btn:hover {
    background-color: rgba(255, 255, 255, 0.10);
    border-color: rgba(255, 255, 255, 0.28);
    color: white;
}

/* Power pill popup */
.pill {
    background-color: rgba(8, 8, 8, 0.93);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 20px;
    padding: 6px;
    margin-bottom: 10px;
}

.pill-btn {
    background-color: transparent;
    border: 1px solid transparent;
    border-radius: 13px;
    color: rgba(255, 255, 255, 0.82);
    font-size: 13px;
    padding: 9px 20px;
    min-width: 170px;
    -gtk-icon-size: 0;
    transition: background-color 120ms ease,
                border-color    120ms ease,
                color           120ms ease;
}

.pill-btn:hover {
    background-color: rgba(255, 255, 255, 0.07);
    border-color: rgba(255, 255, 255, 0.11);
    color: white;
}
"""

ACTIONS = [
    ("⏻", "Shut Down", ["systemctl", "poweroff"]),
    ("", "Reboot",    ["systemctl", "reboot"]),
    ("󰍃", "Log Out",  ["hyprctl", "dispatch", "exit"]),
    ("⏾", "Sleep",    ["systemctl", "suspend"]),
]


class LockWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self._pill_open = False
        self._checking  = False
        self._dot_list  = []
        self._bg_pic    = None
        self._dot_pill  = None
        self._pw_stack  = None
        self._dot_box   = None
        self._pw_hint   = None
        self._pill_rev  = None

        self._init_layer()
        self._build_ui()

        GLib.timeout_add(1000, self._tick)
        self._tick()

    # ── Layer shell ───────────────────────────────────────────────────────

    def _init_layer(self):
        LayerShell.init_for_window(self)
        LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
        LayerShell.set_exclusive_zone(self, -1)
        LayerShell.set_keyboard_mode(self, LayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM,
                     LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(self, edge, True)

    # ── UI ────────────────────────────────────────────────────────────────

    def _build_ui(self):
        root = Gtk.Overlay()
        self.set_child(root)

        # Background layers
        bg = Gtk.Box()
        bg.add_css_class("fallback-bg")
        bg.set_hexpand(True)
        bg.set_vexpand(True)
        root.set_child(bg)

        self._bg_pic = Gtk.Picture()
        self._bg_pic.set_content_fit(Gtk.ContentFit.COVER)
        self._bg_pic.set_hexpand(True)
        self._bg_pic.set_vexpand(True)
        self._bg_pic.set_visible(False)
        self._bg_pic.set_can_target(False)
        root.add_overlay(self._bg_pic)

        dim = Gtk.Box()
        dim.add_css_class("dark-dim")
        dim.set_hexpand(True)
        dim.set_vexpand(True)
        dim.set_can_target(False)
        root.add_overlay(dim)

        # ── Center column ─────────────────────────────────────────────────

        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        center.set_halign(Gtk.Align.CENTER)
        center.set_valign(Gtk.Align.CENTER)
        root.add_overlay(center)

        self._time_lbl = Gtk.Label()
        self._time_lbl.add_css_class("time-label")
        center.append(self._time_lbl)

        self._date_lbl = Gtk.Label()
        self._date_lbl.add_css_class("date-label")
        center.append(self._date_lbl)

        # Invisible entry — lives in layout, captures all keypresses
        self._entry = Gtk.Entry()
        self._entry.set_visibility(False)
        self._entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        self._entry.add_css_class("pw-entry-hidden")
        self._entry.connect("activate", lambda _: self._submit())
        self._entry.connect("changed", self._sync_dots)
        self._entry.connect("notify::has-focus", self._on_focus_change)
        center.append(self._entry)

        # Visible dot pill — horizontal, fixed height
        self._dot_pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._dot_pill.add_css_class("pw-dot-pill")
        self._dot_pill.set_halign(Gtk.Align.CENTER)

        # Stack crossfades between "enter password" hint and password dots
        self._pw_stack = Gtk.Stack()
        self._pw_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self._pw_stack.set_transition_duration(120)
        self._pw_stack.set_halign(Gtk.Align.FILL)
        self._pw_stack.set_hexpand(True)
        self._pw_stack.set_valign(Gtk.Align.CENTER)

        self._pw_hint = Gtk.Label(label="enter password")
        self._pw_hint.add_css_class("pw-hint")
        self._pw_hint.set_halign(Gtk.Align.CENTER)
        self._pw_stack.add_named(self._pw_hint, "hint")

        self._dot_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self._dot_box.set_halign(Gtk.Align.CENTER)
        self._dot_box.set_valign(Gtk.Align.CENTER)
        self._pw_stack.add_named(self._dot_box, "dots")

        self._pw_stack.set_visible_child_name("hint")
        self._dot_pill.append(self._pw_stack)

        center.append(self._dot_pill)

        self._err_lbl = Gtk.Label()
        self._err_lbl.add_css_class("error-label")
        self._err_lbl.set_visible(False)
        center.append(self._err_lbl)

        # ── Bottom-right: pill + power button ─────────────────────────────

        br = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        br.set_halign(Gtk.Align.END)
        br.set_valign(Gtk.Align.END)
        br.set_margin_end(44)
        br.set_margin_bottom(44)
        root.add_overlay(br)

        # Revealer → smooth SLIDE_UP animation on open/close
        self._pill_rev = Gtk.Revealer()
        self._pill_rev.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP)
        self._pill_rev.set_transition_duration(360)
        self._pill_rev.set_reveal_child(False)

        pill = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        pill.add_css_class("pill")
        for icon, label, cmd in ACTIONS:
            btn = Gtk.Button(label=f"{icon}   {label}")
            btn.add_css_class("pill-btn")
            btn.set_halign(Gtk.Align.FILL)
            btn.set_focus_on_click(False)
            btn.connect("clicked", lambda _, c=cmd: self._exec(c))
            pill.append(btn)
        self._pill_rev.set_child(pill)
        br.append(self._pill_rev)

        pw_btn = Gtk.Button(label="⏻")
        pw_btn.add_css_class("power-btn")
        pw_btn.set_focus_on_click(False)  # first click triggers, no focus steal
        pw_btn.connect("clicked", self._toggle_pill)
        br.append(pw_btn)

        kc = Gtk.EventControllerKey()
        kc.connect("key-pressed", self._on_key)
        self.add_controller(kc)

        self.connect("map", self._on_map)

    # ── Map ───────────────────────────────────────────────────────────────

    def _on_map(self, *_):
        self._entry.grab_focus()
        self._start_bg()

    # ── Clock ─────────────────────────────────────────────────────────────

    def _tick(self):
        now = datetime.now()
        self._time_lbl.set_text(now.strftime("%H:%M"))
        self._date_lbl.set_text(now.strftime("%A, %B %-d"))
        return True

    # ── Wallpaper ─────────────────────────────────────────────────────────

    def _start_bg(self):
        if os.path.isfile(BLURRED_WP):
            self._apply_bg_from(BLURRED_WP)
        elif os.path.isfile(WALLPAPER):
            self._apply_bg_from(WALLPAPER)  # show instantly; replace with blur when ready
            threading.Thread(target=self._gen_bg, daemon=True).start()

    def _gen_bg(self):
        try:
            subprocess.run(
                ["convert", WALLPAPER, "-filter", "Gaussian",
                 "-blur", "0x18", "-modulate", "70", BLURRED_WP],
                check=True, timeout=10,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            GLib.idle_add(self._apply_bg_from, BLURRED_WP)
        except Exception:
            pass

    def _apply_bg_from(self, path):
        self._bg_pic.set_filename(path)
        self._bg_pic.set_visible(True)
        return False

    # ── Password dots ─────────────────────────────────────────────────────

    def _sync_dots(self, entry):
        target = len(entry.get_text())
        current = len(self._dot_list)
        for _ in range(target - current):
            self._add_dot()
        for _ in range(current - target):
            self._remove_dot()
        self._pw_stack.set_visible_child_name("dots" if self._dot_list else "hint")

    def _add_dot(self):
        dot = Gtk.Box()
        dot.add_css_class("pw-dot")
        dot.add_css_class("entering")
        self._dot_box.append(dot)
        self._dot_list.append(dot)
        # One frame later: remove entering class → CSS transition plays to full size
        GLib.timeout_add(16, lambda d=dot: (d.remove_css_class("entering"), False)[1])

    def _remove_dot(self):
        if not self._dot_list:
            return
        dot = self._dot_list.pop()
        dot.add_css_class("entering")
        GLib.timeout_add(160, lambda d=dot: (
            self._dot_box.remove(d) if d.get_parent() is self._dot_box else None,
            False)[1])

    def _on_focus_change(self, entry, _):
        if entry.has_focus():
            self._dot_pill.add_css_class("focused")
        else:
            self._dot_pill.remove_css_class("focused")

    def _shake(self):
        # Remove + re-add so animation restarts even on repeated wrong passwords
        self._dot_pill.remove_css_class("shake")
        GLib.timeout_add(10,  lambda: (self._dot_pill.add_css_class("shake"),    False)[1])
        GLib.timeout_add(360, lambda: (self._dot_pill.remove_css_class("shake"), False)[1])

    # ── Power pill ────────────────────────────────────────────────────────

    def _toggle_pill(self, *_):
        self._pill_open = not self._pill_open
        self._pill_rev.set_reveal_child(self._pill_open)

    def _exec(self, cmd):
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.get_application().quit()

    # ── Auth ──────────────────────────────────────────────────────────────

    def _submit(self):
        if self._checking:
            return
        pw = self._entry.get_text()
        if not pw:
            return
        self._checking = True
        self._entry.set_sensitive(False)
        self._err_lbl.set_visible(False)
        threading.Thread(target=self._check_pw, args=(pw,), daemon=True).start()

    def _check_pw(self, pw):
        GLib.idle_add(self._auth_done, pam.pam().authenticate(getpass.getuser(), pw))

    def _auth_done(self, ok):
        self._checking = False
        self._entry.set_sensitive(True)
        if ok:
            self.get_application().quit()
            return
        self._entry.set_text("")        # triggers _sync_dots → clears dots
        self._shake()
        self._err_lbl.set_text("incorrect password")
        self._err_lbl.set_visible(True)
        GLib.timeout_add(2500, lambda: self._err_lbl.set_visible(False) or False)
        self._entry.grab_focus()

    # ── Keys ──────────────────────────────────────────────────────────────

    def _on_key(self, _, keyval, *__):
        if keyval == Gdk.KEY_Escape and self._pill_open:
            self._pill_open = False
            self._pill_rev.set_reveal_child(False)
            return True
        return False


class LockApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="arch.lockscreen.v1")

    def do_activate(self):
        if self.get_windows():
            self.get_windows()[0].present()
            return
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER,
        )
        LockWindow(self).present()


signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
LockApp().run(sys.argv)
