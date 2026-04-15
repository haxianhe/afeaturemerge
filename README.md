# afeaturemerge

> 参考竞品/框架/系统，将其功能融入自身系统的全流程分析与实现规划 Skill。

---

## 这是什么

`afeaturemerge` 是一个 Claude Code Skill，帮你完成这样一件事：

**看到别的系统有个好功能，想在自己系统里实现它** → 从调研到落地方案，一气呵成。

它会自动完成：调研参考系统的实现原理 + 分析你现有系统的状态 + 对比差距 + 产出需求文档和技术方案。

---

## 系统要求

- **Python 3.11+**
- **Node.js**（含 npm）
- **git**
- **curl**

---

## 安装

```bash
curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
```

脚本自动完成所有配置，无需手动安装任何依赖：

| 步骤 | 内容 |
|------|------|
| SearXNG | `git clone` 源码 → `pip install -e` → 注册系统服务（开机自启） |
| sxng-cli | `npm install -g sxng-cli` → 写入配置指向 `http://127.0.0.1:8080` |
| superpowers | `claude mcp add superpowers`（含 `brainstorming` skill） |
| Skill 文件 | 下载到 `~/.claude/skills/afeaturemerge/` |
| Hook | 写入 `~/.claude/settings.json`（文档写入后自动触发知识库同步） |

安装完成后，**重启 Claude Code** 即可生效。

### 通过 git clone 安装

```bash
git clone https://github.com/haxianhe/afeaturemerge.git /tmp/afeaturemerge && \
  bash /tmp/afeaturemerge/install.sh
```

### 更新

重新执行安装命令即可（已有配置自动跳过）：

```bash
curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
```

---

## 验证安装

开启新的 Claude Code 会话，说一句：

```
参考 LangChain 的 Memory 机制，在我的项目里实现会话记忆功能
```

如果 Claude 能识别并开始询问参考系统和目标应用的信息，说明 Skill 已生效。

---

## 使用

安装完成后无需任何额外配置。当你说出以下这类话时，Claude 会**自动激活**这个 Skill：

| 你说的话 | 示例 |
|---------|------|
| 参考 X 的 Y 功能，在我们系统里实现 | "参考 LangChain 的 Memory 机制，在我们的对话服务里实现会话记忆" |
| 调研 X 是怎么做 Y 的，给出实现方案 | "调研 Spring AI 的 ToolCall 实现，给出我们的接入方案" |
| 我想实现类似 X 的 Y 功能 | "我想实现类似 OpenAI Assistants API 的 Thread 多轮对话" |
| 对标/参考/借鉴某系统并希望落地 | "对标 Dify 的工作流引擎，在我们系统里实现类似能力" |

**核心判断标准**：任务包含"研究参考系统 → 分析自身现状 → 产出实现计划"这三个环节时，就该用这个 Skill。

---

## 工作流程

```
用户输入
   ↓
① 信息确认
   Claude 解析参考系统、目标应用，展示理解摘要，等你确认
   ↓
② 并行调研
   ├─ A. 调研参考系统（文档、代码、API 设计）
   └─ B. 调研你的现有系统（现有实现、局限、位置）
   ↓
③ 产出三份文档 → 写入 docs/afeaturemerge/
   文档一：参考系统功能分析
   文档二：现有系统现状分析
   文档三：实现方案（含对比表 + 需求 + 技术方案）
   ↓
④ 云端知识库同步（hook 自动触发）
```

---

## 产出物

### 文档一：参考系统分析
- 核心设计理念（为什么这样设计）
- 关键接口 / API
- 典型代码示例
- 已知限制

### 文档二：现有系统现状
- 当前有无类似实现
- 核心类/文件位置
- 现有实现的不足

### 文档三：实现方案（核心文档）

| 功能点 | 参考系统 | 我们系统 | 是否可参考 |
|--------|---------|---------|-----------|
| 功能 A | ✅ 支持 | ❌ 无 | ✅ 可直接参考 |
| 功能 B | ✅ 支持 | ⚠️ 部分 | ✅ 可参考改造 |
| 功能 C | ✅ 支持 | ❌ 无 | ❌ 不可参考（依赖闭源组件）|

每个功能块配套：
- **需求文档**：要实现什么、用户价值、验收标准
- **技术方案**：具体步骤、涉及模块、代码改动范围

---

## 故障排查

**SearXNG 未就绪**

```bash
# 查看启动日志
tail -50 ~/.local/share/searxng/searxng.log

# 检查端口是否被占用
lsof -i :8080

# 手动启动（验证是否能正常运行）
python3 -m searx.webapp
```

**macOS：SearXNG 服务未自动启动**

```bash
# 手动加载 LaunchAgent
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.afeaturemerge.searxng.plist

# 查看服务状态
launchctl print gui/$(id -u)/com.afeaturemerge.searxng
```

**Linux：SearXNG 服务未自动启动**

```bash
# 查看服务状态
systemctl --user status searxng

# 查看日志
journalctl --user -u searxng -n 50
```

**pip install 失败（Python 3.11+）**

```bash
pip3 install --break-system-packages -e ~/.local/share/searxng
```

**superpowers MCP 配置失败**

```bash
claude mcp add superpowers -- npx -y @superpower-sh/cli@latest
```

---

## 常见问题

**Q：参考系统没有公开文档怎么办？**

告诉 Claude 这是内部系统，提供相关文档链接或描述功能即可。Claude 会据此调整调研策略。

**Q：我不确定目标是哪个模块，可以让 Claude 帮我判断吗？**

可以。如果你没有明确指定，Claude 会用交互式选项让你选择，或者直接从代码库中搜索最相关的模块。

**Q：最终文档会保存在哪里？**

保存到当前项目的 `docs/afeaturemerge/` 目录（跟着项目走，可纳入版本控制）。若配置了云端同步 hook，每份文档写入后会自动提示同步到对应知识库。

**Q：如果参考系统和我们系统差距极小，还会产出文档吗？**

会。Claude 会如实说明差距很小，并指出哪些可以直接复用，避免重复造轮子。

---

## 相关项目

- [superpowers](https://github.com/superpowers-sh/superpowers)：提供 `brainstorming` skill，afeaturemerge 在产出方案时自动调用
- [SearXNG](https://github.com/searxng/searxng)：本地搜索服务，`WebSearch` 不可用时的搜索兜底
- [sxng-cli](https://github.com/hkwuks/sxng-cli)：SearXNG 的命令行前端

---

## Star History

[![Star History Chart](https://api.star-history.com/chart?repos=haxianhe/afeaturemerge&type=date&legend=top-left)](https://www.star-history.com/?repos=haxianhe%2Fafeaturemerge&type=date&legend=top-left)
