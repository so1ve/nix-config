# 设计依据与范例取舍

用于解释或修订教学方式。以下列出本 skill 参考的规范、教学建议和公开范例。社区技能可提供设计思路，其教学效果仍需验证。链接核查日期：2026-10-15。

## Skill 编写规范

- [Agent Skills 格式规范](https://agentskills.io/specification)：采用 name、description 和 Markdown 正文；将可选参考文件与核心流程分开，提供直接引用。保持跨工具可理解，不依赖某一个模型的专有工具名。
- [Agent Skills 编写最佳实践](https://agentskills.io/skill-creation/best-practices)：保持单一任务范围，写出可执行程序及清晰默认行为；按实际失败修订，避免穷举假想边界。这里把“读脚本—提炼要求—串联知识—讲对应题”视为一项完整任务。
- [Anthropic Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)：明确触发条件，控制正文长度，用代表任务检查行为。来源和题号使用严格规则；教学顺序和篇幅允许随材料变化，不锁定固定章节数。

## 教学设计依据

[IES：Organizing Instruction and Study to Improve Student Learning](https://ies.ed.gov/ncee/wwc/practiceguide/1) 汇总了交替学习完整例题与独立解题、连接抽象与具体表征、结合图文、提问与主动回忆等建议。该指南分别给出证据等级，不应把所有建议说成同样强的结论。

在本 skill 中，用完整题解说明怎样应用概念，在关键步骤解释理由，再用改变条件的短变式说明方法怎样调整。按用户的精讲需求，自检设为可选，不要求答对才能继续。上述建议支持示范与练习结合，不能据此声称阅读讲义可以替代练习。

## 教学类 Skill 范例

| 范例 | 可参考的设计 | 本 skill 的取舍 |
|---|---|---|
| [GraceLiao77 / lecture-to-summary-skills](https://github.com/GraceLiao77/lecture-to-summary-skills/blob/main/SKILL.md) | 合并课件与转写稿，关注口头补充与教师强调 | 以脚本为主要来源，区分课堂重点和明确考试要求；保留串联段落和必要题解，不把全部内容压成孤立短条目 |
| [Jellypod / lecture-to-study-guide](https://github.com/Jellypod-Inc/school-skills/blob/main/skills/lecture-to-study-guide/SKILL.md) | 接受多种课堂材料，关联概念、例题与复习输出 | 根据新解题决策选题，不固定生成一大批练习，也不要求每次都画关系图 |
| [GarethManning / Backwards Design Unit Planner](https://github.com/GarethManning/education-agent-skills/blob/main/skills/curriculum-assessment/backwards-design-unit-planner/SKILL.md) | 从目标和评估任务反推教学安排，并检查对应关系 | 把“掌握”落实成解释、判断、计算或证明等动作，再选择例题；不扩张成整学期教学管理 |
| [GarethManning / Explicit Instruction Sequence Builder](https://github.com/GarethManning/education-agent-skills/blob/main/skills/explicit-instruction/explicit-instruction-sequence-builder/SKILL.md) | 从示范到引导练习，再到独立应用 | 默认完整示范加简短迁移；需要互动练习时再逐渐减少提示，避免强制用户进入训练流程 |

## 文字优化

采用用户的 [speak-plainly](https://github.com/so1ve/nix-config/blob/main/dotfiles/agents/skills/speak-plainly/SKILL.md)：先整理内容，再修改句子，删除重复和空话，保留事实、因果、条件及不确定性。课程讲义用段落连接概念，用表格比较方法，用列表呈现步骤。不要为每个知识点重复同一套栏目。

## 修订时检查

- 若输出知识点齐全却难读，先修复概念之间的连接，不再添加栏目。
- 若用户说“太精简”，优先补方法选择和跳过的推导；若说“太多”，先去掉重复和与当前题目无关的补充。
- 若学生只会照抄原题，增加一个改变方法适用条件的对比例；不要只更换数字。
- 若材料不支持具体考试或评分结论，改为说明学习动作与推导中的必要环节，不编造“必考”或某步分值。
- 检查生成结果能否让读者回答：这个概念解决什么问题，接在什么知识后，看到什么条件采用什么方法，为什么这样做。
