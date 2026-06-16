import importlib.machinery
import importlib.util
import json
from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "romm-init"
ENV_TEMPLATE_PATH = Path(__file__).resolve().parents[1] / "env.tpl"

METADATA_SECRET_FIELDS = (
    "igdb_client_id",
    "igdb_client_secret",
    "mobygames_api_key",
    "screenscraper_user",
    "screenscraper_password",
    "retroachievements_api_key",
    "steamgriddb_api_key",
)


def load_romm_init():
    loader = importlib.machinery.SourceFileLoader("romm_init", str(SCRIPT_PATH))
    spec = importlib.util.spec_from_loader("romm_init", loader)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def has_field(item, label):
    return any(field.get("label") == label or field.get("id") == label for field in item.get("fields", []))


class FakeRunner:
    def __init__(self, romm_init, responses=None):
        self.romm_init = romm_init
        self.responses = list(responses or [])
        self.calls = []

    def run(self, args, *, input_text=None, check=True):
        self.calls.append({"args": list(args), "input_text": input_text, "check": check})
        if not self.responses:
            return ""

        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


class RommInitTests(unittest.TestCase):
    def setUp(self):
        self.romm_init = load_romm_init()

    def test_missing_1password_item_is_created_with_required_generated_secrets(self):
        runner = FakeRunner(
            self.romm_init,
            responses=[
                self.romm_init.CommandError(
                    ["op", "item", "get"],
                    1,
                    "",
                    "could not find item RomM Local",
                ),
                json.dumps({"id": "created-item"}),
            ],
        )

        secrets = self.romm_init.ensure_1password_item(
            runner,
            password_factory=lambda label: f"{label}-generated-secret",
        )

        create_call = runner.calls[1]
        self.assertEqual(
            create_call["args"],
            ["op", "item", "create", "--vault", "Personal", "-"],
        )

        created_item = json.loads(create_call["input_text"])
        self.assertEqual(created_item["title"], "RomM Local")
        self.assertEqual(created_item["urls"][0]["href"], "http://romm.disusered.com")
        self.assertEqual(secrets.db_root_password, "db_root_password-generated-secret")
        self.assertEqual(secrets.db_password, "db_password-generated-secret")
        self.assertEqual(secrets.auth_secret_key, "auth_secret_key-generated-secret")
        for field in METADATA_SECRET_FIELDS:
            self.assertFalse(has_field(created_item, field))

    def test_existing_1password_item_is_updated_without_putting_secrets_in_argv(self):
        existing_item = {
            "id": "item-1",
            "title": "RomM Local",
            "urls": [{"href": "http://old.example"}],
            "fields": [
                {
                    "id": "db_password",
                    "label": "db_password",
                    "type": "CONCEALED",
                    "value": "existing-db-password",
                },
                {
                    "id": "steamgriddb_api_key",
                    "label": "steamgriddb_api_key",
                    "type": "CONCEALED",
                    "value": "existing-steamgrid-key",
                },
            ],
        }
        runner = FakeRunner(
            self.romm_init,
            responses=[
                json.dumps(existing_item),
                json.dumps({"id": "item-1"}),
            ],
        )

        secrets = self.romm_init.ensure_1password_item(
            runner,
            password_factory=lambda label: f"{label}-generated-secret",
        )

        edit_call = runner.calls[1]
        self.assertEqual(edit_call["args"], ["op", "item", "edit", "item-1", "--vault", "Personal"])
        argv_text = " ".join(edit_call["args"])
        self.assertNotIn("existing-db-password", argv_text)
        self.assertNotIn("db_root_password-generated-secret", argv_text)
        self.assertNotIn("auth_secret_key-generated-secret", argv_text)

        edited_item = json.loads(edit_call["input_text"])
        self.assertEqual(edited_item["urls"][0]["href"], "http://romm.disusered.com")
        self.assertEqual(secrets.db_password, "existing-db-password")
        self.assertEqual(secrets.db_root_password, "db_root_password-generated-secret")
        self.assertEqual(secrets.auth_secret_key, "auth_secret_key-generated-secret")
        self.assertEqual(self.romm_init.field_value(edited_item, "steamgriddb_api_key"), "existing-steamgrid-key")

    def test_env_template_uses_only_approved_metadata_provider_sources(self):
        template = ENV_TEMPLATE_PATH.read_text()

        self.assertIn("IGDB_CLIENT_ID=op://Personal/Twitch/IGDB App/Client ID\n", template)
        self.assertIn("IGDB_CLIENT_SECRET=op://Personal/Twitch/IGDB App/Client Secret\n", template)
        self.assertIn("RETROACHIEVEMENTS_API_KEY=op://Personal/RetroAchievements/add more/API Key\n", template)
        self.assertIn("HASHEOUS_API_ENABLED=true\n", template)
        self.assertIn("PLAYMATCH_API_ENABLED=true\n", template)
        self.assertIn("LAUNCHBOX_API_ENABLED=true\n", template)
        self.assertIn("ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA=true\n", template)
        self.assertIn("FLASHPOINT_API_ENABLED=true\n", template)
        self.assertIn("HLTB_API_ENABLED=true\n", template)

        self.assertNotIn("MOBYGAMES_API_KEY", template)
        self.assertNotIn("SCREENSCRAPER_USER", template)
        self.assertNotIn("SCREENSCRAPER_PASSWORD", template)
        self.assertNotIn("STEAMGRIDDB_API_KEY", template)
        self.assertNotIn("RETROACHIEVEMENTS_API_KEY=op://Personal/RomM Local/", template)

    def test_render_env_writes_mode_600_and_resolves_1password_template(self):
        class FakePath:
            def __init__(self):
                self.text = ""
                self.mode = None

            def write_text(self, text):
                self.text = text

            def chmod(self, mode):
                self.mode = mode

        runner = FakeRunner(self.romm_init, responses=["DB_PASSWD=rendered-secret\n"])
        output_path = FakePath()

        self.romm_init.render_env_file(runner, Path("/tmp/romm.env.tpl"), output_path)

        self.assertEqual(
            runner.calls[0]["args"],
            ["op", "inject", "--force", "-i", "/tmp/romm.env.tpl"],
        )
        self.assertEqual(output_path.text, "DB_PASSWD=rendered-secret\n")
        self.assertEqual(output_path.mode, 0o600)


if __name__ == "__main__":
    unittest.main()
