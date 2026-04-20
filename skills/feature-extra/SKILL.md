---
name: feature-extra
description: |
  从开源项目/代码库中提取功能模块，规范化为标准模块包（module.json + spec.md + interface.yaml）。适用场景：
  - 用户说"从 X 项目提取 Y 功能模块"
  - 用户说"把这个开源项目的某功能规范化成可复用模块"
  - 用户提供 GitHub URL / 本地路径，希望提取某个功能的模块规范
  - 用户说"分析 [项目]，把 [功能] 提取成标准模块"
  - 任何需要"分析源码/文档 → 识别功能边界 → 产出标准模块规范"的任务
---

# feature-extraction

从开源项目中 AI 自动识别功能边界，提取并规范化为标准模块包，产出 `module.json` + `spec.md` + `interface.yaml`（+ 可选参考实现），供后续组合复用。

---

## 第一步：信息收集与确认

### 解析清单

从用户消息中提取：

| 信息项 | 若缺失，如何处理 |
|-------|--------------|
| 源项目（URL / 本地路径 / 名称） | **必须追问**，无法继续 |
| 目标功能名称 | **必须追问**，无法继续 |
| 目标技术栈（提取参考实现时） | 不追问；默认以源码技术栈为准，标注支持栈 |
| 模块 ID 命名 | 不追问；根据功能名自动生成（`kebab-case`，如 `user-auth-jwt`） |

### 理解摘要模板

解析完成后，展示摘要并使用 `AskUserQuestion` 确认：

> 我的理解：
> - 源项目：**[项目名/URL/路径]**
> - 提取目标：**[功能名称]**
> - 模块 ID（自动生成）：**[module-id]**
> - 产出路径：**`docs/modules/[module-id]/`**

```
AskUserQuestion({
  questions: [{
    header: "确认信息",
    question: "以上理解是否正确？",
    multiSelect: false,
    options: [
      { label: "确认，开始提取", description: "信息无误，立即开始分析" },
      { label: "需要调整", description: "请在 Other 文本框中说明" }
    ]
  }]
})
```

<HARD-GATE>
未展示摘要并收到用户确认前，不得开始分析。
</HARD-GATE>

---

## 第二步：功能边界分析

**使用 `Agent` 工具启动一个 subagent（subagent_type: Explore）深度分析源项目。**

将以下 prompt 模板中的占位符替换为真实值后下发：

```
你是一个代码分析 agent，任务是从 {源项目} 中分析 {功能名} 的实现，提取功能边界。

分析目标（按顺序完成）：

1. 功能边界识别
   - 这个功能的入口点在哪里（API / 入口函数 / 事件）？
   - 这个功能的出口是什么（返回值 / 回调 / 副作用）？
   - 哪些是这个功能"内部的"，哪些是"外部依赖"？

2. 接口梳理（对外暴露的 API）
   - 接口名称、入参、出参
   - 触发的事件或回调
   - 数据模型（请求 / 响应结构）

3. 依赖识别
   - 必须依赖的其他模块或能力（如"需要用户系统"）
   - 与其他功能互斥的约束（如"和 session-auth 不能共存"）

4. 技术栈识别
   - 源码使用的语言/框架
   - 核心实现文件路径列表（精选，不超过 5 个）
   - 关键实现代码片段（最能说明实现逻辑的 20-50 行）

分析资源：
- 若源项目为 GitHub URL：用 WebFetch 抓取 README、关键源文件
- 若源项目为本地路径：用 Glob + Grep + Read 搜索
- WebSearch 搜索官方文档（如有）

要求：
- 结论基于实际代码，不猜测
- 只返回结构化分析报告，不要返回完整原始文件
```

subagent 完成后，在主 context 汇总结构化报告，不要将原始内容搬入。

---

## 第三步：产出标准模块包

基于分析结果，产出 4 个文件。**每个文件完成后立即写入** `docs/modules/[module-id]/`。

### 文件一：module.json（元数据）

```json
{
  "id": "[module-id]",
  "name": "[人类可读名称]",
  "version": "0.1.0",
  "description": "[一句话功能描述]",
  "category": "[auth|payment|messaging|storage|notification|analytics|other]",
  "source": {
    "project": "[源项目名]",
    "url": "[源项目 URL，若有]",
    "extracted_at": "[YYYY-MM-DD]"
  },
  "dependencies": ["[依赖的其他 module-id，若无则为空数组]"],
  "conflicts": ["[互斥的 module-id，若无则为空数组]"],
  "supported_stacks": ["[java|python|nodejs|go|其他]"],
  "ai_generatable": true
}
```

