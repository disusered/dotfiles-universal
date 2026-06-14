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

    def test_scope_config_resolves_xbol_then_general(self):
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
                {"account": "local-dev", "user": "carlos", "agentId": "local-dev"},
            ],
            config["lookupScopes"],
        )
        self.assertEqual({"account": "xbol", "user": "carlos", "agentId": "xbol"}, config["writeScope"])

    def test_scope_config_resolves_dotfiles_to_general_only(self):
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
            [{"account": "local-dev", "user": "carlos", "agentId": "local-dev"}],
            config["lookupScopes"],
        )
        self.assertEqual(
            {"account": "local-dev", "user": "carlos", "agentId": "local-dev"},
            config["writeScope"],
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
                {"account": "local-dev", "user": "carlos", "agentId": "local-dev"},
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


if __name__ == "__main__":
    unittest.main()
