# 背包幸存者

一款融合了背包乱斗和吸血鬼幸存者的rouglike游戏，旨在为玩家提供构筑背包装备搭配体系的策略感，同时能体会到刷怪割草的爽感

## TODO

- 背包系统
  - [x] 进入游戏根据玩家所选角色创建对应背包网格以及初始武器
  - [x] 装备区存储玩家正在使用的装备
  - [x] 存储区存储玩家未来可能会用到的装备
- 商店系统
  - [x] 商店包含5个商品货架放置装备供玩家购买
  - [x] 根据当前地图节点刷新商店刷新池--不同阶段能够刷新的装备不同
  - [x] 商店刷新
  - [ ] 商店添加背包网格购买状态，供玩家购买背包中的网格
- 地图系统
  - [ ] 一场对局包含3层地图，每层地图有多个地图节点，节点之间有路径，玩家可先预览地图再选择路径
  - [x] 地图节点与地图之间的刷新逻辑
- 锻造系统
  - [x] 根据锻造配置表，玩家在锻造台网格中放置多个装备，若能够锻造出更高级装备，则能够在结果网格中预览该装备
  - [x] 玩家点击锻造，根据配置表，消耗锻造台中的装备，在结果网格中生成高级装备
  - [x] 锻造界面网格与背包网格之间装备的交互逻辑
- 战斗系统
  - 玩家装备类型
    - [x] 旋转装备：玩家装备后，该装备会围绕玩家身体按照配置的**旋转半径**和**旋转速度**进行旋转
    - [x] 发射装备：玩家装备后，该装备会根据配置的射击间隔和**射击速度**，**检测半径**和**子弹速度**发射子弹
    - [x] 范围装备：玩家装备后，该装备会根据配置的**范围区域**和**触发间隔**触发范围伤害
    - [ ] 饰品装备：玩家装备后，根据装备配置的数值给予玩家对应数值的增加
    - [ ] 防御装备：玩家装备后，根据装备配置的**旋转半径**，**旋转速度**和**再生间隔**添加能够抵挡敌人弹幕的装备
  - 敌人怪物类型
    - [x] 追逐怪物：全图锁定玩家位置，开始直线追逐
    - [x] 发射怪物：找到玩家位置，然后当玩家进入攻击范围，开始发射弹幕
    - [ ] 敌怪生成逻辑

## 系统拆解

### 1. 总体架构

项目采用 Godot 的“场景 + 脚本 + Autoload”组织方式，并按职责分为四层：

- **表现层**：`scene/` 保存页面、组件和战斗实体场景，`scripts/game/module/*/view/` 负责输入、动画和界面刷新。
- **领域层**：`Equipment`、`MapNode`、`AttrContainer` 等运行时对象承载装备、地图节点和属性数据。
- **系统层**：`GameState`、`BackpackManager`、`MapManager`、`CombatManager` 作为 Autoload，维护跨场景状态并通过信号协调模块。
- **配置层**：`config/*.csv` 保存策划数据，`GameConfig` 在启动时统一加载并转换为强类型 Data 对象和嵌套字典。

主要目录：

```text
config/                  CSV 游戏配置
scene/                   主界面、地图、商店、锻造、战斗及实体场景
scripts/game/config/     配置加载器与 Data 类型
scripts/game/module/     按业务模块组织的数据、系统和表现脚本
scripts/game/utility/    场景切换、轮播容器和调试工具
assets/                  图片、动画、音频、字体等资源
addons/                  SceneManager、PhantomCamera 等第三方插件
```

### 2. 游戏主流程

```text
主菜单
  → 角色选择
  → GameState.start_run(character_id)
  → 初始化角色、背包和第 1 张地图
  → 地图选点
      ├─ BATTLE → 战斗 → 结算 → 返回地图/进入下一张地图/结束游戏
      ├─ SHOP   → 商店购买与整理背包 → 返回地图/地图结算
      └─ FORGE  → 装备合成与整理背包 → 返回地图/地图结算
```

`GameState` 统一校验阶段并处理新局、节点进入、结算、继续、重试和返回菜单。`gaming.gd` 订阅 `phase_changed` 显示面板；节点按钮只提交请求，动画结束不再写进度。地图、库存、单场战斗分别由 `MapManager`、`BackpackManager`、`CombatManager` 保存，跨场景延续当前对局。

