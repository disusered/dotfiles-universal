import importlib.machinery
import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "neo4j-init"
LOADER = importlib.machinery.SourceFileLoader("neo4j_init", str(SCRIPT))
SPEC = importlib.util.spec_from_loader("neo4j_init", LOADER)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FakeRunner:
    def __init__(self, item=None):
        self.item = item
        self.calls = []

    def run(self, args, *, input_text=None, check=True):
        self.calls.append((list(args), input_text))
        if args[:3] == ["op", "item", "get"]:
            if self.item is None:
                raise MODULE.CommandError(args, 1, "", "item not found")
            import json

            return json.dumps(self.item)
        return ""


def test_create_item_uses_neo4j_login_and_generated_password():
    item = MODULE.make_item(lambda: "generated-password")

    assert MODULE.field_value(item, "username") == "neo4j"
    assert MODULE.field_value(item, "password") == "generated-password"
    assert item["urls"][0]["href"] == "http://127.0.0.1:7474"


def test_ensure_item_creates_missing_login():
    runner = FakeRunner()

    item = MODULE.ensure_item(runner, lambda: "generated-password")

    assert MODULE.field_value(item, "password") == "generated-password"
    assert any(call[0][:3] == ["op", "item", "create"] for call in runner.calls)
