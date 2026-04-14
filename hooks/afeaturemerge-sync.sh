#!/bin/bash
# afeaturemerge-sync.sh
# PostToolUse hook：检测写入 docs/afeaturemerge/，自动触发云端知识库同步提示
#
# 安装：curl -sSL https://raw.githubusercontent.com/haxianhe/afeaturemerge/main/install.sh | bash
# 配置示例（~/.claude/settings.json）：
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "matcher": "Write|Edit",
#           "hooks": [{ "type": "command", "command": "~/.claude/skills/afeaturemerge/hooks/afeaturemerge-sync.sh", "timeout": 30 }]
#         }
#       ]
#     }
#   }

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# 检测是否写入 docs/afeaturemerge/ 目录（匹配任意项目下的相对路径）
if [[ "$FILE_PATH" == */docs/afeaturemerge/* ]]; then
    MSG="文件已保存：$FILE_PATH。请立即将此文件同步到云端知识库，并告知用户结果：若当前 session 有可用的知识库 MCP 工具（如钉钉、语雀、Confluence 等），执行同步：若本次任务尚未建立任务文件夹则先创建，再在文件夹下创建文档；若没有任何可用的知识库 MCP 工具，告知用户：文件已保存到本地 $FILE_PATH，未检测到云端知识库 MCP，未同步云端。如需同步，请配置对应的 MCP 工具。"
    jq -n --arg msg "$MSG" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
fi

exit 0