### 文件二：spec.md（功能规范）

```markdown
# [模块名] — 功能规范

> 模块 ID：[module-id]
> 版本：0.1.0
> 提取来源：[源项目名] ([YYYY-MM-DD])

## 这个模块做什么

[2-3 句话：完成什么用户场景，解决什么问题]

## 功能边界

### 包含（In Scope）
- [功能点 1]
- [功能点 2]

### 不包含（Out of Scope）
- [不做的事 1]（原因：[简短说明]）

## 数据模型

[核心数据结构，使用伪代码或 JSON Schema 描述]

## 行为规范

[关键行为约束，如"token 过期后必须返回 401"、"密码必须哈希存储"]

## 边界条件与错误处理

[异常情况和处理方式]
```

### 文件三：interface.yaml（接口契约）

```yaml
module_id: [module-id]
version: "0.1.0"

apis:
  - method: [GET|POST|PUT|DELETE]
    path: "[路径，如 /auth/login]"
    description: "[接口描述]"
    request:
      body:
        - name: "[字段名]"
          type: "[string|number|boolean|object]"
          required: [true|false]
          description: "[说明]"
    response:
      success:
        status: [200|201|...]
        body:
          - name: "[字段名]"
            type: "[类型]"
            description: "[说明]"
      errors:
        - status: [400|401|403|404|500]
          description: "[错误说明]"

events:
  emits:
    - name: "[事件名，如 user.login.success]"
      description: "[触发时机]"
      payload:
        - name: "[字段]"
          type: "[类型]"
  listens:
    - name: "[监听的事件，若无则省略此节]"

dependencies:
  requires:
    - module_id: "[依赖 module-id]"
      reason: "[为什么依赖]"
  conflicts:
    - module_id: "[互斥 module-id]"
      reason: "[为什么互斥]"
```

### 文件四：impls/[tech-stack]/reference.md（参考实现摘要）

从源码中精选最能说明实现逻辑的代码片段，格式：

```markdown
# [模块名] — [tech-stack] 参考实现

> 来源：[源项目名] / [文件路径]

## 核心实现逻辑

[关键代码片段，附注释说明设计决策]

## 集成说明

[如何将此模块集成到目标项目，关键步骤]
```

---

## 产出目录结构

```
docs/modules/[module-id]/
├── module.json          # 元数据
├── spec.md              # 功能规范
├── interface.yaml       # 接口契约
└── impls/
    └── [tech-stack]/
        └── reference.md # 参考实现摘要
```

---

## 质量标准

- **接口完整**：`interface.yaml` 中的每个 API 都有请求/响应/错误定义
- **边界清晰**：`spec.md` 明确列出 In Scope / Out of Scope
- **依赖可解**：`module.json` 中 `dependencies` 不得包含无法独立实现的闭源系统
- **代码有据**：`reference.md` 中的代码片段必须来自实际源码
- **ID 规范**：`module-id` 使用 `kebab-case`，格式为 `[功能类别]-[具体能力]`（如 `auth-jwt`、`payment-stripe`）

---

## 资源不足时的处理

| 情况 | 处理方式 |
|------|---------|
| 源项目为闭源/私有 | 说明情况，请用户提供相关文档或代码片段 |
| GitHub URL 无法访问 | 改用 `sxng --engines bing` 搜索项目文档 |
| 功能边界不清晰 | 用 `AskUserQuestion` 确认关键边界（如"是否包含权限管理？"） |
| 接口文档缺失 | 从源码推导，在 `interface.yaml` 中标注 `inferred: true` |
| 技术栈混合 | 在 `module.json` 的 `supported_stacks` 中列出所有检测到的栈 |

---

## 示例触发

**示例一（GitHub URL）**：
> 「从 https://github.com/supertokens/supertokens-core 提取 JWT 用户认证模块」

执行顺序：
1. 解析：源项目 = supertokens-core，功能 = JWT 用户认证，module-id = `auth-jwt`
2. 展示摘要，等待用户确认
3. 启动 subagent 分析 GitHub 仓库（WebFetch README + 核心文件）
4. 产出 `module.json` → 写入
5. 产出 `spec.md` → 写入
6. 产出 `interface.yaml` → 写入
7. 产出 `impls/java/reference.md` → 写入

**示例二（本地路径）**：
> 「分析 ~/projects/my-app/src/auth，把 JWT 认证部分提取成标准模块」

执行顺序：
1. 解析：源项目 = 本地路径 `~/projects/my-app/src/auth`，功能 = JWT 认证
2. 展示摘要确认
3. subagent 用 Glob + Grep + Read 分析本地代码
4. 产出四个标准文件