### 3. 配置与数据模块

`GameConfig` 保留装备、角色、怪物、拾取物、商店、配方、战斗和地图八组查询接口，正式配置统一来自一个 `ConfigSnapshot`。运行时代码只读取配置；金币、装备实例、地图访问状态仍属于各业务 Manager。没有新增 Autoload、修改 CSV 格式或修改第三方导入插件。

```text
scripts/game/config/
  game_config.gd                 配置就绪检查、加载入口、完整快照发布
  data/config_snapshot.gd        八张表的 Data 对象索引
  data/config_issue.gd           单条错误或警告及其来源
  data/config_load_result.gd     加载结果、候选快照和问题列表
  data/*_data.gd                 现有配置类型及转换函数
  sys/config_loader.gd          导入资源适配、表结构声明、候选索引构建
  sys/config_validator.gd       原始字段、资源及跨表业务校验
```

数据链路为：`CSV → 导入资源 records → 全表原始字段校验 → Data 转换 → 候选 ConfigSnapshot → 跨表校验 → 一次性发布 → GameState 允许进入游戏`。原始记录格式有错时汇总各表问题，不再基于不完整对象执行后续跨表检查。合法表的组合键仍允许父级重复，例如同一个 MapID 下可以有多层、多节点；完整组合重复则报错，不能静默保留第一条。

`GameConfig.ensure_loaded()` 是正常启动与查询前的就绪入口，加载成功后不重复加载。首次失败保持未就绪且不发布任何表，修正并重新导入资源后可以重试。`load_configuration()` 为显式启动/工具入口，不提供游戏中的热更新 UI；失败的替换保留上一次完整快照。`GameState` 在启动、进入角色选择、开局和失败重试时接入检查，错误时保留当前进度。原先手动调用静态 `GameConfig._init()` 的位置已改为 `ensure_loaded()`。

校验覆盖：

- 必填字段、整数范围、有限数值、属性格式、重复属性、形状为等宽 0/1 矩阵且包含占用格；角色背包尺寸及初始装备的实际放置。
- 装备类型、显式发射器/子弹类型、射击/范围装备的必要参数、角色和怪物 HP。
- 角色初始装备、商店货架、配方材料/产物、战斗怪物，以及地图商店/战斗节点的跨表引用；相同材料及数量对应不同配方会报告歧义。
- 同波次时限一致、地图起点存在、连接指向后续层的有效节点、非末层不出现无出口节点。无法从起点到达的节点产生警告。
- 资源路径存在且能够加载为预期类型：Texture2D、SpriteFrames、Shape2D 或可实例化的 PackedScene。

完整键分别为普通表的 `ID`、配方表的 `EquipmentID`、战斗表的 `ID + WaveID + MonsterID`、地图表的 `MapID + LayerIndex + NodeIndex`。诊断包含严重程度、错误码、文件、记录序号、记录键、字段和原因；记录序号从 1 开始，指数据记录，不冒充 CSV 物理行号。界面展示前 8 条问题，完整报告输出到日志；未知数值属性和不可达节点属于警告，不阻止发布。

兼容现有规则：允许没有下一张地图、可选角色立绘为空、零怪物波次、零刷新间隔、无锻造配方；省略发射器/子弹类型时继续使用既有默认值。锻造节点不把 ConfigID 当作商店 ID。启动固定依赖地图 1，战斗金币掉落固定依赖 ID=1、Type=GOLD 的拾取配置，这两项也纳入校验。各业务入口的防御检查继续保留。

测试不修改实际 CSV：`ConfigLoader` 可接受独立记录数据源。`tests/config/config_validation_test.tscn` 覆盖正式数据、非法字段、完整键重复、资源类型、引用、配方与地图规则；`config_loading_test.tscn` 覆盖首次失败、重试恢复、原快照保留和开局/重试阻断。

```shell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_project_test.gd -- res://tests/config/config_validation_test.tscn
godot --headless --path . --script res://tests/run_project_test.gd -- res://tests/config/config_loading_test.tscn
```

编辑器手动验收：在临时副本中制造重复装备 ID、错误商店装备引用或不存在的资源路径，重新导入并运行，确认报告包含配置位置且不能开始对局；还原配置并重新导入后重试，确认可以进入角色选择和开始游戏。通过后的正式配置按只读约定使用，旧字典查询接口仍兼容现有业务和隔离测试，未宣称所有 Data 对象在语言层面不可变。

