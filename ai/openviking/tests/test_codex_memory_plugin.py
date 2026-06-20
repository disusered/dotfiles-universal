import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
OPENVIKING_ROOT = REPO_ROOT / "ai" / "openviking"
PLUGIN_ROOT = OPENVIKING_ROOT / "codex-memory-plugin"


class CodexMemoryPluginTests(unittest.TestCase):
    def test_vendored_codex_memory_plugin_assets_exist(self):
        expected = [
            PLUGIN_ROOT / ".codex-plugin" / "plugin.json",
            PLUGIN_ROOT / ".mcp.json",
            PLUGIN_ROOT / "hooks" / "hooks.json",
            PLUGIN_ROOT / "scripts" / "auto-recall.mjs",
            PLUGIN_ROOT / "scripts" / "config.mjs",
            PLUGIN_ROOT / "scripts" / "scope-config.mjs",
            PLUGIN_ROOT / "setup-helper" / "wrapper.sh",
        ]

        missing = [str(path.relative_to(REPO_ROOT)) for path in expected if not path.exists()]

        self.assertEqual([], missing)

    def test_scope_config_resolves_xbol_only(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        output = subprocess.check_output(
            [
                "node",
                str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                "--cwd",
                "/home/carlos/Development/XBOL/xbol-api-admin",
                "--json",
            ],
            cwd=REPO_ROOT,
            text=True,
        )

        config = json.loads(output)

        self.assertEqual(
            [
                {"account": "xbol", "user": "carlos", "agentId": "xbol"},
            ],
            config["lookupScopes"],
        )
        self.assertEqual({"account": "xbol", "user": "carlos", "agentId": "xbol"}, config["writeScope"])

    def test_scope_config_resolves_dotfiles_only(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        output = subprocess.check_output(
            [
                "node",
                str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                "--cwd",
                "/home/carlos/.dotfiles",
                "--json",
            ],
            cwd=REPO_ROOT,
            text=True,
        )

        config = json.loads(output)

        self.assertEqual(
            [{"account": "dotfiles", "user": "carlos", "agentId": "dotfiles"}],
            config["lookupScopes"],
        )
        self.assertEqual(
            {"account": "dotfiles", "user": "carlos", "agentId": "dotfiles"},
            config["writeScope"],
        )

    def test_scope_config_resolves_herding_cats_to_legacy_local_dev_only(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        output = subprocess.check_output(
            [
                "node",
                str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                "--cwd",
                "/home/carlos/Development/ME/herding-cats/utilities/cfg",
                "--json",
            ],
            cwd=REPO_ROOT,
            text=True,
        )

        config = json.loads(output)

        self.assertEqual("herding-cats", config["activeScope"])
        self.assertEqual(
            [{"account": "local-dev", "user": "carlos", "agentId": "local-dev"}],
            config["lookupScopes"],
        )
        self.assertEqual(
            {"account": "local-dev", "user": "carlos", "agentId": "local-dev"},
            config["writeScope"],
        )

    def test_scope_config_default_is_general_not_legacy_local_dev(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        output = subprocess.check_output(
            [
                "node",
                str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                "--cwd",
                "/home/carlos/Development/ME/unmapped-project",
                "--json",
            ],
            cwd=REPO_ROOT,
            text=True,
        )

        config = json.loads(output)

        self.assertEqual("general", config["activeScope"])
        self.assertEqual(
            [{"account": "general", "user": "carlos", "agentId": "general"}],
            config["lookupScopes"],
        )
        self.assertEqual(
            {"account": "general", "user": "carlos", "agentId": "general"},
            config["writeScope"],
        )

    def test_scope_config_honors_scope_level_fallback_disable(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        with tempfile.TemporaryDirectory() as tmp:
            scope_map = Path(tmp) / "scope-map.json"
            scope_map.write_text(
                json.dumps(
                    {
                        "defaultScope": {
                            "name": "general",
                            "account": "local-dev",
                            "user": "carlos",
                            "agentId": "local-dev",
                        },
                        "generalFallback": True,
                        "scopes": [
                            {
                                "name": "isolated",
                                "account": "isolated",
                                "user": "carlos",
                                "agentId": "isolated",
                                "generalFallback": False,
                                "paths": ["/tmp/isolated-project"],
                            }
                        ],
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            output = subprocess.check_output(
                [
                    "node",
                    str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                    "--cwd",
                    "/tmp/isolated-project/subdir",
                    "--map",
                    str(scope_map),
                    "--json",
                ],
                cwd=REPO_ROOT,
                text=True,
            )

        config = json.loads(output)

        self.assertEqual(
            [{"account": "isolated", "user": "carlos", "agentId": "isolated"}],
            config["lookupScopes"],
        )

    def test_scope_config_resolves_jeu_analysis_then_general(self):
        self.assertTrue((PLUGIN_ROOT / "scripts" / "scope-config.mjs").exists())

        output = subprocess.check_output(
            [
                "node",
                str(PLUGIN_ROOT / "scripts" / "scope-config.mjs"),
                "--cwd",
                "/home/carlos/Development/ME/MAGIC/jeu_analysis",
                "--json",
            ],
            cwd=REPO_ROOT,
            text=True,
        )

        config = json.loads(output)

        self.assertEqual(
            [
                {"account": "jeu_analysis", "user": "carlos", "agentId": "jeu_analysis"},
                {"account": "general", "user": "carlos", "agentId": "general"},
            ],
            config["lookupScopes"],
        )
        self.assertEqual(
            {"account": "jeu_analysis", "user": "carlos", "agentId": "jeu_analysis"},
            config["writeScope"],
        )
        self.assertEqual(["viking://resources/jeu_analysis"], config["resourceUris"])

    def test_render_cache_targets_local_unauthenticated_openviking(self):
        self.assertTrue(PLUGIN_ROOT.exists())
        self.assertTrue((OPENVIKING_ROOT / "scripts" / "openviking-codex-plugin-render-cache").exists())

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            cache_dir = tmp_path / "codex" / "plugins" / "cache" / "openviking-plugins-local" / "openviking-memory" / "0.5.0"
            shutil.copytree(PLUGIN_ROOT, cache_dir)

            ovcli_conf = tmp_path / "ovcli.conf"
            ovcli_conf.write_text(
                json.dumps(
                    {
                        "url": "http://127.0.0.1:1933",
                        "account": "local-dev",
                        "user": "carlos",
                        "agent_id": "local-dev",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            env = os.environ.copy()
            env["OPENVIKING_PLUGIN_CACHE_DIR"] = str(cache_dir)
            env["OPENVIKING_CLI_CONFIG_FILE"] = str(ovcli_conf)

            subprocess.check_call(
                [str(OPENVIKING_ROOT / "scripts" / "openviking-codex-plugin-render-cache")],
                cwd=REPO_ROOT,
                env=env,
            )

            mcp_config = json.loads((cache_dir / ".mcp.json").read_text(encoding="utf-8"))
            server = mcp_config["mcpServers"]["openviking-memory"]
            hooks_config = json.loads((cache_dir / "hooks" / "hooks.json").read_text(encoding="utf-8"))

            self.assertEqual("http://127.0.0.1:1933/mcp", server["url"])
            self.assertNotIn("bearer_token_env_var", server)
            self.assertEqual(
                {
                    "X-OpenViking-Account": "OPENVIKING_ACCOUNT",
                    "X-OpenViking-User": "OPENVIKING_USER",
                    "X-OpenViking-Agent": "OPENVIKING_AGENT_ID",
                },
                server["env_http_headers"],
            )
            rendered_commands = [
                hook["command"]
                for event_hooks in hooks_config["hooks"].values()
                for matcher in event_hooks
                for hook in matcher["hooks"]
            ]
            self.assertTrue(all(str(cache_dir) in command for command in rendered_commands))
            self.assertTrue(all("__OPENVIKING_PLUGIN_ROOT__" not in command for command in rendered_commands))

    def test_install_dereferences_symlinked_plugin_source_before_rendering(self):
        install_script = OPENVIKING_ROOT / "scripts" / "openviking-codex-plugin-install"
        self.assertTrue(install_script.exists())

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source_copy = tmp_path / "plugin-source"
            source_link = tmp_path / "plugin-link"
            home = tmp_path / "home"
            marketplace = tmp_path / "marketplace"
            codex_config = tmp_path / "codex-config.toml"
            ovcli_conf = tmp_path / "ovcli.conf"

            shutil.copytree(PLUGIN_ROOT, source_copy)
            source_link.symlink_to(source_copy, target_is_directory=True)
            ovcli_conf.write_text(
                json.dumps(
                    {
                        "url": "http://127.0.0.1:1933",
                        "account": "local-dev",
                        "user": "carlos",
                        "agent_id": "local-dev",
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            env = os.environ.copy()
            env["HOME"] = str(home)
            env["OPENVIKING_CODEX_PLUGIN_SOURCE"] = str(source_link)
            env["OPENVIKING_CODEX_MARKETPLACE_ROOT"] = str(marketplace)
            env["CODEX_CONFIG_FILE"] = str(codex_config)
            env["OPENVIKING_CLI_CONFIG_FILE"] = str(ovcli_conf)

            subprocess.check_call([str(install_script)], cwd=REPO_ROOT, env=env)

            cache_dir = home / ".codex" / "plugins" / "cache" / "openviking-plugins-local" / "openviking-memory" / "0.5.0"
            source_hooks = (source_copy / "hooks" / "hooks.json").read_text(encoding="utf-8")
            cache_hooks = (cache_dir / "hooks" / "hooks.json").read_text(encoding="utf-8")

            self.assertTrue(cache_dir.is_dir())
            self.assertFalse(cache_dir.is_symlink())
            self.assertIn("__OPENVIKING_PLUGIN_ROOT__", source_hooks)
            self.assertNotIn("__OPENVIKING_PLUGIN_ROOT__", cache_hooks)
            self.assertIn(str(cache_dir), cache_hooks)


if __name__ == "__main__":
    unittest.main()
