#!/bin/sh
# Prints the T3 Code threads that are still working, and the latest one that just finished.
DIR="$HOME/.t3/userdata"
DB="$DIR/statev2.sqlite"
if [ ! -f "$DB" ]; then echo '{"count":0,"working":[],"show":false,"just_finished":false}'; exit 0; fi
# python3 ships with the Command Line Tools; without them /usr/bin/python3 would prompt to install.
xcode-select -p >/dev/null 2>&1 || { echo '{"count":0,"working":[],"show":false,"just_finished":false}'; exit 0; }
ENV_ID=$(cat "$DIR/environment-id" 2>/dev/null)
IN_T3=false
case "$CHOPSTICK_APP" in com.t3tools.t3code*) IN_T3=true ;; esac

sqlite3 -readonly -json -cmd ".timeout 1000" "file:$DB?mode=ro" "
WITH t AS (
  SELECT t.thread_id, t.title, p.title AS project
  FROM orchestration_v2_projection_threads t
  LEFT JOIN projection_projects p ON p.project_id = t.project_id
  WHERE t.deleted_at IS NULL AND t.archived_at IS NULL
    AND coalesce(json_extract(t.payload_json,'\$.lineage.relationshipToParent'),'') <> 'subagent'
),
active AS (
  SELECT t.thread_id, t.title, t.project, max(r.status = 'waiting') AS waiting,
         min(coalesce(json_extract(r.payload_json,'\$.startedAt'), r.requested_at)) AS since
  FROM orchestration_v2_projection_runs r JOIN t USING(thread_id)
  WHERE r.status IN ('queued','preparing','starting','running','waiting')
  GROUP BY t.thread_id
),
done AS (
  SELECT t.thread_id, t.title, t.project, r.status, r.completed_at
  FROM orchestration_v2_projection_runs r JOIN t USING(thread_id)
  WHERE r.completed_at > strftime('%Y-%m-%dT%H:%M:%fZ','now','-20 seconds')
    AND r.status IN ('completed','failed','interrupted')
    AND r.thread_id NOT IN (SELECT thread_id FROM active)
  ORDER BY r.completed_at DESC LIMIT 1
)
SELECT 'a' AS kind, thread_id, title, project, waiting, since, NULL AS status FROM active
UNION ALL
SELECT 'd', thread_id, title, project, 0, completed_at, status FROM done;
" 2>/dev/null | /usr/bin/python3 -I -c '
import json, sys, datetime
env, in_t3 = sys.argv[1], sys.argv[2] == "true"
try: rows = json.loads(sys.stdin.read() or "[]")
except Exception: rows = []
now = datetime.datetime.now(datetime.timezone.utc)
def ago(ts):
    try: s = int((now - datetime.datetime.fromisoformat(ts.replace("Z","+00:00"))).total_seconds())
    except Exception: return ""
    return f"{s}s" if s < 60 else f"{s//60}m" if s < 3600 else f"{s//3600}h {s%3600//60}m"
def link(r): return "t3code://threads/" + env + "/" + r["thread_id"]
working = sorted([r for r in rows if r["kind"] == "a"], key=lambda r: r["since"] or "")
items = [{"title": r["title"] or "Untitled thread",
          "subtitle": ("Needs you · " if r["waiting"] else "Working · ") + (r["project"] or "") + (" · " + ago(r["since"]) if r["since"] else ""),
          "symbol": "hand.raised.fill" if r["waiting"] else "sparkles",
          "url": link(r)} for r in working]
done = next((r for r in rows if r["kind"] == "d"), None)
fin = {}
if done:
    st = done["status"]
    fin = {"title": done["title"] or "Untitled thread", "project": done["project"] or "", "url": link(done),
           "label": "Finished" if st == "completed" else "Failed" if st == "failed" else "Stopped",
           "symbol": "checkmark.circle.fill" if st == "completed" else "xmark.octagon.fill",
           "tint": "green" if st == "completed" else "red"}
print(json.dumps({"hint": "Click a thread to jump to it." if items else "No T3 Code threads working.", "count": len(items), "working": items, "first": items[0] if items else {},
                  "show": bool(items) and not in_t3,
                  "just_finished": bool(done) and not in_t3, "finished": fin}))
' "$ENV_ID" "$IN_T3"