### 4. 全局状态与场景模块

主流程目录：

```text
scripts/game/module/main/
  data/run_state.gd        对局编号、角色、阶段、累计拾取金币、绑定的战斗编号
  data/run_settlement.gd   结算编号、胜负、累计金币、下一步动作及下一张地图编号
  sys/run_flow.gd          纯结算规则，不读取或修改界面和地图
  sys/game_state.gd        对局入口、阶段校验、跨模块操作及通知
  sys/scene_router.gd      场景资源预检、切换锁和 SceneManager 适配
  view/                   主菜单、角色选择、对局面板和结算展示
```

`RunState` 阶段为 `MENU / CHARACTER_SELECT / MAP / SHOP / FORGE / BATTLE / SETTLEMENT / TRANSITIONING`。场景切换及同步通知过程中拒绝重复导航。`SceneRouter` 是 `GameState` 的普通子节点；`RunFlow` 为普通规则类，没有新增 Autoload 或修改插件。

入口为 `show_character_select()`、`start_run(character_id)`、`enter_map_node(map_id, layer, index)`、`leave_current_node()`、`complete_battle(result, source_run_id)`、`continue_run(settlement_id)`、`retry_run(settlement_id)` 和 `return_to_menu()`。返回布尔值表示请求是否接受；资源或配置错误通过 `request_failed` 和提示框反馈，重复点击直接忽略。

数据链路：

```text
UI 输入 → GameState 校验当前阶段与配置
  → MapManager 校验当前地图成员、连接和访问状态
  → BackpackManager 打开货架 / 取消材料选择
  → SceneRouter 预先实例化目标场景
  → 旧场景退出，新场景入树时提交进度，新场景子节点 ready
  → phase_changed → Gaming / PanelManager 展示当前阶段

CombatManager.battle_ended(BattleResult)
  → battle.gd 携带来源对局编号提交 GameState（不依赖 HUD）
  → 校验对局编号、绑定战斗编号和正式战斗结果
  → RunFlow → RunSettlement → GameOver 展示副本
  → 玩家点击继续/重试 → GameState 核对结算编号 → 明确推进或重建本局
```

结算显示和重复刷新不推进地图。普通胜利返回原地图，末层胜利进入下一张已配置地图或结束本局；末层商店/锻造退出也执行该规则。下一张地图保留装备实例、金币和累计统计。失败重试保留角色，创建新对局编号，重置背包、货架、锻造状态、累计金币和首张地图，初始余额沿用 999。旧结果和旧结算按钮不能影响新局。

`GameState.current_character_id` 和 `total_gold_collected` 改为只读查询；旧的 `start_new_run`、任意 `change_scene` 和 `map_node_seleceted` 入口已移除。扩展 UI 时应调用对应业务入口，不直接切场或写入访问状态。

回归测试为 `tests/main/run_flow_test.tscn` 和 `run_navigation_test.tscn`，覆盖只读结算、真实场景切换、连点、缺失场景、无效配置、跨地图保留库存、非战斗终点、无 HUD 结算、旧结果隔离和重试。可用以下命令运行（测试引导器会处理 SceneManager 的初始场景登记）：

```shell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_project_test.gd -- res://tests/main/run_flow_test.tscn
godot --headless --path . --script res://tests/run_project_test.gd -- res://tests/main/run_navigation_test.tscn
```

编辑器手动检查步骤：从主菜单选择角色；快速连续点击地图节点；进入并退出商店、锻造；战斗胜利返回原地图；死亡后重复点击“再来一次”；走到末层商店后确认显示通关结算。新增多地图内容后，检查下一张地图保留装备和金币。自动测试不代替动画、布局及鼠标操作的人工验收。

### 5. 背包与装备模块

