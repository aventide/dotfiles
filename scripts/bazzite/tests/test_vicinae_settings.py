#!/usr/bin/python3
"""Isolated tests: no live GNOME settings, network, or service changes."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("vicinae_settings", Path(__file__).resolve().parents[1] / "vicinae-settings.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ParsingTests(unittest.TestCase):
    def test_jsonc_strings_comments_and_trailing_commas(self):
        value = module.read_jsonc('''// heading
        {"url": "https://example.com/*literal*/", /* block */
         "quoted": "a\\\"b", "literal": "x,}", "array": [1, 2,],}
        ''')
        self.assertEqual(value["url"], "https://example.com/*literal*/")
        self.assertEqual(value["quoted"], 'a"b')
        self.assertEqual(value["literal"], "x,}")
        self.assertEqual(value["array"], [1, 2])

    def test_invalid_input_rejected(self):
        for value in ('/* unfinished', '{"a": "unfinished', '[]', '{bad}'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.read_jsonc(value)

    def test_merge_preserves_other_preferences(self):
        value = {"font": {"rendering": "qt", "normal": {"weight": 500}}, "theme": {"dark": "mine"}}
        module.merge(value, {"font": {"normal": {"family": "Adwaita Sans", "size": 11}}})
        self.assertEqual(value["font"]["rendering"], "qt")
        self.assertEqual(value["font"]["normal"]["weight"], 500)
        self.assertEqual(value["theme"], {"dark": "mine"})

    def test_invalid_merge_rejected(self):
        with self.assertRaises(ValueError):
            module.merge({"font": "invalid"}, {"font": {"normal": {}}})

    def test_systemd_escaping(self):
        self.assertEqual(module.systemd_quoted('/home/my$user/100%/bin/app', executable=True), '"/home/my$$user/100%%/bin/app"')
        self.assertEqual(module.systemd_quoted('PATH=/home/my$user/bin'), '"PATH=/home/my$user/bin"')


class Settings:
    def __init__(self, values, locked=False):
        self.values = values
        self.locked = locked
        self.props = SimpleNamespace(settings_schema=SimpleNamespace(list_keys=lambda: list(values)))

    def get_strv(self, key):
        return list(self.values[key])

    def get_string(self, key):
        return self.values[key]

    def get_value(self, key):
        return SimpleNamespace(unpack=lambda: self.values[key])

    def is_writable(self, key):
        return not self.locked

    def set_strv(self, key, value):
        self.values[key] = list(value)

    def set_string(self, key, value):
        self.values[key] = value


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.source = self.home / "preferences.json"
        self.source.write_text('{"font":{"normal":{"family":"Adwaita Sans","size":11}}}')
        self.config = self.home / ".config/vicinae/settings.json"
        self.config.parent.mkdir(parents=True)
        self.config.write_text('// existing\n{"theme":{"dark":{"name":"mine"}}, "font":{"rendering":"qt"},}')
        self.original = self.config.read_text()
        self.other = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        self.schemas = {
            module.MEDIA: {"custom-keybindings": [self.other]},
            "org.gnome.shell": {"enabled-extensions": ["keep@me"], "disabled-extensions": ["leave-disabled@me"]},
            "org.freedesktop.ibus.general.hotkey": {"trigger": ["Control+space", "Alt+grave"]},
            "org.gnome.desktop.wm.keybindings": {"switch-input-source": ["<Super>space"]},
            "org.gnome.shell.keybindings": {},
        }
        self.custom = {self.other: {"name": "Other", "command": "keep-me", "binding": "<Alt>x"}}
        self.locked = False
        self.uri_defaults = {"vicinae": "previous-vicinae.desktop", "raycast": "previous-raycast.desktop", "com.raycast": ""}
        self.queries = []
        self.failed_query = False

        def new(schema):
            return Settings(self.schemas[schema], self.locked)

        def new_with_path(schema, path):
            return Settings(self.custom.setdefault(path, {"name": "", "command": "", "binding": ""}), self.locked)

        self.fake_gio = SimpleNamespace(Settings=SimpleNamespace(new=new, new_with_path=new_with_path, sync=lambda: None))

    def run_setup(self, check=False):
        args = ["vicinae-settings.py", str(self.source), "/usr/bin/true"]
        if check:
            args.append("--check")
        def run_command(command, **kwargs):
            if command[:3] == ["xdg-mime", "query", "default"]:
                # Queries must happen before new desktop entries are registered.
                self.assertFalse((self.home / ".local/share/applications/vicinae-url-handler.desktop").exists())
                self.queries.append(command[-1])
                if self.failed_query:
                    raise module.subprocess.CalledProcessError(1, command)
                return SimpleNamespace(returncode=0, stdout=self.uri_defaults[command[-1].split("/")[-1]] + "\n")
            return SimpleNamespace(returncode=1)

        with patch.object(module, "Gio", self.fake_gio), patch.object(module.Path, "home", return_value=self.home), \
             patch.dict(os.environ, {"GSETTINGS_BACKEND": "dconf", "XDG_CONFIG_HOME": str(self.home / ".config"),
                                    "XDG_DATA_HOME": str(self.home / ".local/share"), "XDG_STATE_HOME": str(self.home / ".local/state")}), \
             patch("sys.argv", args), patch.object(module.subprocess, "run", side_effect=run_command), \
             contextlib.redirect_stdout(io.StringIO()):
            module.main()

    def test_check_has_no_file_or_setting_writes(self):
        before = json.dumps(self.schemas)
        self.run_setup(check=True)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertEqual(json.dumps(self.schemas), before)
        self.assertFalse((self.home / ".local").exists())
        self.assertEqual(self.queries, [])

    def test_setup_preserves_settings_and_is_repeatable(self):
        self.run_setup()
        value = json.loads(self.config.read_text())
        self.assertEqual(value["theme"]["dark"]["name"], "mine")
        self.assertEqual(value["font"]["rendering"], "qt")
        self.assertEqual(value["font"]["normal"], {"family": "Adwaita Sans", "size": 11})
        self.assertEqual(self.schemas[module.MEDIA]["custom-keybindings"], [self.other, module.SHORTCUT_PATH])
        self.assertEqual(self.schemas["org.freedesktop.ibus.general.hotkey"]["trigger"], ["Alt+grave"])
        self.assertEqual(self.schemas["org.gnome.shell"]["enabled-extensions"], ["keep@me", module.UUID])
        self.assertEqual(self.schemas["org.gnome.shell"]["disabled-extensions"], ["leave-disabled@me"])
        self.assertEqual(self.custom[self.other]["command"], "keep-me")
        backup = self.config.with_name(self.config.name + ".before-dotfiles-vicinae")
        self.assertEqual(backup.read_text(), self.original)
        snapshot = self.home / ".local/state/dotfiles/vicinae-before.json"
        first_snapshot = snapshot.read_text()
        first_config = self.config.read_text()
        self.run_setup()
        self.assertEqual(snapshot.read_text(), first_snapshot)
        self.assertEqual(self.config.read_text(), first_config)
        self.assertEqual(backup.read_text(), self.original)
        self.assertEqual(self.schemas[module.MEDIA]["custom-keybindings"].count(module.SHORTCUT_PATH), 1)

    def test_previously_disabled_extension_is_enabled_without_touching_others(self):
        shell = self.schemas["org.gnome.shell"]
        shell["disabled-extensions"].append(module.UUID)
        self.run_setup()
        self.assertIn(module.UUID, shell["enabled-extensions"])
        self.assertEqual(shell["disabled-extensions"], ["leave-disabled@me"])
        snapshot = json.loads((self.home / ".local/state/dotfiles/vicinae-before.json").read_text())
        self.assertEqual(snapshot["disabled-extensions"], ["leave-disabled@me", module.UUID])
        self.run_setup()
        self.assertEqual(shell["enabled-extensions"].count(module.UUID), 1)
        self.assertEqual(json.loads((self.home / ".local/state/dotfiles/vicinae-before.json").read_text()), snapshot)

    def test_locked_disabled_extensions_refused_before_writes(self):
        shell = self.schemas["org.gnome.shell"]
        shell["disabled-extensions"].append(module.UUID)
        original = Settings.is_writable
        with patch.object(Settings, "is_writable", lambda setting, key: key != "disabled-extensions" and original(setting, key)):
            with self.assertRaisesRegex(ValueError, "disabled-extensions"):
                self.run_setup()
        self.assertEqual(self.config.read_text(), self.original)
        self.assertFalse((self.home / ".local").exists())

    def test_uri_defaults_saved_once_including_no_previous_handler(self):
        self.run_setup()
        snapshot = self.home / ".local/state/dotfiles/vicinae-before.json"
        self.assertEqual(json.loads(snapshot.read_text())["uri-handler-defaults"], self.uri_defaults)
        self.assertEqual(len(self.queries), 3)
        self.uri_defaults = dict.fromkeys(module.URI_SCHEMES, "vicinae-url-handler.desktop")
        self.run_setup()
        self.assertEqual(len(self.queries), 3)
        self.assertEqual(json.loads(snapshot.read_text())["uri-handler-defaults"]["raycast"], "previous-raycast.desktop")

    def test_older_snapshot_extended_without_overwriting_original_values(self):
        snapshot = self.home / ".local/state/dotfiles/vicinae-before.json"
        snapshot.parent.mkdir(parents=True)
        original = {"enabled-extensions": ["original@me"], "ibus-trigger": ["original-trigger"]}
        snapshot.write_text(json.dumps(original))
        self.run_setup()
        saved = json.loads(snapshot.read_text())
        for key, value in original.items():
            self.assertEqual(saved[key], value)
        self.assertEqual(saved["uri-handler-defaults"], self.uri_defaults)
        self.assertEqual(saved["disabled-extensions"], ["leave-disabled@me"])

    def test_failed_uri_query_refused_before_writes(self):
        self.failed_query = True
        with self.assertRaises(module.subprocess.CalledProcessError):
            self.run_setup()
        self.assertEqual(self.config.read_text(), self.original)
        self.assertFalse((self.home / ".local").exists())

    def test_conflict_refused_before_config_changes(self):
        self.custom[self.other]["binding"] = "<Ctrl>space"
        with self.assertRaisesRegex(ValueError, "another shortcut"):
            self.run_setup()
        self.assertEqual(self.config.read_text(), self.original)

    def test_locked_setting_refused_before_config_changes(self):
        self.locked = True
        with self.assertRaisesRegex(ValueError, "locked"):
            self.run_setup()
        self.assertEqual(self.config.read_text(), self.original)

    def test_symlink_refused(self):
        self.config.unlink()
        self.config.symlink_to(self.source)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.run_setup()

    def test_named_shortcut_reused(self):
        self.custom[self.other]["name"] = "Toggle Vicinae"
        self.run_setup()
        self.assertEqual(self.schemas[module.MEDIA]["custom-keybindings"], [self.other])
        self.assertEqual(self.custom[self.other]["binding"], "<Control>space")


if __name__ == "__main__":
    unittest.main()
