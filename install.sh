#!/bin/bash

FAILED_ITEMS=()

echo "Installing afeaturemerge..."
echo ""

# ── 前置依赖检查 ──────────────────────────────────────────────────────────────
echo "检查前置依赖..."

MISSING=()
command -v git     &>/dev/null || MISSING+=("git")
command -v python3 &>/dev/null || MISSING+=("python3")
command -v curl    &>/dev/null || MISSING+=("curl")

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "✗ 缺少必要工具：${MISSING[*]}"
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "  建议：brew install ${MISSING[*]}"
    else
        echo "  建议：sudo apt-get install ${MISSING[*]}"
    fi
    exit 1
fi
echo "  ✓ git / python3 / curl"
echo ""

# ── 依赖 1：SearXNG（本地服务）+ sxng-cli（CLI 前端）────────────────────────
echo "[1/2] 检查 SearXNG + sxng-cli..."

SEARXNG_DIR="$HOME/.local/share/searxng"
SEARXNG_LOG="$SEARXNG_DIR/searxng.log"

# 查找 Python 3.10+（SearXNG 要求）
# 优先查找带版本号的命令，再找 Homebrew，最后 fallback 到 python3
PYTHON3=""
for _py in python3.13 python3.12 python3.11 python3.10 \
           /opt/homebrew/bin/python3 /usr/local/bin/python3 python3; do
    if command -v "$_py" &>/dev/null; then
        _ver=$("$_py" -c "import sys; print(sys.version_info[:2])" 2>/dev/null)
        # 检查是否 >= (3, 10)
        if "$_py" -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" 2>/dev/null; then
            PYTHON3="$_py"
            break
        fi
    fi
done

if [ -z "$PYTHON3" ]; then
    echo "  ✗ 未找到 Python 3.10+，SearXNG 安装跳过"
    echo "    macOS：brew install python@3.11"
    echo "    Linux：sudo apt-get install python3.11"
    FAILED_ITEMS+=("Python 3.10+（SearXNG 依赖）")
fi

# — 1a. clone 源码 —
if [ -d "$SEARXNG_DIR/.git" ]; then
    echo "  ✓ SearXNG 源码已存在（$SEARXNG_DIR）"
else
    echo "  正在 clone SearXNG 源码..."
    if git clone https://github.com/searxng/searxng "$SEARXNG_DIR"; then
        echo "  ✓ clone 完成"
    else
        echo "  ✗ clone 失败，请检查网络后重试"
        FAILED_ITEMS+=("SearXNG 源码 clone")
    fi
fi

# — 1b. pip install（仅在找到合适 Python 时执行）—
if [ -z "$PYTHON3" ]; then
    echo "  ⚠ 跳过 SearXNG 安装（无 Python 3.10+）"
elif "$PYTHON3" -c "import searx" &>/dev/null; then
    echo "  ✓ searx Python 包已安装（使用 $PYTHON3）"
elif [ -d "$SEARXNG_DIR" ]; then
    echo "  正在安装 Python 依赖（使用 $PYTHON3）..."
    # 升级 pip
    "$PYTHON3" -m pip install --upgrade pip --quiet 2>/dev/null || true
    # 预装 setup.py 解析时需要的依赖（msgspec + pyyaml）
    # 配合 --no-build-isolation 让 pip 跳过隔离环境，从而能找到这些已安装的包
    "$PYTHON3" -m pip install msgspec pyyaml --quiet 2>/dev/null || \
    "$PYTHON3" -m pip install --break-system-packages msgspec pyyaml --quiet 2>/dev/null || true
    # 安装 SearXNG（不用 -e，build backend 不支持 editable 模式）
    "$PYTHON3" -m pip install --no-build-isolation "$SEARXNG_DIR" 2>/dev/null || \
    "$PYTHON3" -m pip install --no-build-isolation --break-system-packages "$SEARXNG_DIR" 2>/dev/null || \
    "$PYTHON3" -m pip install --no-build-isolation --user "$SEARXNG_DIR" 2>/dev/null || true

    # 以实际 import 结果判断，而非 pip 退出码
    if "$PYTHON3" -c "import searx" &>/dev/null; then
        echo "  ✓ Python 依赖安装完成"
    else
        echo "  ✗ 安装后仍无法导入 searx，请手动排查："
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "    brew install libxml2 libxslt openssl"
            echo "    $PYTHON3 -m pip install $SEARXNG_DIR"
        else
            echo "    sudo apt-get install python3-dev libxml2-dev libxslt-dev"
            echo "    $PYTHON3 -m pip install $SEARXNG_DIR"
        fi
        FAILED_ITEMS+=("searx Python 依赖")
    fi
