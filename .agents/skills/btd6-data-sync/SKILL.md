---
name: btd6-data-sync
description: '同步并审计本仓库的 BTD6 内容数据、中文翻译和 Insta 素材。Use when: BTD6 版本更新、新英雄或猴塔无法识别、当前活动显示英文或分类错误、收集活动轮换错误、开箱缺图、需要对齐 BTD6ApiExplorer。'
license: MIT
---

# BTD6 内容数据同步

将 `BTD6ApiExplorer/BTD6ApiExplorer.github.io` 作为内容目录和资源参考，更新本仓库所有消费同一批 BTD6 数据的功能。目标不是只修复一个名称，而是让活动解析、收集轮换、开箱模拟、翻译和素材保持同一内容版本。

## 数据源与基线

1. 将参考仓库浅克隆到 `mktemp -d` 创建的临时目录，或使用用户指定的本地副本。不要把参考仓库或运行时输出写入工作树。
2. 记录参考提交 SHA、提交时间、`data/Constants.json` 中的 `version` 和 `projectContentVersion`。
3. 重点读取 `towersInOrder`、`heroesInOrder`、`mapsInOrder`、`bossesInOrder` 和 `collection.towerOrder`。
4. 参考项目不提供可靠中文名时，不要凭空宣称官方译名。优先沿用仓库既有中文风格；无法确认时保留英文 ID，并明确说明。

## 先审计再修改

运行只读审计脚本：

```bash
python3 .agents/skills/btd6-data-sync/scripts/audit_btd6_content.py \
  --reference <BTD6ApiExplorer目录> \
  --plugin-root plugins/btd6bot_plugin
```

审计输出用于确定缺项，但不能代替源码搜索。用 `rg` 搜索新增 ID、旧版最新 ID、`TOWER_POOL`、`TOWER_CATEGORIES`、翻译表和素材解析函数，确认所有消费者。特别检查三个嵌套组件：

- `btd6_api_processor`：活动规则分类、活动/地图/Boss 翻译、收集轮换及其素材。
- `ChatMonkeyTD`：开箱随机池及其素材。
- `btd6_knowledge_base`：用户问法和中英文别名。

## 更新约束

- `collection.towerOrder` 是参与带种子洗牌的有序协议。必须逐项保持参考顺序，禁止排序、改成集合或只断言包含新增塔；顺序变化会让整期轮换结果错位。
- 活动解析中的类别应与 `towersInOrder[*].category` 对齐，同时保留上游历史拼写兼容项。未知未来 ID 仍应走现有 fail-soft 路径，不能让整个活动失败。
- `ChatMonkeyTD` 的 `Wizard` 是本地素材命名兼容，不应机械改成 `WizardMonkey`，除非同时迁移素材解析契约。
- 每个普通猴塔有 16 个 Insta 路径码：`000 001 002 003 004 005 010 020 030 040 050 100 200 300 400 500`。新增塔必须同步到 `btd6_api_processor/assets/InstaMonkeyIcon/` 和 `ChatMonkeyTD/assets/InstaMonkeyIcon/`。
- 复制参考项目二进制素材前核对其许可和来源；只复制功能实际需要的文件，不批量导入整个资源库。
- 翻译表同时兼容参考项目当前规范 ID 和已被上游使用过的旧 ID。例如大小写、英美拼写或历史内部名变化不应破坏旧快照。
- 不修改缓存索引、生成图片、活动快照或其他运行时输出。发现旧缓存影响验证时，说明其影响；除非用户明确授权，不删除缓存。

## 验证

至少验证以下行为：

1. 新猴塔在活动 `_towers` 中得到正确中文名、类别和可用状态；新英雄由 `isHero` 正确识别。
2. 收集池与参考 `collection.towerOrder` 完全相等，并用固定事件 ID 验证确定性轮换；不要只测 `in`。
3. 开箱池能抽到新增塔，16 个路径码都能解析，至少实际合成一张非空图片。
4. 翻译解析器能读取新增塔、英雄、地图和 Boss，而不是只检查 Markdown 文本存在。
5. 运行活动处理组件和插件主测试集，再运行审计脚本确认无差异。
6. 在每个嵌套 Git 仓库内执行 `git diff --check` 和 `git status --short`。父仓库只显示小写 `m`，不能据此判断实际改动内容。

最终报告应列出参考提交与内容版本、各消费者的变更、素材数量、测试结果，以及未能确认的翻译或未执行的联网验证。
