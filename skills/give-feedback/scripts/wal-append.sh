#!/usr/bin/env bash
# Appends one formatted entry block to the global feedback WAL and prints
# the assigned R### ID. The caller keeps the judgment (clustering, rule
# text, whether the rule earns an active-rules line); this script owns ID
# assignment and byte-level formatting so entries are structurally valid
# by construction.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: wal-append.sh --title T --kind K --rule R --instance I
                     [--instance I]... [--scope S] [--relates-to IDS] [--active]

  --kind        one of: code-style, workflow, environment
                (domain feedback routes to project memory, not this WAL)
  --scope       scope hint (default: general)
  --relates-to  comma-separated R### IDs (default: —)
  --active      also append "- R###: rule" to active-rules.md
EOF
  exit 2
}

title="" kind="" scope="general" rule="" relates="—" active=0
instances=()
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title=$2; shift 2 ;;
    --kind) kind=$2; shift 2 ;;
    --scope) scope=$2; shift 2 ;;
    --rule) rule=$2; shift 2 ;;
    --instance) instances+=("$2"); shift 2 ;;
    --relates-to) relates=$2; shift 2 ;;
    --active) active=1; shift ;;
    *) usage ;;
  esac
done

[ -n "$title" ] && [ -n "$rule" ] && [ ${#instances[@]} -gt 0 ] || usage
case "$kind" in code-style|workflow|environment) ;; *) usage ;; esac

dir="$HOME/.claude/feedback/global"
wal="$dir/wal.md"
mkdir -p "$dir"
[ -f "$wal" ] || printf '# Feedback WAL\n' > "$wal"

last=$(grep -oE '^## R[0-9]+' "$wal" | tr -dc '0-9\n' | sort -n | tail -n 1 || true)
id=$(printf 'R%03d' $((10#${last:-0} + 1)))

{
  printf '\n## %s — %s\n' "$id" "$title"
  printf 'created: %s | kind: %s | scope: %s\n' "$(date +%F)" "$kind" "$scope"
  printf 'relates-to: %s\n' "$relates"
  printf 'rule: %s\n' "$rule"
  printf 'instances:\n'
  for i in "${instances[@]}"; do printf -- '- %s\n' "$i"; done
} >> "$wal"

if [ "$active" -eq 1 ]; then
  ar="$dir/active-rules.md"
  [ -f "$ar" ] || printf '# Provisional rules (from recent feedback; obey like committed rules)\n' > "$ar"
  printf -- '- %s: %s\n' "$id" "$rule" >> "$ar"
fi

echo "$id"
