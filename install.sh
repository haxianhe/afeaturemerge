#!/bin/bash
set -e

echo "Installing afeaturemerge..."

mkdir -p ~/.claude/skills/afeaturemerge/hooks

curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/SKILL.md \
  -o ~/.claude/skills/afeaturemerge/SKILL.md

curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/hooks/afeaturemerge-sync.sh \
  -o ~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh
chmod +x ~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh

python3 <<'PYEOF'
import json, os

p = os.path.expanduser('~/.claude/settings.json')
try:
    with open(p) as f:
        s = json.load(f)
except Exception:
    s = {}

entry = {
    'matcher': 'Write|Edit',
    'hooks': [{
        'type': 'command',
        'command': os.path.expanduser('~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh'),
        'timeout': 30
    }]
}

hooks = s.setdefault('hooks', {})
ptu = hooks.setdefault('PostToolUse', [])

if not any('afeaturemerge-sync.sh' in str(e) for e in ptu):
    ptu.append(entry)
    with open(p, 'w') as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
    print('Hook configured in ~/.claude/settings.json')
else:
    print('Hook already configured, skipped.')
PYEOF

echo ""
echo "Done. Restart Claude Code to activate."
