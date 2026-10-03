#!/usr/bin/python3
"""Merge Vicinae preferences and register its GNOME shortcut without a dconf dump."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from gi.repository import Gio

UUID = "vicinae@dagimg-dot"
MEDIA = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM = MEDIA + ".custom-keybinding"
SHORTCUT_PATH = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/"
URI_SCHEMES = ("vicinae", "raycast", "com.raycast")


def read_jsonc(text):
    """Remove JSONC comments/trailing commas, without altering quoted strings."""
    result = []
    i = 0
    while i < len(text):
        if text[i] == '"':
            start = i
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            else:
                raise ValueError("Unterminated JSON string")
            result.append(text[start:i])
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
            result.append(" ")
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise ValueError("Unterminated JSON comment")
            result.append(" ")
            i = end + 2
        else:
            result.append(text[i])
            i += 1
    text = "".join(result)
    result = []
    i = 0
    quoted = False
    while i < len(text):
        char = text[i]
        if quoted and char == "\\":
            result.append(text[i:i + 2])
            i += 2
            continue
        if char == '"':
            quoted = not quoted
        if char == "," and not quoted:
            remaining = text[i + 1:].lstrip()
            if remaining.startswith(("}", "]")):
                i += 1
                continue
        result.append(char)
        i += 1
    data = json.loads("".join(result))
    if not isinstance(data, dict):
        raise ValueError("Expected a configuration object")
    return data


def merge(target, updates):
    for key, value in updates.items():
        if isinstance(value, dict):
            if key not in target:
                target[key] = {}
            if not isinstance(target[key], dict):
                raise ValueError(f"Existing {key} preference is not an object")
            merge(target[key], value)
        else:
            target[key] = value


def write_file(path, content, backup=True):
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink: {path}")
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    saved = path.with_name(path.name + ".before-dotfiles-vicinae")
    if backup and path.exists() and not saved.exists():
        shutil.copy2(path, saved)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".dotfiles-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def control_space(binding):
    return binding.lower() in ("<control>space", "<ctrl>space", "<primary>space", "control+space")


def quoted(value):
    # Desktop Exec (also parsed by GNOME's custom-shortcut launcher).
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%").replace("$", "\\$").replace("`", "\\`") + '"'


def systemd_quoted(value, executable=False):
    value = str(value).replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%")
    # Environment= does not expand $, while ExecStart= does.
    if executable:
        value = value.replace("$", "$$")
    return '"' + value + '"'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("preferences", type=Path)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if os.geteuid() == 0 or os.environ.get("GSETTINGS_BACKEND") != "dconf":
        raise ValueError("Run as the desktop user with GSETTINGS_BACKEND=dconf")
    home = Path.home()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    state_home = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
    config = config_home / "vicinae/settings.json"
    preferences = read_jsonc(args.preferences.read_text())
    settings = read_jsonc(config.read_text()) if config.exists() else {}
    merge(settings, preferences)
    config_text = json.dumps(settings, indent=2) + "\n"
    binary = args.binary.absolute()
    if not os.access(binary, os.X_OK):
        raise ValueError(f"Not executable: {binary}")

    media = Gio.Settings.new(MEDIA)
    paths = media.get_strv("custom-keybindings")
    shortcut_path = SHORTCUT_PATH
    for path in paths:
        existing = Gio.Settings.new_with_path(CUSTOM, path)
        if existing.get_string("name") == "Toggle Vicinae":
            shortcut_path = path
            break
    shortcut = Gio.Settings.new_with_path(CUSTOM, shortcut_path)
    if shortcut.get_string("name") not in ("", "Toggle Vicinae"):
        raise ValueError("The Vicinae shortcut path belongs to another shortcut")
    for path in paths:
        if path != shortcut_path:
            existing = Gio.Settings.new_with_path(CUSTOM, path)
            if control_space(existing.get_string("binding")):
                raise ValueError(f"Ctrl+Space belongs to another shortcut: {existing.get_string('name')}")
    for schema in ("org.gnome.desktop.wm.keybindings", "org.gnome.shell.keybindings"):
        bindings = Gio.Settings.new(schema)
        for key in bindings.props.settings_schema.list_keys():
            value = bindings.get_value(key).unpack()
            if isinstance(value, list) and any(control_space(item) for item in value):
                raise ValueError(f"Ctrl+Space conflicts with {schema} {key}")
    shell = Gio.Settings.new("org.gnome.shell")
    ibus = Gio.Settings.new("org.freedesktop.ibus.general.hotkey")
    enabled = shell.get_strv("enabled-extensions")
    disabled = shell.get_strv("disabled-extensions")
    trigger = ibus.get_strv("trigger")
    targets = [(media, "custom-keybindings"), (shell, "enabled-extensions"), (ibus, "trigger")]
    if UUID in disabled:
        targets.append((shell, "disabled-extensions"))
    targets += [(shortcut, key) for key in ("name", "command", "binding")]
    for target, key in targets:
        if not target.is_writable(key):
            raise ValueError(f"GNOME setting is locked: {key}")

    dropin = config_home / "systemd/user/vicinae.service.d/dotfiles.conf"
    unit = config_home / "systemd/user/vicinae.service"
    applications = data_home / "applications"
    for path in (config, dropin, unit, applications / "vicinae.desktop", applications / "vicinae-url-handler.desktop"):
        if path.is_symlink():
            raise ValueError(f"Refusing to overwrite a symlink: {path}")
    print(f"Vicinae: {binary}; font: Adwaita Sans 11; shortcut: <Control>space")
    if args.check:
        print("Preferences parse successfully; unrelated settings and shortcuts will be retained.")
        return

    # Capture URI defaults before writing desktop entries: registering a new
    # handler can itself change which application a query resolves to.
    # Older snapshots keep their original values and gain only missing fields.
    snapshot = state_home / "dotfiles/vicinae-before.json"
    before = json.loads(snapshot.read_text()) if snapshot.exists() else {}
    if not isinstance(before, dict):
        raise ValueError(f"Expected an object in snapshot: {snapshot}")
    if "uri-handler-defaults" not in before:
        before["uri-handler-defaults"] = {
            scheme: subprocess.run(
                ["xdg-mime", "query", "default", "x-scheme-handler/" + scheme],
                check=True, capture_output=True, text=True,
            ).stdout.strip()
            for scheme in URI_SCHEMES
        }
    current = {
        "custom-keybindings": paths,
        "shortcut-path": shortcut_path,
        "shortcut": {key: shortcut.get_string(key) for key in ("name", "command", "binding")},
        "ibus-trigger": trigger,
        "enabled-extensions": enabled,
        "disabled-extensions": disabled,
    }
    for key, value in current.items():
        before.setdefault(key, value)
    # User-only snapshot: never copied into the repository.
    write_file(snapshot, json.dumps(before, indent=2) + "\n", backup=False)
    write_file(config, config_text)
    quoted_binary = quoted(binary)
    service_path = [str(home / ".local/bin")]
    for prefix in (Path("/home/linuxbrew/.linuxbrew/bin"), Path("/home/linuxbrew/.linuxbrew/sbin")):
        if prefix.is_dir():
            service_path.append(str(prefix))
    service_path.extend(("/usr/local/sbin", "/usr/local/bin", "/usr/bin"))
    service_binary = systemd_quoted(binary, executable=True)
    write_file(dropin, '[Service]\nExecStart=\nExecStart=' + service_binary + ' server --replace\nEnvironment=' + systemd_quoted('PATH=' + ':'.join(service_path)) + '\n')
    if subprocess.run(["systemctl", "--user", "cat", "vicinae.service"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        write_file(unit, "[Unit]\nDescription=Vicinae Launcher Daemon\nAfter=graphical-session-pre.target\nPartOf=graphical-session.target\n\n[Service]\nType=simple\nExecStart=" + service_binary + " server --replace\nRestart=on-failure\n\n[Install]\nWantedBy=graphical-session.target\n")
    write_file(applications / "vicinae.desktop", '[Desktop Entry]\nType=Application\nName=Vicinae\nExec=' + quoted_binary + ' open\nIcon=vicinae\nTerminal=false\nCategories=Utility;\n')
    write_file(applications / "vicinae-url-handler.desktop", '[Desktop Entry]\nType=Application\nName=Vicinae Deeplink Handler\nExec=' + quoted_binary + ' %u\nIcon=vicinae\nTerminal=false\nNoDisplay=true\nMimeType=x-scheme-handler/vicinae;x-scheme-handler/raycast;x-scheme-handler/com.raycast;\n')
    shortcut.set_string("name", "Toggle Vicinae")
    shortcut.set_string("command", quoted_binary + " toggle")
    shortcut.set_string("binding", "<Control>space")
    if shortcut_path not in paths:
        media.set_strv("custom-keybindings", paths + [shortcut_path])
    ibus.set_strv("trigger", [item for item in trigger if not control_space(item)])
    if UUID not in enabled:
        shell.set_strv("enabled-extensions", enabled + [UUID])
    if UUID in disabled:
        shell.set_strv("disabled-extensions", [item for item in disabled if item != UUID])
    extension_schemas = data_home / "gnome-shell/extensions" / UUID / "schemas"
    if not extension_schemas.is_dir():
        extension_schemas = Path("/usr/share/gnome-shell/extensions") / UUID / "schemas"
    if extension_schemas.is_dir():
        source = Gio.SettingsSchemaSource.new_from_directory(str(extension_schemas), Gio.SettingsSchemaSource.get_default(), False)
        schema = source.lookup("org.gnome.shell.extensions.vicinae", False)
        if schema and schema.has_key("blocked-applications"):
            extension = Gio.Settings.new_full(schema, None, None)
            blocked = extension.get_strv("blocked-applications")
            if "Bitwarden" not in blocked:
                extension.set_strv("blocked-applications", blocked + ["Bitwarden"])
    Gio.Settings.sync()
    print(f"Applied. Original shortcut values retained at {snapshot}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Vicinae setup: {error}")
