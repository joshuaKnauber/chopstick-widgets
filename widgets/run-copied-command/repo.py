"""Prints the folder of the T3 Code thread the copied text came from.

Looks through the most recently active threads for an assistant message that
contains the text; falls back to the most recently active thread.
Usage: python3 -I repo.py "<copied text>"
"""
import json, os, sqlite3, sys

text = sys.argv[1].strip() if len(sys.argv) > 1 else ""
db = os.path.expanduser("~/.t3/userdata/statev2.sqlite")
try:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)
    threads = con.execute(
        "select thread_id, project_id, json_extract(payload_json,'$.worktreePath') "
        "from orchestration_v2_projection_threads "
        "where deleted_at is null and archived_at is null "
        "order by updated_at desc limit 15").fetchall()
    pick = threads[0] if threads else None
    if text:
        for t in threads:
            hit = con.execute(
                "select 1 from orchestration_v2_projection_messages "
                "where thread_id = ? and role = 'assistant' "
                "and instr(json_extract(payload_json,'$.text'), ?) > 0 "
                "order by created_at desc limit 1", (t[0], text)).fetchone()
            if hit:
                pick = t
                break
    path = None
    if pick:
        path = pick[2]
        if not path or not os.path.isdir(path):
            row = con.execute("select workspace_root from projection_projects where project_id = ?",
                              (pick[1],)).fetchone()
            path = row[0] if row else None
    if path and os.path.isdir(path):
        print(path)
except Exception:
    pass
