import json
import sys
from pathlib import Path

task_id, value, status = sys.argv[1], sys.argv[2].lower() == "true", sys.argv[3]
path = Path("configs/scnet_browser_tasks.json")
data = json.loads(path.read_text(encoding="utf-8"))

hits = [task for task in data["tasks"] if task.get("id") == task_id]
if len(hits) != 1:
    raise SystemExit(f"expected exactly one task {task_id}, found {len(hits)}")

hits[0]["submit"] = value
hits[0]["status"] = status
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"{task_id} submit={value} status={status}")
