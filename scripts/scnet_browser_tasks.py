"""Submit SCNet AI model-training tasks through Playwright.

Task values and UI selectors are read from a JSON inventory. Credentials are
never stored in that file: the script reads an account-specific environment
variable, the shared environment variable, or prompts with getpass.
"""

from __future__ import annotations

import argparse
import copy
import getpass
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
IMAGE_FIELDS = ("framework", "version", "python", "dtk")


class ConfigError(ValueError):
    pass


class LoginRequired(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Submit SCNet AI training tasks from a JSON inventory."
    )
    parser.add_argument(
        "--config",
        default=str(PROJECT_ROOT / "configs" / "scnet_browser_tasks.json"),
    )
    parser.add_argument(
        "--task",
        action="append",
        default=[],
        help="Task id to run; may be repeated. Default: all configured tasks.",
    )
    parser.add_argument(
        "--check-config",
        action="store_true",
        help="Validate and print the rendered plan without opening a browser.",
    )
    parser.add_argument(
        "--inspect-accounts",
        action="store_true",
        help="Log in and read live balances without creating a task.",
    )
    parser.add_argument(
        "--inspect-job",
        help="Read-only inspect a task by its exact display name.",
    )
    parser.add_argument(
        "--list-jobs",
        action="store_true",
        help="Read-only list task rows for --account.",
    )
    parser.add_argument(
        "--account",
        help="Account owning --inspect-job.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--headed", action="store_true")
    mode.add_argument("--headless", action="store_true")
    submission_mode = parser.add_mutually_exclusive_group()
    submission_mode.add_argument(
        "--submit",
        action="store_true",
        help="Actually click the final Create button. Default follows dry_run.",
    )
    submission_mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Fill and validate forms without clicking Create.",
    )
    parser.add_argument(
        "--force-resubmit",
        action="store_true",
        help=(
            "Allow submission even when the task already has "
            "submitted_task_id in the config."
        ),
    )
    parser.add_argument(
        "--list-tasks",
        action="store_true",
        help="List configured task ids and safety state without opening a browser.",
    )
    parser.add_argument(
        "--no-prompt",
        action="store_true",
        help="Fail instead of prompting when a password environment variable is absent.",
    )
    return parser.parse_args()


