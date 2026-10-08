"""Runs report.jq against canned Prometheus responses shaped like the AI proxy's metrics."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

REPORT = Path(sys.argv.pop(1) if len(sys.argv) > 1 else Path(__file__).with_name("report.jq"))


def vector(*series):
    return {"status": "success", "data": {"resultType": "vector", "result": [
        {"metric": labels, "value": [0, str(value)]} for labels, value in series
    ]}}


def m(provider, account, **labels):
    return {"__name__": "x", "provider": provider, "account": account, **labels}


RESPONSES = {
    "usage": vector(
        (m("claude", "one@x", limit="5h"), 0.43), (m("claude", "one@x", limit="7d"), 0.16),
        (m("claude", "two@x", limit="7d"), 0.87), (m("claude", "two@x", limit="5h"), 0.34),
        (m("codex", "me@x", limit="5h"), 0.34), (m("codex", "me@x", limit="7d"), 0.22),
        (m("codex", "me@x", limit="30m"), 0.05), (m("claude", "one@x", limit="overage"), 0.9),
    ),
    "resets": vector(
        (m("claude", "one@x", limit="5h"), 1000), (m("claude", "one@x", limit="7d"), 9000),
        (m("claude", "two@x", limit="5h"), 1200), (m("claude", "two@x", limit="7d"), 5000),
        (m("codex", "me@x", limit="5h"), 800), (m("codex", "me@x", limit="7d"), 7000),
    ),
    "status": vector(
        (m("claude", "two@x", limit="7d", status="allowed_warning"), 1),
        (m("claude", "two@x", limit="7d", status="allowed"), 0),
        (m("claude", "one@x", limit="overage", status="rejected"), 1),
    ),
    "overUsed": vector((m("claude", "one@x"), 249.76)),
    "overLimit": vector((m("claude", "one@x"), 0)),
    "available": vector((m("claude", "one@x"), 1), (m("claude", "two@x"), 0), (m("codex", "me@x"), 1)),
    "modelUsage": vector((m("claude", "one@x", model="Fable", limit="7d"), 0.05)),
    "modelResets": vector((m("claude", "one@x", model="Fable", limit="7d"), 9000)),
}


def report(responses=RESPONSES):
    args = []
    for name, value in responses.items():
        args += ["--argjson", name, json.dumps(value)]
    out = subprocess.run(["jq", "-n", *args, "-f", str(REPORT)], check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


class ReportTest(unittest.TestCase):
    def setUp(self):
        self.r = report()
        self.claude, self.codex = self.r["providers"]

    def account(self, provider, name):
        return next(a for a in provider["accounts"] if a["account"] == name)

    def test_lists_providers_claude_first_with_their_accounts(self):
        self.assertEqual([p["id"] for p in self.r["providers"]], ["claude", "codex"])
        self.assertEqual(self.claude["name"], "Claude")
        self.assertEqual([a["account"] for a in self.claude["accounts"]], ["one@x", "two@x"])
        self.assertEqual([a["account"] for a in self.codex["accounts"]], ["me@x"])

    def test_keeps_each_accounts_own_limits_in_5h_7d_order(self):
        two = self.account(self.claude, "two@x")
        self.assertEqual([lim["label"] for lim in two["limits"]], ["5h", "7d"])
        self.assertEqual(round(two["limits"][1]["percent"]), 87)
        self.assertEqual(two["limits"][1]["resetAt"], 5000)

    def test_picks_up_any_duration_shaped_limit_in_window_order(self):
        me = self.codex["accounts"][0]
        self.assertEqual([(lim["label"], lim["seconds"]) for lim in me["limits"]],
                         [("30m", 1800), ("5h", 18000), ("7d", 604800)])

    def test_ignores_limits_that_are_not_windows(self):
        one = self.account(self.claude, "one@x")
        self.assertNotIn("overage", [lim["label"] for lim in one["limits"]])

    def test_handles_an_added_account_without_changes(self):
        extra = {k: {"data": {"result": list(v["data"]["result"])}} for k, v in RESPONSES.items()}
        extra["usage"]["data"]["result"].append({"metric": m("claude", "three@x", limit="5h"), "value": [0, "0.5"]})
        extra["resets"]["data"]["result"].append({"metric": m("claude", "three@x", limit="5h"), "value": [0, "1500"]})
        claude = report(extra)["providers"][0]
        self.assertEqual([a["account"] for a in claude["accounts"]], ["one@x", "three@x", "two@x"])

    def test_takes_the_active_status_per_limit(self):
        two = self.account(self.claude, "two@x")
        self.assertEqual(two["limits"][1]["status"], "allowed_warning")
        self.assertIsNone(two["limits"][0]["status"])

    def test_reports_overage_and_availability(self):
        one, two = self.account(self.claude, "one@x"), self.account(self.claude, "two@x")
        self.assertEqual(one["overage"], {"used": 249.76, "limit": 0, "status": "rejected"})
        self.assertIsNone(two["overage"])
        self.assertTrue(one["available"])
        self.assertFalse(two["available"])

    def test_attaches_model_quotas_to_their_account(self):
        one = self.account(self.claude, "one@x")
        self.assertEqual(one["models"], [{"model": "Fable", "label": "7d", "percent": 5.0, "resetAt": 9000}])
        self.assertEqual(self.codex["accounts"][0]["models"], [])

    def test_handles_a_codex_only_proxy(self):
        only = {k: {"data": {"result": [s for s in v["data"]["result"] if s["metric"]["provider"] == "codex"]}}
                for k, v in RESPONSES.items()}
        r = report(only)
        self.assertEqual([p["id"] for p in r["providers"]], ["codex"])


if __name__ == "__main__":
    unittest.main()