- **核心数据**：`Equipment.id` 为配置编号，`instance_id` 唯一标识实际装备；`InventoryState` 保存金币、按实例编号索引的正式装备和网格占用，`ShopState` 保存货架，`ForgeState` 保存材料选择和未领取成品。
- **核心系统**：`BackpackManager` 持有这些状态及普通 `RefCounted` 服务 `InventoryService`，作为跨场景业务入口。`GridRules` 提供放置、旋转、寻找空位等纯计算，`ForgeRules` 按材料配置编号及数量匹配配方。
- **完整操作**：`try_purchase_equipment()`、`try_move_equipment()`、`try_forge()`、`try_claim_forge_reward()` 返回 `InventoryOperationResult`，包含成功状态、失败原因及受影响实例和区域。失败不修改数据；成功先完成所有写入和属性重算，再发送通知。
- **表现组件**：`EquipmentCard` 只修改显示快照，`PanelManager` 将鼠标位置转为目标网格后提交操作；`Package` 按实例编号同步卡牌。查询返回副本，界面不能通过修改返回的字典、网格或装备绕过业务入口。

数据链路为：`玩家输入 → View 生成候选位置 → BackpackManager → InventoryService 校验并提交 → 属性重算 → 结果信号 → View 刷新`。`equip_changed`、`gold_changed`、`shop_changed`、`forge_changed` 按本次变化分别最多发送一次；同步通知期间再次提交写操作会被拒绝，避免监听者观察到混合状态。新局重置库存、材料选择、成品和货架，但不复用实例或商品编号，旧拖拽请求不会命中新局对象。

主要目录：`data/` 下为 `equipment.gd`、`inventory_state.gd`、`shop_state.gd`、`forge_state.gd`、`inventory_operation_result.gd`；`sys/` 下为 `backpack_manager.gd`、`inventory_service.gd`、`grid_rules.gd`、`forge_rules.gd`；现有 `view/` 和场景路径继续保留。没有新增 Autoload。

### 6. 商店与锻造模块

**商店**根据当前地图节点的 `config_id` 读取 `ShopConfigData`，由业务层生成商品编号和货架状态。购买先校验商品未售出、余额及目标空位，再统一扣钱、增加装备并标记售出；价格从正式商品状态读取。刷新生成新商品编号，刷新前的请求会被拒绝。重建界面或再次打开当前节点时读取已有货架，不会把已售商品恢复。刷新沿用现有免费规则。

**锻造**选择材料时记录装备实例编号和锻造台预览位置，原装备仍留在背包/暂存区，但禁止移动、移除和重复选择；取消只解除选择，不复制装备。`try_forge()` 从业务状态匹配 `equipment_forge.csv`，校验材料数量、结果槽和 `Coin` 费用后，一次性扣费、消耗材料并生成成品。结果预览不代表拥有成品，实际成品由 `ForgeState.pending_reward` 保存。

领取成品时校验目标空位，成功后转入库存并清空结果槽；失败保留成品。关闭锻造面板会取消未合成材料的选择，已合成的待领取成品继续保存，且领取前禁止再次锻造，避免覆盖奖励。

`tests/backpack/` 中的购买、移动、锻造和 UI 流程测试覆盖无界面业务执行、通知一致性、重复/过期请求、旋转碰撞、材料锁定、配方费用、面板重建及领取失败。编辑器手动检查：购买到背包和暂存区、拖拽旋转后放到重叠/越界位置、取消材料选择、金币不足时锻造、合成后关闭重开面板再领取，以及整理装备后进入战斗。

### 7. 地图模块

`MapManager` 将 `map_data.csv` 转为 `MapNode` 列表，保存当前地图、当前节点和访问状态。节点包含层号、索引、类型、业务配置 ID 以及通往下一层的连接。

`map.gd` 和 `MapNodeButton` 负责生成节点、连接线、拖动滚动及可达状态展示。第一次只能选择起点，之后只能进入当前节点 `connections` 中声明的节点。`get_next_map_id()` 只查询下一张地图编号；`GameState.continue_run()` 接受请求后才调用 `init_map()`。初始化失败保留原地图。优先读取手工编排的 `map_<id>.tscn`，未提供时由基础地图按层生成节点及连接线；当前正式 CSV 仍只有地图 1。

### 8. 战斗模块

`battle.gd` 是战斗场景装配器：将敌人容器、掉落容器和出生点整理成 `BattleContext`，先连接射击、停止和结算事件，再调用 `CombatManager.start_battle(config_id, context)`。配置或场景引用无效时不会启动战斗。

`CombatManager` 统一维护 `IDLE → RUNNING → FINISHED` 状态和经过时间；`battle.gd` 每帧只调用 `tick_combat(delta)`，不再通过场景 Timer 推算时间。波次结束和敌人死亡都会检查胜利，且只统计当前敌人容器中的敌人，因此提前清怪后到达波次结束时间也能结算。