def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(base)
    for key, value in override.items():
        if (
            key in result
            and isinstance(result[key], dict)
            and isinstance(value, dict)
        ):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def _reject_password_fields(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = str(key).lower().replace("-", "_")
            sensitive_keys = {
                "password",
                "passwd",
                "pwd",
                "secret",
                "token",
                "api_key",
                "apikey",
                "credential",
            }
            if normalized in sensitive_keys or normalized.endswith("_password"):
                raise ConfigError(
                    f"Do not store credentials in the config ({path}.{key})"
                )
            _reject_password_fields(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _reject_password_fields(child, f"{path}[{index}]")


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    _reject_password_fields(config)
    defaults = config.get("defaults", {})
    if not isinstance(defaults, dict):
        raise ConfigError("defaults must be an object")
    browser = config.get("browser")
    if not isinstance(browser, dict):
        raise ConfigError("browser must be an object")
    ui = browser.get("ui")
    if not isinstance(ui, dict):
        raise ConfigError("browser.ui must be an object")
    tasks = config.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise ConfigError("tasks must be a non-empty array")
    config["tasks"] = [
        _deep_merge(defaults, task) if isinstance(task, dict) else task
        for task in tasks
    ]
    return config


def render_value(value: Any, variables: dict[str, str]) -> Any:
    if isinstance(value, str):
        rendered = value
        for key, replacement in variables.items():
            rendered = rendered.replace("{" + key + "}", replacement)
        return rendered
    if isinstance(value, list):
        return [render_value(item, variables) for item in value]
    if isinstance(value, dict):
        return {
            key: render_value(item, variables)
            for key, item in value.items()
        }
    return value


def render_tasks(
    config: dict[str, Any],
    selected_ids: list[str],
    *,
    run_stamp: str | None = None,
) -> list[dict[str, Any]]:
    stamp = run_stamp or datetime.now().strftime("%Y%m%d_%H%M%S")
    selected = set(selected_ids)
    rendered = []
    seen_names: set[str] = set()
    defaults = config.get("defaults", {})
    for index, task in enumerate(config["tasks"]):
        if not isinstance(task, dict):
            raise ConfigError(f"Task {index} must be an object")
        task = _deep_merge(defaults, task)
        task_id = str(task.get("id", f"task-{index}"))
        if not bool(task.get("enabled", True)) and task_id not in selected:
            continue
        if selected and task_id not in selected:
            continue
        account = str(task.get("account", ""))
        if not account:
            raise ConfigError(f"Task {task_id} is missing account")
        values = render_value(
            task,
            {"timestamp": stamp, "account": account, "task_index": str(index)},
        )
        values["id"] = task_id
        name = str(values.get("name", ""))
        if not name:
            raise ConfigError(f"Task {task_id} is missing name")
        if len(name) > 40:
            raise ConfigError(
                f"Task name exceeds SCNet's 40-character limit: {name}"
            )
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,39}", name):
            raise ConfigError(f"Invalid SCNet task name: {name}")
        if name in seen_names:
            raise ConfigError(f"Duplicate rendered task name: {name}")
        seen_names.add(name)
        script = str(values.get("startup_script", "")).strip()
        if not script:
            raise ConfigError(f"Task {task_id} is missing startup_script")
        prefixes = values.get(
            "allowed_start_prefixes",
            ["bash ", "python ", "torchrun "],
        )
        if not any(script.startswith(prefix) for prefix in prefixes):
            raise ConfigError(
                f"Task {task_id} startup_script must start with one of {prefixes}"
            )
        image = values.get("image")
        if not isinstance(image, dict):
            raise ConfigError(f"Task {task_id} is missing image")
        missing = [key for key in IMAGE_FIELDS if not image.get(key)]
        if missing:
            raise ConfigError(
                f"Task {task_id} image is missing: {', '.join(missing)}"
            )
        values["cards"] = int(values.get("cards", 1))
        values["instances"] = int(values.get("instances", 1))
        if values["cards"] < 1 or values["instances"] < 1:
            raise ConfigError(f"Task {task_id} has invalid card/instance count")
        wall_hours = float(values.get("wall_hours", 0))
        if wall_hours <= 0:
            raise ConfigError(f"Task {task_id} has invalid wall_hours")
        values["wall_hours"] = wall_hours
        for field in ("region", "accelerator", "resource_group"):
            if not str(values.get(field, "")).strip():
                raise ConfigError(f"Task {task_id} is missing {field}")
        for field in ("cpu_per_card", "memory_gb_per_card"):
            if int(values.get(field, 0)) < 1:
                raise ConfigError(f"Task {task_id} has invalid {field}")
        rendered.append(values)
    if selected:
        found = {task["id"] for task in rendered}
        missing = selected - found
        if missing:
            raise ConfigError(f"Unknown task ids: {sorted(missing)}")
    return rendered


def password_env_name(account: str, prefix: str = "SCNET_PASSWORD_") -> str:
    normalized = re.sub(r"[^A-Za-z0-9]", "_", account).upper()
    return f"{prefix}{normalized}"


def read_plan(task: dict[str, Any]) -> dict[str, Any]:
    cpu_per_card = int(task["cpu_per_card"])
    memory_gb_per_card = int(task["memory_gb_per_card"])
    card_slots = int(task["cards"]) * int(task["instances"])
    return {
        "task_id": task["id"],
        "name": task["name"],
        "account": task["account"],
        "mode": "人工智能/模型训练",
        "region": task["region"],
        "accelerator": task["accelerator"],
        "resource_group": task["resource_group"],
        "dcu": task["cards"],
        "instances": task["instances"],
        "cpu_per_card": cpu_per_card,
        "memory_gb_per_card": memory_gb_per_card,
        "cpu_ram": (
            f"{cpu_per_card} CPU + {memory_gb_per_card} GB per DCU; "
            f"platform allocation for {card_slots} DCU(s)"
        ),
        "expected_resource_text": task.get("expected_resource_text", []),
        "wall_hours": task.get("wall_hours"),
        "worst_card_hours": float(task.get("wall_hours", 0))
        * int(task["cards"])
        * int(task["instances"]),
        "expected_card_hours": task.get("expected_card_hours"),
        "image": task["image"],
        "startup_script": task["startup_script"],
        "input_paths": task.get("input_paths", []),
        "output_paths": task.get("output_paths", []),
        "stop_conditions": task.get("stop_conditions", []),
        "submit_allowed": bool(task.get("submit", True)),
        "configured_status": task.get("status"),
        "existing_task_id": task.get("submitted_task_id"),
    }


def validate_submission_guards(
    tasks: list[dict[str, Any]],
    *,
    submit: bool,
    force_resubmit: bool,
) -> None:
    if not submit or force_resubmit:
        return
    blocked = [
        {
            "id": task["id"],
            "name": task["name"],
            "submitted_task_id": task["submitted_task_id"],
        }
        for task in tasks
        if bool(task.get("submit", True)) and task.get("submitted_task_id")
    ]
    if blocked:
        raise ConfigError(
            "Refusing to submit tasks that already record submitted_task_id: "
            f"{blocked}. Verify the old task is finished, then remove its "
            "submitted_task_id or pass --force-resubmit for an intentional rerun."
        )


def parse_account_inspection(
    body_text: str,
    balance_regex: str,
) -> dict[str, Any]:
    balance_match = re.search(balance_regex, body_text)
    balance = float(balance_match.group(1)) if balance_match else None
    return {
        "balance_card_hours": balance,
        "balance_match": balance_match.group(0) if balance_match else None,
    }


def _password_for(
    account: str,
    browser_cfg: dict[str, Any],
    *,
    allow_prompt: bool = True,
) -> str:
    prefix = str(browser_cfg.get("password_env_prefix", "SCNET_PASSWORD_"))
    shared_name = str(browser_cfg.get("shared_password_env", "SCNET_PASSWORD"))
    account_key = password_env_name(account, prefix)
    value = os.getenv(account_key) or os.getenv(shared_name)
    if value:
        return value
    if allow_prompt and sys.stdin.isatty():
        return getpass.getpass(f"SCNet password for {account}: ")
    raise LoginRequired(
        f"Set {account_key} or {shared_name}, or run in an interactive terminal"
    )


def _browser_viewport(browser_cfg: dict[str, Any]) -> dict[str, int]:
    viewport = browser_cfg.get("viewport", {})
    if not isinstance(viewport, dict):
        raise ConfigError("browser.viewport must be an object")
    width = int(viewport.get("width", 1440))
    height = int(viewport.get("height", 1000))
    if width <= 0 or height <= 0:
        raise ConfigError("browser.viewport dimensions must be positive")
    return {"width": width, "height": height}


def _session_state_path(
    browser_cfg: dict[str, Any],
    account: str,
) -> Path:
    profile_dir = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    ) / account
    profile_dir.mkdir(parents=True, exist_ok=True)
    filename = str(
        browser_cfg.get("session_state_filename", "n019_browser_state.json")
    )
    return profile_dir / filename