fi

# — 1c. 自动启动配置（仅 searx 可用时注册）—
if "$PYTHON3" -c "import searx" &>/dev/null; then

if [[ "$(uname)" == "Darwin" ]]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/com.afeaturemerge.searxng.plist"
    if [ ! -f "$PLIST_PATH" ]; then
        mkdir -p "$HOME/Library/LaunchAgents"
        cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.afeaturemerge.searxng</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(command -v "$PYTHON3")</string>
        <string>-m</string>
        <string>searx.webapp</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$SEARXNG_LOG</string>
    <key>StandardErrorPath</key>
    <string>$SEARXNG_LOG</string>
</dict>
</plist>
EOF
        # macOS Ventura+ 用 bootstrap，旧版 fallback 到 load
        if launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || \
           launchctl load "$PLIST_PATH" 2>/dev/null; then
            echo "  ✓ 已注册 macOS LaunchAgent（开机自动启动）"
        else
            echo "  ⚠ LaunchAgent 注册失败，SearXNG 不会开机自启"
        fi
    else
        echo "  ✓ LaunchAgent 已存在，跳过"
    fi
else
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SYSTEMD_DIR/searxng.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        mkdir -p "$SYSTEMD_DIR"
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=SearXNG (afeaturemerge)
After=network.target

[Service]
Type=simple
ExecStart=$(command -v "$PYTHON3") -m searx.webapp
Restart=always
RestartSec=5
StandardOutput=append:$SEARXNG_LOG
StandardError=append:$SEARXNG_LOG

[Install]
WantedBy=default.target
EOF
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable searxng 2>/dev/null || true
        if systemctl --user start searxng 2>/dev/null; then
            echo "  ✓ 已注册 systemd 用户服务（开机自动启动）"
        else
            echo "  ⚠ systemd 服务启动失败：journalctl --user -u searxng -n 20"
        fi
    else
        echo "  ✓ systemd 服务已存在，跳过"
    fi
fi

# — 1d. 检查服务是否就绪（最多等 30 秒）—
echo "  等待 SearXNG 启动..."
READY=0
for i in $(seq 1 15); do
    if curl -s --max-time 2 http://127.0.0.1:8080 &>/dev/null; then
        echo "  ✓ SearXNG 运行中（http://127.0.0.1:8080）"
        READY=1
        break
    fi
    sleep 2
done

if [ "$READY" -eq 0 ]; then
    echo "  ⚠ SearXNG 30 秒内未就绪"
    echo "    排查：tail -20 $SEARXNG_LOG"
    echo "         lsof -i :8080"
    FAILED_ITEMS+=("SearXNG 服务启动")
fi

else
    echo "  ⚠ searx 不可用，跳过服务注册和启动"
fi # end: if searx importable

# — 1e. sxng-cli —
if command -v sxng &>/dev/null; then
    echo "  ✓ sxng 已安装"
elif ! command -v npm &>/dev/null; then
    echo "  ✗ 未检测到 npm，请安装 Node.js 后重新运行脚本"
    echo "    https://nodejs.org/"
    FAILED_ITEMS+=("sxng-cli（缺少 npm）")
else
    echo "  正在安装 sxng-cli..."
    if npm install -g sxng-cli; then
        echo "  ✓ sxng-cli 安装完成"
    else
        echo "  ✗ sxng-cli 安装失败，请手动运行：npm install -g sxng-cli"
        FAILED_ITEMS+=("sxng-cli 安装")
    fi
fi

