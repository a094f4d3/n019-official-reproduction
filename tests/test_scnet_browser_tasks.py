from __future__ import annotations

import unittest
from pathlib import Path

from scripts.scnet_browser_tasks import (
    ConfigError,
    load_config,
    parse_account_inspection,
    password_env_name,
    read_plan,
    render_tasks,
    validate_submission_guards,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ScnetBrowserTaskTests(unittest.TestCase):
    def test_rendered_task_plan(self) -> None:
        config = {
            "defaults": {
                "region": "华中一区【A区】",
                "accelerator": "异构加速卡BW",
                "resource_group": "113 组",
                "cards": 2,
                "instances": 1,
                "auto_fault": False,
                "cpu_per_card": 15,
                "memory_gb_per_card": 59,
                "wall_hours": 18,
                "expected_card_hours": 28.0,
                "image": {
                    "framework": "PyTorch",
                    "version": "2.9.0",
                    "python": "py3.11-Ubuntu22.04",
                    "dtk": "dtk26.04",
                },
            },
            "tasks": [
                {
                    "id": "train",
                    "name": "n019_{timestamp}",
                    "account": "a094f4d4",
                    "startup_script": "bash /public/home/{account}/run.sh",
                }
            ],
        }
        tasks = render_tasks(
            config,
            [],
            run_stamp="20261103_120000",
        )
        self.assertEqual(tasks[0]["name"], "n019_20261103_120000")
        self.assertEqual(
            tasks[0]["startup_script"],
            "bash /public/home/a094f4d4/run.sh",
        )
        plan = read_plan(tasks[0])
        self.assertEqual(plan["worst_card_hours"], 36.0)
        self.assertEqual(plan["dcu"], 2)
        self.assertEqual(plan["cpu_per_card"], 15)
        self.assertEqual(plan["memory_gb_per_card"], 59)

    def test_task_name_length_is_validated(self) -> None:
        config = {
            "defaults": {
                "region": "华中一区【A区】",
                "accelerator": "异构加速卡BW",
                "resource_group": "113 组",
                "cpu_per_card": 15,
                "memory_gb_per_card": 59,
                "wall_hours": 1,
                "image": {
                    "framework": "PyTorch",
                    "version": "2.9.0",
                    "python": "py3.11-Ubuntu22.04",
                    "dtk": "dtk26.04",
                }
            },
            "tasks": [
                {
                    "name": "x" * 41,
                    "account": "a094f4d4",
                    "startup_script": "bash /tmp/run.sh",
                }
            ],
        }
        with self.assertRaises(ConfigError):
            render_tasks(config, [])

    def test_password_names_are_account_specific(self) -> None:
        self.assertEqual(
            password_env_name("a094f4d4"),
            "SCNET_PASSWORD_A094F4D4",
        )
        self.assertEqual(
            password_env_name("a094f4d4", "TEST_PW_"),
            "TEST_PW_A094F4D4",
        )

    def test_password_fields_are_rejected(self) -> None:
        # The loader validates JSON files; this keeps the safety rule visible.
        with self.assertRaises(ConfigError):
            from scripts.scnet_browser_tasks import _reject_password_fields

            _reject_password_fields({"login": {"password": "secret"}})

    def test_project_config_keeps_optional_tasks_disabled(self) -> None:
        config = load_config(
            PROJECT_ROOT / "configs" / "scnet_browser_tasks.json"
        )
        enabled = render_tasks(config, [])
        for task in enabled:
            self.assertFalse(task["submit"], task["id"])
            self.assertTrue(task.get("submitted_task_id"), task["id"])
        selected = render_tasks(config, ["d3-target-embedding-shard2"])
        self.assertEqual(len(selected), 1)
        self.assertEqual(selected[0]["account"], "a094f4d3")
        self.assertFalse(selected[0]["submit"])

    def test_disabled_submit_guard_is_visible_in_plan(self) -> None:
        config = load_config(
            PROJECT_ROOT / "configs" / "scnet_browser_tasks.json"
        )
        task = render_tasks(config, ["d4-target-embedding-shard0"])[0]
        plan = read_plan(task)
        self.assertFalse(plan["submit_allowed"])
        self.assertEqual(
            plan["configured_status"],
            "failed_after_final_write_verified",
        )
        self.assertEqual(plan["existing_task_id"], "2117447702608093185")

    def test_account_inspection_parses_balance(self) -> None:
        parsed = parse_account_inspection(
            "49.3025卡*时",
            r"([0-9]+(?:\.[0-9]+)?)\s*卡\s*\*?\s*时",
        )
        self.assertEqual(parsed["balance_card_hours"], 49.3025)

    def test_account_inspection_reports_missing_balance(self) -> None:
        parsed = parse_account_inspection(
            "登录页面",
            r"([0-9]+(?:\.[0-9]+)?)\s*卡\s*\*?\s*时",
        )
        self.assertIsNone(parsed["balance_card_hours"])

    def test_existing_task_id_blocks_accidental_resubmit(self) -> None:
        task = {
            "id": "existing",
            "name": "n019_existing",
            "submit": True,
            "submitted_task_id": "2117447702608093185",
        }
        with self.assertRaisesRegex(ConfigError, "submitted_task_id"):
            validate_submission_guards(
                [task],
                submit=True,
                force_resubmit=False,
            )
        validate_submission_guards(
            [task],
            submit=True,
            force_resubmit=True,
        )

    def test_task_level_submit_false_is_not_blocked_by_existing_id(self) -> None:
        task = {
            "id": "recorded",
            "name": "n019_recorded",
            "submit": False,
            "submitted_task_id": "2117447702608093185",
        }
        validate_submission_guards(
            [task],
            submit=True,
            force_resubmit=False,
        )


if __name__ == "__main__":
    unittest.main()
