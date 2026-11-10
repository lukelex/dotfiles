"""GTK presentation for the XDPH picker; capture and portal transport stay separate."""

from pathlib import Path
from types import SimpleNamespace

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk, Pango


def workspace_order(name, current):
    try:
        return (name != current, 0, int(name))
    except ValueError:
        return (name != current, 1, name)


class Picker:
    def __init__(self, app, windows, outputs, clients, monitors, executor, captures, api, fallback):
        self.app, self.api, self.executor, self.captures = app, api, executor, captures
        self.sources, self.groups = [], {}
        self.selected = self.detail_source = None
        self.armed = self.validating = self.polling = False
        self.pending = 0
        self.columns = 3
        self.kind = "window"
        self.closed = False
        focused = next((m for m in monitors.values() if m.get("focused")), next(iter(monitors.values()), {}))
        self.current_workspace = focused.get("activeWorkspace", {}).get("name", "")
        scale = focused.get("scale", 1) or 1
        width, height = focused.get("width", 1024), focused.get("height", 960)
        if focused.get("transform", 0) % 2:
            width, height = height, width
        self.window = Gtk.ApplicationWindow(application=app, title="Select what to share")
        self.window.add_css_class("share-picker")
        self.window.set_default_size(min(760, max(320, int(width / scale) - 64)), min(795, max(320, int(height / scale) - 96)))
        self.window.connect("close-request", lambda *_: self.quit() or False)
        self.window.connect("notify::focus-widget", lambda *_: setattr(self, "armed", False))
        css = Gtk.CssProvider()
        css.load_from_path(str(Path(__file__).with_name("share-picker.css")))
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        for side in ("top", "bottom", "start", "end"):
            getattr(self.root, "set_margin_" + side)(18)
        self.window.set_child(self.root)
        self.root.append(self.label("Select what to share", "heading"))
        self.root.append(self.label("Choose a source, then Share. Your selection stays private until confirmed.", "muted", wrap=True))
        self.pages = Gtk.Stack(vexpand=True)
        self.root.append(self.pages)
        browse = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.pages.add_named(browse, "browse")
        controls = Gtk.Box(spacing=8)
        browse.append(controls)
        self.windows_tab = Gtk.ToggleButton(label="Windows", active=True)
        self.screens_tab = Gtk.ToggleButton(label="Screens")
        self.screens_tab.set_group(self.windows_tab)
        for tab, kind in ((self.windows_tab, "window"), (self.screens_tab, "screen")):
            tab.connect("toggled", lambda button, k=kind: self.change_kind(k) if button.get_active() else None)
            controls.append(tab)
        spacer = Gtk.Box(hexpand=True)
        controls.append(spacer)
        self.refresh = Gtk.Button(label="Refresh", tooltip_text="Refresh snapshots")
        self.refresh.connect("clicked", lambda *_: self.refresh_previews())
        controls.append(self.refresh)
        self.search = Gtk.SearchEntry(placeholder_text="Search windows and applications…", hexpand=True)
        self.search.connect("changed", lambda *_: self.filter_sources())
        # Stop-search is GTK's Escape action when the entry owns focus.
        self.search.connect("stop-search", lambda *_: self.escape())
        browse.append(self.search)
        self.scroll = Gtk.ScrolledWindow(vexpand=True, hscrollbar_policy=Gtk.PolicyType.NEVER)
        browse.append(self.scroll)
        self.sections = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        self.scroll.set_child(self.sections)
        self.empty = self.label("No matching windows. Try a different search.", "muted", wrap=True)
        browse.append(self.empty)
        self.notice = self.label("New windows require reopening the share dialog.", "muted", wrap=True)
        self.root.append(self.notice)

        details = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.pages.add_named(details, "detail")
        back = Gtk.Button(label="← Back to sources", halign=Gtk.Align.START)
        back.connect("clicked", lambda *_: self.close_detail())
        details.append(back)
        self.detail_title = self.label("", wrap=True)
        self.detail_title.set_selectable(True)
        details.append(self.detail_title)
        self.detail_picture = Gtk.Picture(vexpand=True, content_fit=Gtk.ContentFit.CONTAIN)
        details.append(self.detail_picture)
        self.detail_status = self.label("", "muted")
        details.append(self.detail_status)

        footer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        footer.add_css_class("footer")
        self.root.append(footer)
        self.selection_label = Gtk.Label(label="No source selected", xalign=0, ellipsize=Pango.EllipsizeMode.END, hexpand=True)
        footer.append(self.selection_label)
        actions = Gtk.Box(spacing=8)
        footer.append(actions)
        self.expand = Gtk.Button(label="Expand preview", sensitive=False)
        self.expand.connect("clicked", lambda *_: self.open_detail())
        actions.append(self.expand)
        actions.append(Gtk.Box(hexpand=True))
        cancel = Gtk.Button(label="Cancel")
        cancel.connect("clicked", lambda *_: self.quit())
        actions.append(cancel)
        self.share = Gtk.Button(label="Share", sensitive=False)
        self.share.add_css_class("primary")
        self.share.connect("clicked", lambda *_: self.confirm())
        actions.append(self.share)
        standard = Gtk.Button(label="Use standard picker", halign=Gtk.Align.START)
        standard.add_css_class("quiet")
        standard.connect("clicked", lambda *_: fallback() or self.quit())
        footer.append(standard)

        def rank(window):
            client = clients.get(window["address"], {})
            workspace = client.get("workspace", {}).get("name", "Unknown")
            history = client.get("focusHistoryID", -1)
            return (workspace_order(workspace, self.current_workspace), history if history >= 0 else 10**9)
        for window in sorted(windows, key=rank):
            client = clients.get(window["address"], {})
            self.add_source("window", window["id"], client.get("title") or window["title"] or window["class"],
                            window["class"], client.get("workspace", {}).get("name", "Unknown"),
                            api.window_capture_args(window, clients), window,
                            api.window_available(window, clients))
        for name in outputs:
            monitor = monitors.get(name, {})
            self.add_source("screen", name, monitor.get("description") or name, name, "Screens", ("-o", name), None, name in monitors)
        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self.key_pressed)
        self.window.add_controller(keys)
        self.filter_sources()

    @staticmethod
    def label(text, css=None, wrap=False):
        label = Gtk.Label(label=text, xalign=0, wrap=wrap)
        if css:
            label.add_css_class(css)
        return label

    def group(self, kind, workspace):
        key = (kind, workspace)
        if key not in self.groups:
            section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            title = "Screens" if kind == "screen" else f"Workspace {workspace}" + (" · Current" if workspace == self.current_workspace else "")
            section.append(self.label(title, "section-heading"))
            grid = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, homogeneous=True,
                               min_children_per_line=self.columns, max_children_per_line=self.columns,
                               column_spacing=12, row_spacing=12)
            grid.set_activate_on_single_click(False)
            section.append(grid)
            self.sections.append(section)
            self.groups[key] = (section, grid)
        return self.groups[key][1]

    def add_source(self, kind, identifier, title, app_name, workspace, args, window, valid):
        source = SimpleNamespace(kind=kind, identifier=identifier, title=title, app_name=app_name,
                                 workspace=workspace, args=args, window=window, valid=valid, version=0,
                                 texture=None, visible=False, rank=len(self.sources))
        source.button = Gtk.Button(sensitive=valid, hexpand=True, tooltip_text=title)
        source.button.add_css_class("source-card")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        # A one-column layout can shrink on a small display; normal cards are ~220px.
        box.set_size_request(190, -1)
        source.button.set_child(box)
        icon_name = app_name.lower() if kind == "window" else "video-display"
        if not Gtk.IconTheme.get_for_display(Gdk.Display.get_default()).has_icon(icon_name):
            icon_name = "application-x-executable"
        source.preview = Gtk.Stack()
        source.preview.set_size_request(-1, 130)
        source.preview.add_css_class("preview")
        placeholder = Gtk.Image.new_from_icon_name(icon_name)
        placeholder.set_pixel_size(48)
        source.preview.add_named(placeholder, "icon")
        source.picture = Gtk.Picture(content_fit=Gtk.ContentFit.CONTAIN)
        source.preview.add_named(source.picture, "snapshot")
        box.append(source.preview)
        app_row = Gtk.Box(spacing=6)
        small_icon = Gtk.Image.new_from_icon_name(icon_name)
        small_icon.set_pixel_size(18)
        app_row.append(small_icon)
        source.app_label = Gtk.Label(label=app_name, xalign=0, ellipsize=Pango.EllipsizeMode.END, max_width_chars=22)
        app_row.append(source.app_label)
        box.append(app_row)
        source.title_label = Gtk.Label(label=title, xalign=0, yalign=0, wrap=True,
                                       wrap_mode=Pango.WrapMode.WORD_CHAR, lines=2,
                                       ellipsize=Pango.EllipsizeMode.END, max_width_chars=28)
        source.title_label.set_size_request(-1, 36)
        box.append(source.title_label)
        source.status = self.label("Loading preview…" if args else "Preview unavailable", "muted")
        box.append(source.status)
        source.button.connect("clicked", lambda *_: self.select(source))
        self.group(kind, workspace).append(source.button)
        source.cell = source.button.get_parent()
        source.cell.set_focusable(False)
        self.sources.append(source)

    def present(self):
        self.window.present()
        self.window.add_tick_callback(self.resize_grid)
        self.search.grab_focus()
        self.refresh_previews()
        self.timer = GLib.timeout_add_seconds(2, self.poll_sources)

    def resize_grid(self, *_):
        width = self.scroll.get_width()
        columns = max(1, min(width // 224, (width + 299) // 300))
        if columns != self.columns:
            self.columns = columns
            for _section, grid in self.groups.values():
                grid.set_min_children_per_line(columns)
                grid.set_max_children_per_line(columns)
        return not self.closed

    def quit(self):
        self.closed = True
        self.app.quit()

    def change_kind(self, kind):
        self.kind = kind
        self.clear_selection()
        self.search.set_placeholder_text("Search windows and applications…" if kind == "window" else "Search screens…")
        self.filter_sources()

    def filter_sources(self):
        self.armed = False
        query = self.search.get_text().casefold().split()
        for source in self.sources:
            haystack = f"{source.title} {source.app_name} {source.workspace}".casefold()
            source.visible = source.valid and source.kind == self.kind and all(term in haystack for term in query)
            source.cell.set_visible(source.visible)
        for key, (section, _grid) in self.groups.items():
            section.set_visible(any(s.visible and (s.kind, s.workspace) == key for s in self.sources))
        self.empty.set_visible(not any(s.visible for s in self.sources))
        self.empty.set_label("No matching sources. Try a different search." if query else "No sources available here. Try the other tab or reopen sharing.")
        if self.selected and not self.selected.visible:
            self.clear_selection("Selection cleared: the source is no longer in this view.")

    def clear_selection(self, message=None):
        if self.selected:
            self.selected.button.remove_css_class("selected")
        self.selected = None
        self.armed = False
        self.share.set_sensitive(False)
        self.expand.set_sensitive(False)
        self.selection_label.set_label("No source selected")
        self.selection_label.set_tooltip_text(None)
        if self.detail_source:
            self.close_detail()
        if message:
            self.notice.set_label(message)

    def select(self, source):
        if not source.valid or not source.visible or self.validating:
            return
        self.clear_selection()
        self.selected = source
        source.button.add_css_class("selected")
        source.button.grab_focus()
        self.armed = True
        self.selection_label.set_label(f"Selected: {source.title}")
        self.selection_label.set_tooltip_text(source.title)
        self.share.set_sensitive(True)
        self.expand.set_sensitive(True)

    def confirm(self):
        source = self.selected
        if not source or not source.valid or not source.visible or self.validating:
            return
        self.validating = True
        self.share.set_sensitive(False)
        def verify():
            if source.window:
                current = {int(c["address"], 16): c for c in self.api.hyprctl("clients")}
                return self.api.window_available(source.window, current)
            return source.identifier in {m["name"] for m in self.api.hyprctl("monitors")}
        def verified(future):
            self.validating = False
            try:
                valid = future.result()
            except Exception:
                self.notice.set_label("Cannot verify this source. Retry or use the standard picker.")
                self.share.set_sensitive(self.selected is not None)
                return
            if source is not self.selected or not source.visible:
                self.share.set_sensitive(self.selected is not None)
                return
            if not valid:
                source.valid = False
                self.clear_selection("Selection cleared: the source closed or disconnected.")
                self.filter_sources()
                return
            print(self.api.portal_selection(source.kind, source.identifier), flush=True)
            self.quit()
        self.submit(verify, verified)

    def submit(self, work, callback):
        future = self.executor.submit(work)
        def deliver():
            if not self.closed and not self.captures.stopped.is_set():
                callback(future)
            return False
        future.add_done_callback(lambda _: GLib.idle_add(deliver) if not self.captures.stopped.is_set() else None)

    def capture(self, source, expanded=False):
        if not source.args or not source.valid:
            source.status.set_label("Preview unavailable")
            if expanded:
                self.detail_status.set_label("Preview unavailable. You can still share this source.")
            return
        source.version += 1
        version = source.version
        self.pending += 1
        self.refresh.set_sensitive(False)
        source.status.set_label("Loading preview…")
        def deliver(future):
            self.pending -= 1
            self.refresh.set_sensitive(self.pending == 0)
            if source.version != version or not source.valid:
                return
            try:
                data = future.result()
                texture = Gdk.Texture.new_from_bytes(GLib.Bytes.new(data)) if data else None
            except Exception:
                self.api.log("preview-unavailable")
                texture = None
            source.texture = texture
            source.picture.set_paintable(texture)
            source.preview.set_visible_child_name("snapshot" if texture else "icon")
            source.status.set_label("Snapshot" if texture else "Preview unavailable")
            if self.detail_source is source:
                self.detail_picture.set_paintable(texture)
                self.detail_status.set_label("Fresh snapshot · Esc to go back" if texture else "Preview unavailable. You can still share this source.")
        self.submit(lambda: self.api.thumbnail(*source.args, stopped=self.captures.stopped,
                                              captures=self.captures, scale=0.5 if expanded else 0.25), deliver)

    def refresh_previews(self):
        if self.pending:
            return
        for source in self.sources:
            if source.valid:
                self.capture(source)

    def open_detail(self):
        if not self.selected:
            return
        self.detail_source = self.selected
        self.detail_title.set_label(self.selected.title)
        self.detail_picture.set_paintable(self.selected.texture)
        self.detail_status.set_label("Refreshing preview…")
        self.pages.set_visible_child_name("detail")
        self.expand.set_sensitive(False)
        self.capture(self.selected, expanded=True)

    def close_detail(self):
        self.detail_source = None
        self.detail_picture.set_paintable(None)
        self.pages.set_visible_child_name("browse")
        self.expand.set_sensitive(self.selected is not None)
        if self.selected:
            self.selected.button.grab_focus()

    def escape(self):
        if self.detail_source:
            self.close_detail()
        elif self.search.get_text():
            self.search.set_text("")
            self.filter_sources()
        else:
            self.quit()

    def focused_source(self):
        widget = self.window.get_focus()
        while widget:
            for source in self.sources:
                if source.button is widget:
                    return source
            widget = widget.get_parent()
        return None

    def visible_sources(self):
        return sorted((s for s in self.sources if s.visible),
                      key=lambda s: (workspace_order(s.workspace, self.current_workspace), s.rank))

    def neighbor(self, source, keyval):
        visible = self.visible_sources()
        if not source:
            return visible[0]
        ok, origin = source.button.compute_bounds(self.sections)
        vertical = keyval in (Gdk.KEY_Up, Gdk.KEY_Down)
        forward = keyval in (Gdk.KEY_Right, Gdk.KEY_Down)
        candidates = []
        if ok:
            for other in visible:
                valid, bounds = other.button.compute_bounds(self.sections)
                if not valid or other is source:
                    continue
                dx = bounds.get_x() - origin.get_x()
                dy = bounds.get_y() - origin.get_y()
                distance, cross = (dy, dx) if vertical else (dx, dy)
                if distance * (1 if forward else -1) > 1 and (vertical or abs(cross) < 2):
                    candidates.append((abs(distance), abs(cross), other))
        if candidates:
            return min(candidates, key=lambda entry: entry[:2])[2]
        return source

    def key_pressed(self, _controller, keyval, _keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.escape()
            return True
        if self.detail_source:
            return False
        visible = self.visible_sources()
        focused = self.focused_source()
        focus = self.window.get_focus()
        editing = focus is self.search or (focus and focus.is_ancestor(self.search))
        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            # Real buttons outside the grid retain their normal keyboard activation.
            if not focused and not editing:
                return False
            target = focused or (visible[0] if visible else None)
            if target and target is self.selected and self.armed:
                self.confirm()
            elif target:
                self.select(target)
            return True
        if keyval in (Gdk.KEY_Left, Gdk.KEY_Right, Gdk.KEY_Up, Gdk.KEY_Down) and visible:
            # Left/right still edit text when the search entry owns focus.
            if not focused and keyval in (Gdk.KEY_Left, Gdk.KEY_Right):
                return False
            target = self.neighbor(focused, keyval)
            target.button.grab_focus()
            self.armed = False
            return True
        modifiers = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.SUPER_MASK
        if not state & modifiers:
            char = Gdk.keyval_to_unicode(keyval)
            if char and chr(char).isprintable() and not editing:
                self.search.grab_focus()
                self.search.set_text(self.search.get_text() + chr(char))
                self.search.set_position(-1)
                self.filter_sources()
                return True
        return False

    def poll_sources(self):
        if self.closed or self.captures.stopped.is_set():
            return False
        if self.polling:
            return True
        self.polling = True
        def read():
            return ({int(c["address"], 16): c for c in self.api.hyprctl("clients")},
                    {m["name"] for m in self.api.hyprctl("monitors")})
        def update(future):
            self.polling = False
            try:
                clients, screens = future.result()
            except Exception:
                self.notice.set_label("Hyprland unavailable. Retry or use the standard picker.")
                return
            changed = False
            for source in self.sources:
                valid = self.api.window_available(source.window, clients) if source.window else source.identifier in screens
                # Once gone, never resurrect a handle from this portal snapshot.
                if source.valid and not valid:
                    source.valid = False
                    source.button.set_sensitive(False)
                    changed = True
                    if source is self.selected:
                        self.clear_selection("Selection cleared: the source closed or disconnected.")
                if source.valid and source.window:
                    client = clients[source.window["address"]]
                    title = client.get("title") or source.app_name
                    workspace = client.get("workspace", {}).get("name", "Unknown")
                    if title != source.title:
                        source.title = title
                        source.title_label.set_label(title)
                        source.button.set_tooltip_text(title)
                        changed = True
                    if workspace != source.workspace:
                        # Moving workspace changes membership, not the recent-focus order.
                        old_grid = source.cell.get_parent()
                        source.cell.set_child(None)
                        old_grid.remove(source.cell)
                        source.workspace = workspace
                        source.rank = max(s.rank for s in self.sources) + 1
                        self.group(source.kind, workspace).append(source.button)
                        source.cell = source.button.get_parent()
                        source.cell.set_focusable(False)
                        previous = None
                        keys = sorted(self.groups, key=lambda key: (key[0] == "screen", workspace_order(key[1], self.current_workspace)))
                        for key in keys:
                            section = self.groups[key][0]
                            self.sections.reorder_child_after(section, previous)
                            previous = section
                        changed = True
                    if source is self.selected:
                        self.selection_label.set_label(f"Selected: {title}")
                        self.selection_label.set_tooltip_text(title)
                    if source is self.detail_source:
                        self.detail_title.set_label(title)
            if changed:
                self.filter_sources()
        self.submit(read, update)
        return True