# — 1f. sxng 配置（指向本地实例）—
SXNG_CONFIG_DIR="$HOME/sxng-cli"
SXNG_CONFIG_FILE="$SXNG_CONFIG_DIR/sxng.config.json"
if [ ! -f "$SXNG_CONFIG_FILE" ]; then
    mkdir -p "$SXNG_CONFIG_DIR"
    cat > "$SXNG_CONFIG_FILE" <<'EOF'
{
  "baseUrl": "http://127.0.0.1:8080",
  "defaultEngine": "",
  "allowedEngines": [],
  "defaultLimit": 10,
  "useProxy": false,
  "proxyUrl": "",
  "timeout": 10000
}
EOF
    echo "  ✓ 已写入 sxng 配置（指向 http://127.0.0.1:8080）"
else
    echo "  ✓ sxng 配置已存在，跳过"
fi
echo ""

# ── 依赖 2：superpowers（brainstorming skill）─────────────────────────────────
echo "[2/2] 检查 superpowers MCP（brainstorming skill）..."

if ! command -v claude &>/dev/null; then
    echo "  ✗ 未检测到 claude CLI，请先安装 Claude Code"
    echo "    https://claude.ai/code"
    FAILED_ITEMS+=("superpowers MCP（缺少 claude CLI）")
elif claude mcp list 2>/dev/null | grep -q "superpowers"; then
    echo "  ✓ superpowers 已配置，跳过"
else
    echo "  未检测到 superpowers，正在配置..."
    if claude mcp add superpowers -- npx -y @superpower-sh/cli@latest; then
        echo "  ✓ superpowers 配置完成"
    else
        echo "  ✗ superpowers 配置失败，请手动运行："
        echo "      claude mcp add superpowers -- npx -y @superpower-sh/cli@latest"
        FAILED_ITEMS+=("superpowers MCP")
    fi
fi
echo ""

# ── Skill 文件 ────────────────────────────────────────────────────────────────
BASE_URL="https://raw.githubusercontent.com/haxianhe/afeaturemerge/main"

# afeaturemerge skill
echo "Installing afeaturemerge skill..."
mkdir -p ~/.claude/skills/afeaturemerge/hooks

if curl -sSL "$BASE_URL/skills/afeaturemerge/SKILL.md" \
       -o ~/.claude/skills/afeaturemerge/SKILL.md && \
   curl -sSL "$BASE_URL/hooks/afeaturemerge-sync.sh" \
       -o ~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh; then
    chmod +x ~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh
    echo "  ✓ afeaturemerge skill 下载完成"
else
    echo "  ✗ afeaturemerge skill 下载失败，请检查网络后重试"
    FAILED_ITEMS+=("afeaturemerge skill 下载")
fi

# feature-extra skill
echo "Installing feature-extra skill..."
mkdir -p ~/.claude/skills/feature-extra

if curl -sSL "$BASE_URL/skills/feature-extra/SKILL.md" \
       -o ~/.claude/skills/feature-extra/SKILL.md; then
    echo "  ✓ feature-extra skill 下载完成"
else
    echo "  ✗ feature-extra skill 下载失败，请检查网络后重试"
    FAILED_ITEMS+=("feature-extra skill 下载")
fi

python3 <<'PYEOF'
import json, os, sys

p = os.path.expanduser('~/.claude/settings.json')
try:
    if os.path.exists(p):
        with open(p) as f:
            s = json.load(f)
    else:
        s = {}
except json.JSONDecodeError as e:
    print(f'  ✗ {p} JSON 格式有误：{e}', file=sys.stderr)
    print('    请手动检查并修复该文件', file=sys.stderr)
    sys.exit(1)

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
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as f:
            json.dump(s, f, indent=2, ensure_ascii=False)
        print('  ✓ Hook 已写入 ~/.claude/settings.json')
    except Exception as e:
        print(f'  ✗ 写入 settings.json 失败：{e}', file=sys.stderr)
        sys.exit(1)
else:
    print('  ✓ Hook 已存在，跳过')
PYEOF

# ── 安装总结 ──────────────────────────────────────────────────────────────────
echo ""
if [ ${#FAILED_ITEMS[@]} -eq 0 ]; then
    echo "✓ 安装完成！重启 Claude Code 后即可使用 afeaturemerge。"
else
    echo "⚠ 安装完成，但以下组件需要手动处理："
    for item in "${FAILED_ITEMS[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "  修复后重新运行："
    echo "  curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
"
fi
