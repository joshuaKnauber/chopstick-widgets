# Runs the command in the repo it was copied for, output (stdout + stderr) streamed.
dir="$CHOPSTICK_REPO"
[ -n "$dir" ] || dir=$(/usr/bin/python3 -I repo.py "")
dir="${dir:-$HOME}"
cd "$dir" || { echo "Folder not found: $dir" >&2; exit 1; }
exec /bin/zsh -lc "$CHOPSTICK_CMD" </dev/null 2>&1
