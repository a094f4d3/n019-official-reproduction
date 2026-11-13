"""Stop one SCNet AI training job through the headless console UI."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from datetime import datetime
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
HELPER_PATH = PROJECT_ROOT / "scripts" / "scnet_browser_tasks.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("scnet_browser_tasks", HELPER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import {HELPER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="configs/scnet_browser_tasks.json")
    parser.add_argument("--account", required=True)
    parser.add_argument("--job-name", required=True)
    args = parser.parse_args()

    helper = load_helper()
    from playwright.sync_api import sync_playwright

    config = helper.load_config((PROJECT_ROOT / args.config).resolve())
    browser_cfg = config["browser"]
    timeout = int(browser_cfg.get("timeout_ms", 60000))
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_root = Path(config.get("output_root", "runs/scnet_browser_submissions"))
    artifact_dir = (PROJECT_ROOT / output_root).resolve() / run_stamp
    artifact_dir.mkdir(parents=True, exist_ok=True)
    profile_dir = Path(
        os.path.expandvars(os.path.expanduser(browser_cfg["profile_root"]))
    ) / args.account

    with sync_playwright() as playwright:
        context = playwright.chromium.launch_persistent_context(
            str(profile_dir),
            channel=browser_cfg.get("channel", "msedge"),
            headless=True,
            slow_mo=int(browser_cfg.get("slow_mo_ms", 0)),
            viewport=helper._browser_viewport(browser_cfg),
        )
        try:
            page = context.pages[0] if context.pages else context.new_page()
            helper._login(page, {"account": args.account}, config)
            page.goto(
                browser_cfg["task_list_page_url"],
                wait_until="domcontentloaded",
                timeout=timeout,
            )
            page.wait_for_timeout(2000)
            row = helper._first_visible(
                page.locator(
                    browser_cfg["ui"].get("task_row_selector", "tr")
                ).filter(has_text=args.job_name)
            )
            row.wait_for(state="visible", timeout=timeout)
            fixed_name = page.locator(".el-table__fixed").get_by_text(
                args.job_name,
                exact=False,
            )
            if fixed_name.count():
                helper._first_visible(fixed_name).click(timeout=5_000, force=True)
            else:
                row.locator("td").nth(1).click(force=True)
            page.wait_for_timeout(2500)
            if len(context.pages) > 1:
                page = context.pages[-1]

            body = page.locator("body").inner_text()
            if args.job_name not in body:
                raise RuntimeError("Job detail page does not show the requested name")

            stop = page.get_by_text("停止", exact=True)
            if not stop.count():
                raise RuntimeError("No visible 停止 control on the job detail page")
            helper._first_visible(stop).click(timeout=10_000)
            page.wait_for_timeout(1000)

            for label in ("确定", "确认", "停止"):
                confirm = page.get_by_role("button", name=label, exact=True)
                if confirm.count():
                    try:
                        helper._first_visible(confirm).click(timeout=5_000)
                        break
                    except Exception:
                        continue
            page.wait_for_timeout(3000)
            screenshot = artifact_dir / f"{args.job_name}_stop.png"
            page.screenshot(path=str(screenshot), full_page=True)
            result = {
                "account": args.account,
                "job_name": args.job_name,
                "stopped_at": datetime.now().isoformat(),
                "url": page.url,
                "screenshot": str(screenshot),
                "body_tail": page.locator("body").inner_text()[-3000:],
            }
            (artifact_dir / "stop_result.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(json.dumps(result, ensure_ascii=False, indent=2))
        finally:
            context.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