`end_battle(won)` 只执行一次，先停止战斗操作，再发布不含节点引用的 `BattleResult`（战斗编号、配置 ID、胜负、原因、经过时间）。场景停止玩家、敌人、子弹和拾取物的处理，结算 UI 继续运行。失败后点击“再来一次”会初始化新局并返回地图场景。

退出场景统一调用 `cleanup()`，解除本场监听，清空容器、出生点、生成器及计时；中途退出不发送胜负结算。延迟掉落、胜利检查和子弹生成绑定战斗编号，旧场景的回调不会影响下一场。金币、装备和地图进度仍由原有全局系统保存。

`CombatManager` 负责波次推进、敌人生成器调度、击杀统计、金币掉落和胜利判断；`EnemySpawner` 根据怪物 ID、数量、间隔和出生点实例化敌人。模块通过以下信号解耦：

- `damage_applied(result: DamageResult)`：伤害已经生效，UI 仅根据结果快照显示伤害数字和更新血条。
- `projectile_requested`：Shooter 通过 `request_projectile()` 校验战斗状态和来源后发布，由战斗场景创建子弹。
- `enemy_killed`：记录击杀并生成金币掉落物。
- `gold_collected`：保留金币拾取这一战斗事件；可消费余额及界面刷新由 `BackpackManager.gold_changed` 驱动。
- `battle_stopped`：结束或清理时停止场景实体，保留 UI 操作。
- `battle_ended(result: BattleResult)`：发布结束结果，触发胜负结算。

伤害执行链路为：武器 / 子弹 / 敌人 → `DamageRequest` → `CombatManager.apply_damage()` → `DamageSystem` → 目标 `take_damage()` → `DamageResult` → `damage_applied` → UI。`DamageSystem` 是由管理器持有的普通 `RefCounted` 对象，不新增 Autoload；目标通过 `current_hp` 和 `take_damage(float) -> bool` 提供受伤接口，并负责自己的无敌时间和死亡行为。

结果保存实际扣血量、剩余生命值、受击位置及死亡标记，显示层无需读取已经销毁的敌人位置。无效或被拒绝的伤害不发送通知；玩家死亡统一调用 `end_battle(false)`，战斗结束后拒绝新的伤害请求。伤害处理不依赖 HUD 是否存在。

生命周期回归场景为 `tests/battle/battle_lifecycle_test.tscn`，覆盖启动校验、跨波次计时、提前/延后清怪、场景外敌人隔离、旧延迟任务、重复结束与清理、无结算退出，以及实际战斗场景的冻结和再次进入。编辑器手动检查：进入战斗后分别胜利/死亡，确认结算时实体停止且按钮可用；返回地图再进入战斗；死亡后点击“再来一次”；战斗中切换回菜单后重新开局，检查调试器无失效节点引用。

### 9. 战斗实体模块

- **Player**：读取角色属性，处理 WASD 移动，并将背包装备转换为旋转武器或发射器实例。
- **Enemy**：实现追逐/攻击状态切换、接触伤害、受伤和死亡；`EnemyShooter` 在此基础上增加弹幕攻击。
- **RotateWeapon**：绕玩家旋转，碰撞敌人时发送伤害事件。
- **Shooter / Bullet**：检测最近目标、按间隔请求射击；子弹区分来源阵营并在命中后销毁。
- **Pickup**：处理金币掉落、吸附、闪烁、过期和拾取。
- **BattleUI / GameOver**：展示生命、金币、波次、伤害数字和战斗结果；金币标签初始化并订阅 `BackpackManager.gold_changed`。

### 10. 模块依赖与扩展边界

```text
CSV → GameConfig → 各业务 Manager → 领域对象/场景实例 → View 与 UI
角色选择 → GameState → BackpackManager + MapManager
背包装备 → Player → Weapon/Shooter → CombatManager
地图节点 → Shop / Forge / Battle 配置 → 节点结算 → 地图推进
```

后续新增装备类型时，应扩展装备配置、`Equipment` 类型及 Player 的装备实例化策略；新增地图节点类型时，应扩展节点调度而不是把逻辑写入按钮；新增敌人行为宜继承基础敌人或拆分独立状态组件。当前待完成的主要边界包括范围、饰品、防御装备，以及更完整的多地图内容和敌怪生成规则。
