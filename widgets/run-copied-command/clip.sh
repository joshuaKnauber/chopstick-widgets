# Reports whether the clipboard holds a shell command, and which repo
# (the T3 Code thread it came from) to run it in.
text=$(pbpaste 2>/dev/null | head -c 2000)
first=$(printf '%s' "$text" | sed -n '/[^[:space:]]/{s/^[[:space:]]*//;s/^\$ //;p;q;}')
if printf '%s' "$first" | grep -Eq '^(npx|npm|pnpm|yarn|bun|bunx|node|cd|git|gh|wrangler|curl|ls|make|docker|brew|python3?|pip3?|cargo|swift|xcodebuild|rm|mv|cp|mkdir|cat|echo|export|sh|bash|zsh)( |$)'; then
  /usr/bin/python3 -I -c '
import json, os, subprocess, sys
t = sys.argv[1].strip()
t = "\n".join(l[2:] if l.startswith("$ ") else l for l in t.splitlines())
repo = subprocess.run(["/usr/bin/python3", "-I", "repo.py", t], capture_output=True, text=True).stdout.strip()
home = os.path.expanduser("~")
print(json.dumps({"is_cmd": True, "cmd": t, "first": sys.argv[2], "repo": repo,
                  "repo_name": os.path.basename(repo) if repo else "",
                  "repo_short": repo.replace(home, "~", 1) if repo else ""}))' "$text" "$first"
else
  echo '{"is_cmd": false}'
fi
