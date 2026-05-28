import importlib.machinery
import importlib.util
import json
from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "xbol-grafana-bootstrap"


def load_bootstrap():
    loader = importlib.machinery.SourceFileLoader("xbol_grafana_bootstrap", str(SCRIPT_PATH))
    spec = importlib.util.spec_from_loader("xbol_grafana_bootstrap", loader)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class FakeRunner:
    def __init__(self, bootstrap, responses=None):
        self.bootstrap = bootstrap
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


class XbolGrafanaBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.bootstrap = load_bootstrap()

    def test_missing_1password_item_is_created_with_http_tailnet_url(self):
        runner = FakeRunner(
            self.bootstrap,
            responses=[
                self.bootstrap.CommandError(["op", "item", "get"], 1, "", "could not find item XBOL Grafana Local"),
                json.dumps({"id": "created-item"}),
            ],
        )
        secrets = self.bootstrap.ensure_1password_item(
            runner,
            password_factory=lambda label: f"{label}-generated-secret",
        )

        create_call = runner.calls[1]
        self.assertEqual(
            create_call["args"],
            [
                "op",
                "item",
                "create",
                "--vault",
                "Personal",
                "-",
            ],
        )

        created_item = json.loads(create_call["input_text"])
        self.assertEqual(created_item["title"], "XBOL Grafana Local")
        self.assertEqual(created_item["urls"][0]["href"], "http://xbol.disusered.com")
        self.assertEqual(secrets.admin_password, "admin_password-generated-secret")
        self.assertEqual(secrets.carlos_password, "carlos_password-generated-secret")
        self.assertEqual(secrets.agent_service_account_token, "")

    def test_existing_item_is_updated_without_putting_secrets_in_argv(self):
        existing_item = {
            "id": "item-1",
            "title": "XBOL Grafana Local",
            "urls": [{"href": "http://old.example"}],
            "fields": [
                {"id": "admin_password", "label": "admin_password", "type": "CONCEALED", "value": "admin-secret"},
            ],
        }
        runner = FakeRunner(
            self.bootstrap,
            responses=[
                json.dumps(existing_item),
                json.dumps({"id": "item-1"}),
            ],
        )

        secrets = self.bootstrap.ensure_1password_item(
            runner,
            password_factory=lambda label: f"{label}-generated-secret",
        )

        edit_call = runner.calls[1]
        self.assertEqual(edit_call["args"], ["op", "item", "edit", "item-1", "--vault", "Personal"])
        self.assertNotIn("carlos_password-generated-secret", " ".join(edit_call["args"]))
        self.assertNotIn("admin-secret", " ".join(edit_call["args"]))

        edited_item = json.loads(edit_call["input_text"])
        self.assertEqual(edited_item["urls"][0]["href"], "http://xbol.disusered.com")
        self.assertEqual(secrets.admin_password, "admin-secret")
        self.assertEqual(secrets.carlos_password, "carlos_password-generated-secret")

    def test_invalid_existing_agent_token_requires_explicit_rotation(self):
        class FakeGrafana:
            def authenticate_service_account(self, token):
                return False

        grafana = FakeGrafana()
        secrets = self.bootstrap.GrafanaSecrets(
            admin_password="admin-secret",
            carlos_password="carlos-secret",
            agent_service_account_token="stale-token",
        )

        with self.assertRaisesRegex(self.bootstrap.BootstrapError, "--rotate-agent-token"):
            self.bootstrap.ensure_agent_token(
                grafana,
                service_account_id=17,
                secrets=secrets,
                op_store=None,
                rotate_agent_token=False,
            )

    def test_rotate_agent_token_creates_and_persists_new_token(self):
        class FakeGrafana:
            def __init__(self):
                self.created = []

            def authenticate_service_account(self, token):
                return False

            def create_service_account_token(self, service_account_id, token_name):
                self.created.append((service_account_id, token_name))
                return "new-token-secret"

        class FakeStore:
            def __init__(self):
                self.updates = []

            def set_agent_service_account_token(self, token):
                self.updates.append(token)

        secrets = self.bootstrap.GrafanaSecrets(
            admin_password="admin-secret",
            carlos_password="carlos-secret",
            agent_service_account_token="stale-token",
        )
        grafana = FakeGrafana()
        store = FakeStore()

        token = self.bootstrap.ensure_agent_token(
            grafana,
            service_account_id=17,
            secrets=secrets,
            op_store=store,
            rotate_agent_token=True,
        )

        self.assertEqual(token, "new-token-secret")
        self.assertEqual(grafana.created, [(17, "xbol-agent-mcp")])
        self.assertEqual(store.updates, ["new-token-secret"])

    def test_wait_seconds_is_accepted_after_subcommand(self):
        args = self.bootstrap.parse_args(["apply", "--wait-seconds", "60"])

        self.assertEqual(args.command, "apply")
        self.assertEqual(args.wait_seconds, 60)


if __name__ == "__main__":
    unittest.main()