def _save_browser_state(
    page: Any,
    browser_cfg: dict[str, Any],
    account: str,
) -> None:
    if not bool(browser_cfg.get("persist_session_state", True)):
        return
    state_path = _session_state_path(browser_cfg, account)
    state = page.context.storage_state()
    page_state = page.evaluate(
        """() => ({
          origin: location.origin,
          local: Object.fromEntries(
            Array.from({length: localStorage.length}, (_, i) => {
              const key = localStorage.key(i);
              return [key, localStorage.getItem(key)];
            })
          ),
          session: Object.fromEntries(
            Array.from({length: sessionStorage.length}, (_, i) => {
              const key = sessionStorage.key(i);
              return [key, sessionStorage.getItem(key)];
            })
          )
        })"""
    )
    origins = {
        entry["origin"]: dict(entry.get("localStorage", {}))
        for entry in state.get("origins", [])
        if entry.get("origin")
    }
    if page_state.get("origin"):
        origins[page_state["origin"]] = page_state.get("local", {})
        state["session_storage"] = {
            page_state["origin"]: page_state.get("session", {})
        }
    state["origins"] = [
        {"origin": origin, "localStorage": values}
        for origin, values in origins.items()
    ]
    temporary = state_path.with_suffix(state_path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(state, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    os.replace(temporary, state_path)


def _restore_browser_state(
    page: Any,
    browser_cfg: dict[str, Any],
    account: str,
) -> None:
    if not bool(browser_cfg.get("persist_session_state", True)):
        return
    state_path = _session_state_path(browser_cfg, account)
    if not state_path.is_file():
        return
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
        cookies = state.get("cookies", [])
        if cookies:
            page.context.add_cookies(cookies)
        session_storage = state.get("session_storage", {})
        for entry in state.get("origins", []):
            origin = entry.get("origin")
            if not origin:
                continue
            local_values = entry.get("localStorage", {})
            session_values = session_storage.get(origin, {})
            script = """(() => {
              if (location.origin !== %s) return;
              const local = %s;
              const session = %s;
              for (const [key, value] of Object.entries(local)) {
                localStorage.setItem(key, value);
              }
              for (const [key, value] of Object.entries(session)) {
                sessionStorage.setItem(key, value);
              }
            })();""" % (
                json.dumps(origin),
                json.dumps(local_values, ensure_ascii=True),
                json.dumps(session_values, ensure_ascii=True),
            )
            page.context.add_init_script(script=script)
    except Exception as exc:
        print(
            f"Could not restore browser state for {account}: {exc}",
            file=sys.stderr,
            flush=True,
        )


def _visible(page: Any, selector: str) -> bool:
    locator = page.locator(selector)
    return locator.count() > 0 and locator.first.is_visible()


def _click_first_visible(locator: Any, timeout_ms: int = 30000) -> None:
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        for index in range(locator.count()):
            candidate = locator.nth(index)
            if candidate.is_visible():
                try:
                    candidate.click()
                except Exception:
                    # Element Plus sometimes reports a radio as visible while
                    # its parent overlay is still animating. A forced click
                    # still dispatches the native label event.
                    candidate.click(force=True)
                return
        time.sleep(0.1)
    raise TimeoutError("No visible matching element appeared")


def _first_visible(locator: Any, timeout_ms: int = 30000) -> Any:
    deadline = time.monotonic() + timeout_ms / 1000
    while time.monotonic() < deadline:
        for index in range(locator.count()):
            candidate = locator.nth(index)
            if candidate.is_visible():
                return candidate
        time.sleep(0.1)
    raise TimeoutError("No visible matching element appeared")


def _login(page: Any, task: dict[str, Any], config: dict[str, Any]) -> None:
    browser_cfg = config["browser"]
    ui = browser_cfg["ui"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    _restore_browser_state(page, browser_cfg, str(task["account"]))
    page.goto(
        browser_cfg["model_training_url"],
        wait_until="domcontentloaded",
        timeout=timeout,
    )
    page.wait_for_function(
        """selector => !!document.querySelector(selector)""",
        arg=ui["login_ready_selector"],
        timeout=timeout,
    )
    if _visible(page, ui["task_name_selector"]):
        _save_browser_state(page, browser_cfg, str(task["account"]))
        return
    page.locator(ui["username_selector"]).wait_for(
        state="visible", timeout=timeout
    )
    page.locator(ui["username_selector"]).fill(task["account"])
    print(f"Logging in as {task['account']}...", flush=True)
    page.locator(ui["password_selector"]).fill(
        _password_for(
            task["account"],
            browser_cfg,
            allow_prompt=bool(
                browser_cfg.get("password_prompt", True)
            ),
        )
    )
    if _visible(page, ui["captcha_selector"]):
        if browser_cfg.get("headless", False):
            raise LoginRequired(
                "SCNet requires a graphical CAPTCHA; rerun with --headed"
            )
        manual_seconds = int(
            browser_cfg.get("manual_login_timeout_seconds", 120)
        )
        print(
            "Graphical CAPTCHA appeared. Complete login in the opened browser; "
            f"waiting up to {manual_seconds} seconds.",
            flush=True,
        )
        page.wait_for_function(
            "fragment => !location.href.includes(fragment)",
            arg=ui["login_url_fragment"],
            timeout=manual_seconds * 1000,
        )
    else:
        _click_first_visible(
            page.get_by_role(
                "button", name=ui["login_button_name"], exact=True
            ),
            timeout,
        )
    try:
        page.wait_for_function(
            "fragment => !location.href.includes(fragment)",
            arg=ui["login_url_fragment"],
            timeout=timeout,
        )
    except Exception as exc:
        raise LoginRequired(
            "SCNet login did not complete; check credentials or manual login"
        ) from exc
    page.goto(
        browser_cfg["model_training_url"],
        wait_until="domcontentloaded",
        timeout=timeout,
    )
    page.locator(ui["task_name_selector"]).wait_for(
        state="visible", timeout=timeout
    )
    _save_browser_state(page, browser_cfg, str(task["account"]))


def _form_item(page: Any, label: str, ui: dict[str, Any]) -> Any:
    text = page.get_by_text(
        re.compile(rf"^\s*\*?\s*{re.escape(label)}\s*$")
    ).first
    return text.locator(ui["form_item_xpath"])


def _select_region_and_resource(
    page: Any, task: dict[str, Any], ui: dict[str, Any]
) -> None:
    _click_first_visible(
        page.get_by_role("radio", name=task["region"], exact=True)
    )
    _click_first_visible(
        page.get_by_role(
            "button", name=ui["refresh_button_name"], exact=True
        )
    )
    row = page.locator(ui["resource_row_selector"]).filter(
        has_text=task["resource_group"]
    )
    row = row.filter(has_text=task["accelerator"]).first
    row = _first_visible(row)
    row_text = " ".join(row.inner_text().split())
    missing = [
        expected
        for expected in task.get("expected_resource_text", [])
        if expected not in row_text
    ]
    if missing:
        raise ConfigError(
            "Selected resource row does not match configured allocation; "
            f"missing text: {missing}"
        )
    row.click()


def _select_cards(page: Any, cards: int, ui: dict[str, Any]) -> None:
    item = _form_item(page, ui["cards_label"], ui)
    _click_first_visible(
        item.get_by_role("radio", name=str(cards), exact=True)
    )


def _select_instances(page: Any, instances: int, ui: dict[str, Any]) -> None:
    item = _form_item(page, ui["instances_label"], ui)
    field = item.locator("input[role='spinbutton']").first
    current = int(field.input_value())
    if current == instances:
        return
    container = item.locator(".el-input-number").first
    button_name = "__increase" if instances > current else "__decrease"
    button = container.locator(f".el-input-number{button_name}")
    for _ in range(abs(instances - current)):
        if "is-disabled" in (button.get_attribute("class") or ""):
            raise RuntimeError(
                f"Cannot set instances to {instances}; control is disabled"
            )
        button.click()
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if int(field.input_value()) == instances:
            return
        time.sleep(0.1)
    raise RuntimeError(f"Instance count did not update to {instances}")


def _set_auto_fault(
    page: Any,
    enabled: bool,
    retry_limit: int,
    ui: dict[str, Any],
) -> None:
    item = _form_item(page, ui["auto_fault_label"], ui)
    switch = item.locator(".el-switch").first
    checked = "is-checked" in (switch.get_attribute("class") or "")
    if checked != enabled:
        switch.click()
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            current = "is-checked" in (switch.get_attribute("class") or "")
            if current == enabled:
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Automatic fault tolerance switch did not update")
    if enabled:
        retry = item.locator("input[role='spinbutton']").first
        retry.fill(str(retry_limit))


def _select_image(page: Any, image: dict[str, str], ui: dict[str, Any]) -> None:
    _click_first_visible(
        page.get_by_placeholder(ui["image_placeholder"])
    )
    for key in IMAGE_FIELDS:
        node = page.locator(ui["visible_popper_selector"]).locator(
            ui["cascader_node_selector"]
        ).filter(
            has_text=re.compile(rf"^\s*{re.escape(image[key])}\s*$")
        )
        _click_first_visible(node)
        page.wait_for_timeout(150)
    expected = ui["image_value_separator"].join(
        image[key] for key in IMAGE_FIELDS
    )
    page.wait_for_function(
        """expected => [...document.querySelectorAll('input')].some(
          input => input.offsetParent !== null && input.value === expected
        )""",
        arg=expected,
        timeout=30000,
    )


def _fill_startup_script(
    page: Any, script: str, ui: dict[str, Any]
) -> None:
    editor = page.locator(ui["startup_editor_selector"]).first
    editor.wait_for(state="visible", timeout=30000)
    editor.scroll_into_view_if_needed()
    page.evaluate(
        """script => {
          const editor = [...document.querySelectorAll('.CodeMirror')]
            .find(element => element.offsetParent !== null);
          if (!editor || !editor.CodeMirror) {
            throw new Error('Visible CodeMirror editor not found');
          }
          editor.CodeMirror.setValue(script);
          editor.CodeMirror.setCursor(editor.CodeMirror.lineCount(), 0);
        }""",
        script,
    )
    page.wait_for_timeout(300)
    rendered = page.evaluate(
        """selector => {
          const editor = [...document.querySelectorAll(selector)]
            .find(element => element.offsetParent !== null);
          return editor && editor.CodeMirror
            ? editor.CodeMirror.getValue()
            : null;
        }""",
        ui["startup_editor_selector"],
    )
    if rendered != script:
        raise RuntimeError("Startup script did not populate the CodeMirror editor")


def _accept_terms(page: Any, ui: dict[str, Any]) -> None:
    label = page.locator("label.el-checkbox").filter(
        has_text=ui["terms_label"]
    )
    visible = [item for item in label.all() if item.is_visible()]
    if not visible:
        return
    if "is-checked" not in (visible[0].get_attribute("class") or ""):
        visible[0].click()


def _selected_resource_row(
    page: Any, task: dict[str, Any], ui: dict[str, Any]
) -> Any:
    rows = page.locator(ui["resource_row_selector"]).filter(
        has_text=task["resource_group"]
    ).filter(has_text=task["accelerator"])
    for index in range(rows.count()):
        row = rows.nth(index)
        if not row.is_visible():
            continue
        radio = row.locator("input[type='radio']").first
        if radio.count() and radio.is_checked():
            return row
    raise RuntimeError("Configured resource row is not selected")


def _form_snapshot(
    page: Any, task: dict[str, Any], ui: dict[str, Any]
) -> dict[str, Any]:
    startup_script = page.evaluate(
        """selector => {
          const editor = [...document.querySelectorAll(selector)]
            .find(element => element.offsetParent !== null);
          return editor && editor.CodeMirror
            ? editor.CodeMirror.getValue()
            : null;
        }""",
        ui["startup_editor_selector"],
    )
    resource_row = _selected_resource_row(page, task, ui)
    region = page.get_by_role(
        "radio", name=task["region"], exact=True
    ).first
    cards = _form_item(page, ui["cards_label"], ui).get_by_role(
        "radio", name=str(task["cards"]), exact=True
    ).first
    instances = _form_item(page, ui["instances_label"], ui).locator(
        "input[role='spinbutton']"
    ).first
    auto_fault = _form_item(page, ui["auto_fault_label"], ui).locator(
        ".el-switch"
    ).first
    image = page.get_by_placeholder(ui["image_placeholder"])
    expected_image = ui["image_value_separator"].join(
        task["image"][key] for key in IMAGE_FIELDS
    )
    snapshot = {
        "name": page.locator(ui["task_name_selector"]).input_value(),
        "region": region.is_checked(),
        "resource_row": " ".join(resource_row.inner_text().split()),
        "cards": cards.is_checked(),
        "instances": int(instances.input_value()),
        "auto_fault": "is-checked"
        in (auto_fault.get_attribute("class") or ""),
        "image": image.input_value(),
        "startup_script": startup_script,
    }
    checks = {
        "name": snapshot["name"] == task["name"],
        "region": snapshot["region"],
        "cards": snapshot["cards"],
        "instances": snapshot["instances"] == int(task["instances"]),
        "auto_fault": snapshot["auto_fault"] == bool(task["auto_fault"]),
        "image": snapshot["image"] == expected_image,
        "startup_script": snapshot["startup_script"] == task["startup_script"],
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise RuntimeError(f"Rendered task form failed validation: {failed}")
    return snapshot


def _submit_one(
    page: Any,
    task: dict[str, Any],
    config: dict[str, Any],
    artifact_dir: Path,
    *,
    submit: bool,
) -> dict[str, Any]:
    browser_cfg = config["browser"]
    ui = browser_cfg["ui"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    page.goto(
        config["browser"]["model_training_url"],
        wait_until="domcontentloaded",
        timeout=timeout,
    )
    page.locator(ui["task_name_selector"]).wait_for(
        state="visible", timeout=timeout
    )
    page.locator(ui["task_name_selector"]).fill(task["name"])
    _select_region_and_resource(page, task, ui)
    _select_cards(page, int(task["cards"]), ui)
    _select_instances(page, int(task["instances"]), ui)
    _set_auto_fault(
        page,
        bool(task["auto_fault"]),
        int(task.get("auto_fault_retry_limit", 3)),
        ui,
    )
    _select_image(page, task["image"], ui)
    _fill_startup_script(page, task["startup_script"], ui)
    if task.get("accept_terms", True):
        _accept_terms(page, ui)
    form_snapshot = _form_snapshot(page, task, ui)
    (artifact_dir / f"{task['id']}_form.json").write_text(
        json.dumps(form_snapshot, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    try:
        page.screenshot(path=str(artifact_dir / f"{task['id']}_filled.png"))
    except Exception:
        print(
            f"Filled-form screenshot unavailable for {task['id']}; continuing.",
            file=sys.stderr,
            flush=True,
        )
    if not submit:
        return {"submitted": False, "reason": "dry_run"}

    create = page.get_by_role(
        "button", name=ui["create_button_name"], exact=True
    )
    _click_first_visible(create, timeout)
    deadline = time.monotonic() + timeout / 1000
    while time.monotonic() < deadline:
        # The create form and the task list share the same route prefix.
        # Wait until the create sub-route is gone rather than matching the
        # shared /model-training fragment immediately.
        if "/add-train" not in page.url:
            break
        page.wait_for_timeout(250)
    else:
        raise TimeoutError(
            "Task-creation page did not leave the add-train route; "
            f"current URL: {page.url}"
        )
    _click_first_visible(page.get_by_text(task["name"], exact=True), timeout)
    drawer = _first_visible(page.locator(".el-drawer"), timeout)
    drawer.wait_for(state="visible", timeout=timeout)
    page.wait_for_function(
        """() => [...document.querySelectorAll('.el-drawer')].some(
          node => node.offsetParent !== null && node.innerText.includes('ID')
        )""",
        timeout=timeout,
    )
    drawer_text = drawer.inner_text()
    details_text = drawer_text + "\n" + page.locator("body").inner_text()
    (artifact_dir / f"{task['id']}_details.txt").write_text(
        details_text,
        encoding="utf-8",
    )
    task_id_match = re.search(ui["task_id_regex"], details_text)
    status_match = re.search(ui["status_regex"], details_text)
    screenshot = artifact_dir / f"{task['id']}_submitted.png"
    try:
        page.screenshot(path=str(screenshot), full_page=True)
    except Exception:
        screenshot = None
    return {
        "submitted": True,
        "task_id": task_id_match.group(1) if task_id_match else None,
        "status": status_match.group(1) if status_match else None,
        "screenshot": str(screenshot),
    }


def run_browser(
    config: dict[str, Any],
    tasks: list[dict[str, Any]],
    *,
    submit: bool,
) -> list[dict[str, Any]]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "Playwright is not installed. Run: "
            "python -m pip install 'playwright>=1.50,<2'"
        ) from exc

    maximum = int(config.get("max_tasks_per_run", 4))
    if len(tasks) > maximum:
        raise ConfigError(
            f"Rendered task count {len(tasks)} exceeds max_tasks_per_run={maximum}"
        )
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    artifact_dir = Path(config.get("output_root", "runs/scnet_browser_submissions"))
    artifact_dir = (PROJECT_ROOT / artifact_dir).resolve() / run_stamp
    artifact_dir.mkdir(parents=True, exist_ok=True)
    results: list[dict[str, Any]] = []
    browser_cfg = config["browser"]
    channel = browser_cfg.get("channel", "msedge")
    profile_root = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    )

    with sync_playwright() as playwright:
        for account in sorted({task["account"] for task in tasks}):
            account_tasks = [task for task in tasks if task["account"] == account]
            profile_dir = profile_root / account
            profile_dir.mkdir(parents=True, exist_ok=True)
            context = playwright.chromium.launch_persistent_context(
                str(profile_dir),
                channel=channel,
                headless=bool(browser_cfg.get("headless", False)),
                slow_mo=int(browser_cfg.get("slow_mo_ms", 0)),
                viewport=_browser_viewport(browser_cfg),
            )
            try:
                page = context.pages[0] if context.pages else context.new_page()
                try:
                    _login(page, account_tasks[0], config)
                except Exception:
                    login_failure = artifact_dir / f"{account}_login_failed.png"
                    page.screenshot(path=str(login_failure), full_page=True)
                    raise
                for task in account_tasks:
                    plan = read_plan(task)
                    plan_path = artifact_dir / f"{task['id']}_plan.json"
                    plan_path.write_text(
                        json.dumps(plan, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8",
                    )
                    print(json.dumps(plan, ensure_ascii=False, indent=2))
                    try:
                        task_submits = bool(task.get("submit", True))
                        outcome = _submit_one(
                            page,
                            task,
                            config,
                            artifact_dir,
                            submit=submit and task_submits,
                        )
                        if not outcome.get("submitted"):
                            outcome["reason"] = (
                                "task_submit_disabled"
                                if submit and not task_submits
                                else "dry_run"
                            )
                    except Exception as exc:
                        failure = artifact_dir / f"{task['id']}_failed.png"
                        try:
                            page.screenshot(path=str(failure), full_page=True)
                        except Exception:
                            failure = None
                        raise RuntimeError(
                            f"Task {task['id']} failed; screenshot={failure or 'unavailable'}"
                        ) from exc
                    results.append(
                        {
                            "task_id": task["id"],
                            "name": task["name"],
                            "account": account,
                            **outcome,
                        }
                    )
            finally:
                context.close()

    (artifact_dir / "results.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Results: {artifact_dir / 'results.json'}")
    return results


def inspect_accounts(config: dict[str, Any]) -> list[dict[str, Any]]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "Playwright is not installed. Run: "
            "python -m pip install 'playwright>=1.50,<2'"
        ) from exc

    inspection = config.get("inspection", {})
    accounts = inspection.get("accounts")
    if not accounts:
        accounts = sorted({task["account"] for task in config["tasks"]})
    if not isinstance(accounts, list) or not accounts:
        raise ConfigError("inspection.accounts must be a non-empty array")

    browser_cfg = config["browser"]
    ui = browser_cfg["ui"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    artifact_dir = Path(config.get("output_root", "runs/scnet_browser_submissions"))
    artifact_dir = (PROJECT_ROOT / artifact_dir).resolve() / run_stamp
    artifact_dir.mkdir(parents=True, exist_ok=True)
    profile_root = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    )
    results = []

    with sync_playwright() as playwright:
        for account in accounts:
            account = str(account)
            profile_dir = profile_root / account
            profile_dir.mkdir(parents=True, exist_ok=True)
            context = playwright.chromium.launch_persistent_context(
                str(profile_dir),
                channel=browser_cfg.get("channel", "msedge"),
                headless=bool(browser_cfg.get("headless", False)),
                slow_mo=int(browser_cfg.get("slow_mo_ms", 0)),
                viewport=_browser_viewport(browser_cfg),
            )
            try:
                page = context.pages[0] if context.pages else context.new_page()
                _login(page, {"account": account}, config)
                page.goto(
                    browser_cfg["model_training_url"],
                    wait_until="domcontentloaded",
                    timeout=timeout,
                )
                page.locator(ui["task_name_selector"]).wait_for(
                    state="visible", timeout=timeout
                )
                label = page.get_by_text(
                    inspection.get("balance_label", "机时余量"), exact=True
                ).first
                label.wait_for(state="visible", timeout=timeout)
                value = label.locator("xpath=..").locator(
                    inspection.get(
                        "balance_value_selector",
                        ".el-descriptions-item__content",
                    )
                ).first
                page.wait_for_timeout(5000)
                deadline_ms = timeout
                waited_ms = 0
                while waited_ms < deadline_ms:
                    value_text = value.inner_text()
                    parsed = parse_account_inspection(
                        value_text,
                        inspection.get(
                            "balance_regex",
                            r"([0-9]+(?:\.[0-9]+)?)\s*卡\s*\*?\s*时",
                        ),
                    )
                    if parsed["balance_card_hours"] is not None:
                        break
                    page.wait_for_timeout(1000)
                    waited_ms += 1000
                value_text = value.inner_text()
                parsed = parse_account_inspection(
                    value_text,
                    inspection.get(
                        "balance_regex",
                        r"([0-9]+(?:\.[0-9]+)?)\s*卡\s*\*?\s*时",
                    ),
                )
                screenshot = artifact_dir / f"{account}_inspection.png"
                try:
                    page.screenshot(path=str(screenshot), full_page=True)
                except Exception:
                    screenshot = None
                result = {
                    "account": account,
                    "balance_text": value_text,
                    **parsed,
                    "screenshot": str(screenshot) if screenshot else None,
                }
            finally:
                context.close()
            (artifact_dir / f"{account}_inspection.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            results.append(result)

    (artifact_dir / "inspection_results.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return results


def inspect_job(
    config: dict[str, Any],
    account: str,
    job_name: str,
) -> dict[str, Any]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "Playwright is not installed. Run: "
            "python -m pip install 'playwright>=1.50,<2'"
        ) from exc

    browser_cfg = config["browser"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    artifact_dir = Path(config.get("output_root", "runs/scnet_browser_submissions"))
    artifact_dir = (PROJECT_ROOT / artifact_dir).resolve() / run_stamp
    artifact_dir.mkdir(parents=True, exist_ok=True)
    profile_dir = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    ) / account
    profile_dir.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as playwright:
        context = playwright.chromium.launch_persistent_context(
            str(profile_dir),
            channel=browser_cfg.get("channel", "msedge"),
            headless=bool(browser_cfg.get("headless", False)),
            slow_mo=int(browser_cfg.get("slow_mo_ms", 0)),
            viewport=_browser_viewport(browser_cfg),
        )
        try:
            page = context.pages[0] if context.pages else context.new_page()
            _login(page, {"account": account}, config)
            page.goto(
                browser_cfg["task_list_page_url"],
                wait_until="domcontentloaded",
                timeout=timeout,
            )
            page.wait_for_timeout(2000)
            row = _first_visible(
                page.locator(
                    browser_cfg["ui"].get("task_row_selector", "tr")
                ).filter(has_text=job_name)
            )
            row.wait_for(state="visible", timeout=timeout)
            row_html = row.evaluate("(el) => el.outerHTML")
            vue_dump = row.evaluate(
                """(el) => {
                    const ids = new Set();
                    const labels = {};
                    const seen = new WeakSet();
                    function visit(value, depth) {
                        if (value == null || depth > 5) return;
                        if (typeof value === "string") {
                            for (const match of value.matchAll(/\\d{15,24}/g)) {
                                ids.add(match[0]);
                            }
                            return;
                        }
                        if (typeof value !== "object") return;
                        if (seen.has(value)) return;
                        seen.add(value);
                        const keys = Array.isArray(value)
                            ? value.map((_, index) => index)
                            : Object.keys(value);
                        for (const key of keys.slice(0, 200)) {
                            if (
                                typeof key === "string" &&
                                /id|name|task|job|instance/i.test(key) &&
                                (typeof value[key] === "string" ||
                                    typeof value[key] === "number")
                            ) {
                                labels[key] = String(value[key]);
                            }
                            visit(value[key], depth + 1);
                        }
                    }
                    let node = el;
                    for (let level = 0; node && level < 10; level += 1) {
                        for (const key of Object.keys(node)) {
                            if (key.startsWith("__vue")) {
                                const vm = node[key];
                                visit(vm && vm.$props, 0);
                                visit(vm && vm.$data, 0);
                                visit(vm && vm.$parent && vm.$parent.$data, 0);
                            }
                        }
                        node = node.parentElement;
                    }
                    return {ids: Array.from(ids), labels};
                }"""
            )
            # Element UI duplicates the fixed columns into a separate table.
            # Click the visible fixed-column clone; the underlying row cell is
            # hidden behind it and cannot receive pointer events.
            fixed_name = page.locator(".el-table__fixed").get_by_text(
                job_name, exact=False
            )
            if fixed_name.count():
                try:
                    _first_visible(fixed_name).click(timeout=5_000, force=True)
                except Exception:
                    row.locator("td").nth(1).click(force=True)
            else:
                row.locator("td").nth(1).click(force=True)
            page.wait_for_timeout(2500)
            if len(context.pages) > 1:
                page = context.pages[-1]
            body_text = page.locator("body").inner_text()
            screenshot = artifact_dir / f"{job_name}_details.png"
            try:
                page.screenshot(path=str(screenshot), full_page=True)
            except Exception:
                screenshot = None
            final_url = page.url
        finally:
            context.close()
    result = {
        "account": account,
        "job_name": job_name,
        "url": final_url,
        "screenshot": str(screenshot) if screenshot else None,
        "body_text": body_text,
        "row_html": row_html,
        "vue_dump": vue_dump,
    }
    (artifact_dir / f"{job_name}_details.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(body_text)
    print(f"Details: {artifact_dir / f'{job_name}_details.json'}")
    return result


def list_jobs(config: dict[str, Any], account: str) -> list[dict[str, Any]]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "Playwright is not installed. Run: "
            "python -m pip install 'playwright>=1.50,<2'"
        ) from exc

    browser_cfg = config["browser"]
    ui = browser_cfg["ui"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    artifact_dir = Path(config.get("output_root", "runs/scnet_browser_submissions"))
    artifact_dir = (PROJECT_ROOT / artifact_dir).resolve() / run_stamp
    artifact_dir.mkdir(parents=True, exist_ok=True)
    profile_dir = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    ) / account
    profile_dir.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as playwright:
        context = playwright.chromium.launch_persistent_context(
            str(profile_dir),
            channel=browser_cfg.get("channel", "msedge"),
            headless=bool(browser_cfg.get("headless", False)),
            slow_mo=int(browser_cfg.get("slow_mo_ms", 0)),
            viewport=_browser_viewport(browser_cfg),
        )
        try:
            page = context.pages[0] if context.pages else context.new_page()
            _login(page, {"account": account}, config)
            page.goto(
                browser_cfg["task_list_page_url"],
                wait_until="domcontentloaded",
                timeout=timeout,
            )
            page.wait_for_timeout(2500)
            rows = page.locator(ui.get("task_row_selector", "tr"))
            values = []
            for index in range(rows.count()):
                row = rows.nth(index)
                if not row.is_visible():
                    continue
                text = " ".join(row.inner_text().split())
                if text:
                    values.append({"index": index, "text": text})
            screenshot = artifact_dir / f"{account}_jobs.png"
            try:
                page.screenshot(path=str(screenshot), full_page=True)
            except Exception:
                screenshot = None
            final_url = page.url
        finally:
            context.close()

    result = {
        "account": account,
        "url": final_url,
            "screenshot": str(screenshot) if screenshot else None,
        "rows": values,
    }
    (artifact_dir / f"{account}_jobs.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return values


def main() -> int:
    args = parse_args()
    config = load_config(Path(args.config))
    if args.list_jobs:
        if not args.account:
            raise ConfigError("--list-jobs requires --account")
        if args.headed:
            config["browser"]["headless"] = False
        if args.headless:
            config["browser"]["headless"] = True
        if args.no_prompt:
            config["browser"]["password_prompt"] = False
        list_jobs(config, args.account)
        return 0
    if args.inspect_job:
        if not args.account:
            raise ConfigError("--inspect-job requires --account")
        if args.headed:
            config["browser"]["headless"] = False
        if args.headless:
            config["browser"]["headless"] = True
        if args.no_prompt:
            config["browser"]["password_prompt"] = False
        inspect_job(config, args.account, args.inspect_job)
        return 0
    if args.inspect_accounts:
        if args.headed:
            config["browser"]["headless"] = False
        if args.headless:
            config["browser"]["headless"] = True
        if args.no_prompt:
            config["browser"]["password_prompt"] = False
        inspect_accounts(config)
        return 0
    if args.list_tasks:
        all_ids = [
            str(task.get("id", f"task-{index}"))
            for index, task in enumerate(config["tasks"])
        ]
        tasks = [
            render_tasks(config, [task_id])[0]
            for task_id in all_ids
        ]
        print(
            json.dumps(
                [
                    {
                        "id": task["id"],
                        "account": task["account"],
                        "name": task["name"],
                        "enabled": bool(task.get("enabled", True)),
                        "submit": bool(task.get("submit", True)),
                        "status": task.get("status"),
                        "submitted_task_id": task.get("submitted_task_id"),
                        "cards": int(task["cards"]),
                        "instances": int(task["instances"]),
                        "wall_hours": float(task["wall_hours"]),
                    }
                    for task in tasks
                ],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    tasks = render_tasks(config, args.task)
    if args.check_config:
        print(
            json.dumps(
                [read_plan(task) for task in tasks],
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    if not tasks:
        print("No enabled tasks matched the requested selection.")
        return 0
    if args.headed:
        config["browser"]["headless"] = False
    if args.headless:
        config["browser"]["headless"] = True
    if args.no_prompt:
        config["browser"]["password_prompt"] = False
    if args.submit:
        submit = True
    elif args.dry_run:
        submit = False
    else:
        submit = not bool(config.get("dry_run", True))
    if args.force_resubmit and not submit:
        raise ConfigError("--force-resubmit requires --submit or dry_run=false")
    validate_submission_guards(
        tasks,
        submit=submit,
        force_resubmit=bool(args.force_resubmit),
    )
    run_browser(config, tasks, submit=submit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
