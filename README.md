# afeaturemerge

> 两个 Claude Code Skill，帮你把别人的好功能变成自己的。

---

## Skills

### `afeaturemerge` — 特性迁移

**看到别的系统有个好功能，想在自己系统里实现它。**

从调研到落地方案，一气呵成：调研参考系统的实现原理 → 分析你的现有系统 → 对比差距 → 产出需求文档和技术方案。

**触发示例**：

| 说法 | 示例 |
|------|------|
| 参考 X 的 Y 功能，在我们系统里实现 | "参考 LangChain 的 Memory 机制，在我们的对话服务里实现会话记忆" |
| 调研 X 是怎么做 Y 的，给出实现方案 | "调研 Spring AI 的 ToolCall 实现，给出我们的接入方案" |
| 我想实现类似 X 的 Y 功能 | "我想实现类似 OpenAI Assistants API 的 Thread 多轮对话" |
| 对标/参考/借鉴某系统并希望落地 | "对标 Dify 的工作流引擎，在我们系统里实现类似能力" |

**工作流程**：

```
① 信息确认 — 解析参考系统、目标应用，展示摘要，等你确认
② 并行调研 — A. 调研参考系统（文档、代码、API）
              B. 调研你的现有系统（实现、局限、位置）
③ 产出三份文档 → docs/afeaturemerge/
   · 参考系统功能分析
   · 现有系统现状分析
   · 实现方案（对比表 + 需求文档 + 技术方案）
```

**产出物示例**（文档三·对比表）：

| 功能点 | 参考系统 | 我们系统 | 是否可参考 |
|--------|---------|---------|-----------|
| 功能 A | ✅ 支持 | ❌ 无 | ✅ 可直接参考 |
| 功能 B | ✅ 支持 | ⚠️ 部分 | ✅ 可参考改造 |
| 功能 C | ✅ 支持 | ❌ 无 | ❌ 不可参考（依赖闭源组件）|

---

### `feature-extra` — 功能提取

**想把开源项目的某个功能提取成标准可复用模块。**

分析源码，输出标准模块包：识别功能边界 → 产出 `module.json` + `spec.md` + `interface.yaml` + 参考实现摘要。

**触发示例**：

| 说法 | 示例 |
|------|------|
| 从 X 项目提取 Y 功能模块 | "从 supertokens-core 提取 JWT 用户认证模块" |
| 把这个开源项目的某功能规范化成可复用模块 | "把 Stripe 的支付集成部分提取成标准模块" |
| 分析 [路径]，提取 [功能] | "分析 ~/projects/my-app/src/auth，提取 JWT 认证部分" |

**工作流程**：

```
① 信息确认 — 解析源项目、目标功能，自动生成 module-id，等你确认
② 功能边界分析 — subagent 分析源码/文档，识别接口、依赖、实现逻辑
③ 产出标准模块包 → docs/modules/[module-id]/
   · module.json    — 元数据、依赖声明、支持的技术栈
   · spec.md        — 功能规范（In Scope / Out of Scope）
   · interface.yaml — 接口契约（API、事件、依赖关系）
   · impls/[stack]/reference.md — 参考实现代码摘要
```

---

## 系统要求

- **Python 3.10+**
- **Node.js**（含 npm）
- **git**
- **curl**

---

## 安装

```bash
curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
```

脚本自动完成所有配置：

| 步骤 | 内容 |
|------|------|
| SearXNG | clone 源码 → pip install → 注册系统服务（开机自启） |
| sxng-cli | `npm install -g sxng-cli` → 写入配置 |
| superpowers | `claude mcp add superpowers`（含 `brainstorming` skill） |
| Skill 文件 | 下载 `afeaturemerge` + `feature-extra` 到 `~/.claude/skills/` |
| Hook | 写入 `~/.claude/settings.json`（文档写入后自动提示知识库同步） |

安装完成后，**重启 Claude Code** 即可生效。

### 通过 git clone 安装

```bash
git clone https://github.com/haxianhe/afeaturemerge.git /tmp/afeaturemerge && \
  bash /tmp/afeaturemerge/install.sh
```

### 更新

```bash
curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
```

---

## 验证安装

**验证 afeaturemerge**：开启新会话，说：

```
参考 LangChain 的 Memory 机制，在我的项目里实现会话记忆功能
```

**验证 feature-extra**：开启新会话，说：

```
从 https://github.com/supertokens/supertokens-core 提取 JWT 认证模块
```

Claude 能识别并开始收集信息，说明 Skill 已生效。

---

## 故障排查

**SearXNG 未就绪**

```bash
tail -50 ~/.local/share/searxng/searxng.log
lsof -i :8080
python3 -m searx.webapp   # 手动启动验证
```

**macOS：SearXNG 服务未自动启动**

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.afeaturemerge.searxng.plist
launchctl print gui/$(id -u)/com.afeaturemerge.searxng
```

**Linux：SearXNG 服务未自动启动**

```bash
systemctl --user status searxng
journalctl --user -u searxng -n 50
```

**pip install 失败**

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

告诉 Claude 这是内部系统，提供相关文档链接或描述功能即可，Claude 会调整调研策略。

**Q：我不确定用哪个 skill？**

- 想在**自己系统里实现**某功能 → `afeaturemerge`
- 想把开源项目的功能**提取成独立模块**供复用 → `feature-extra`

**Q：我不知道参考哪个开源项目，Claude 能推荐吗？**

可以。直接说"我想加 X 功能但不知道参考哪个项目"，Claude 会自动搜索并列出候选项让你选。

**Q：文档保存在哪里？**

- `afeaturemerge`：`docs/afeaturemerge/`
- `feature-extra`：`docs/modules/[module-id]/`

两者都跟着项目走，可纳入版本控制。

---

## 相关项目

- [superpowers](https://github.com/superpowers-sh/superpowers)：提供 `brainstorming` skill，afeaturemerge 在产出方案时自动调用
- [SearXNG](https://github.com/searxng/searxng)：本地搜索服务，`WebSearch` 不可用时的搜索兜底
- [sxng-cli](https://github.com/hkwuks/sxng-cli)：SearXNG 的命令行前端

---

## Star History

[![Star History Chart](https://api.star-history.com/chart?repos=haxianhe/afeaturemerge&type=date&legend=top-left)](https://www.star-history.com/?repos=haxianhe%2Fafeaturemerge&type=date&legend=top-left)
