import json
import sys
from pathlib import Path

task_id, submitted_id, submitted_name = sys.argv[1], sys.argv[2], sys.argv[3]
path = Path("configs/scnet_browser_tasks.json")
data = json.loads(path.read_text(encoding="utf-8"))

hits = [task for task in data["tasks"] if task.get("id") == task_id]
if len(hits) != 1:
    raise SystemExit(f"expected exactly one task {task_id}, found {len(hits)}")

task = hits[0]
task["submit"] = False
task["submitted_task_id"] = submitted_id
task["submitted_name"] = submitted_name
task["status"] = "submitted_20261109_014409"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(
    f"{task_id} submit=False submitted_task_id={submitted_id} "
    f"name={submitted_name}"
)
