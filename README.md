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
  → GameState.start_new_run()
  → 初始化角色、背包和第 1 张地图
  → 地图选点
      ├─ BATTLE → 战斗 → 结算 → 返回地图/进入下一张地图/结束游戏
      ├─ SHOP   → 商店购买与整理背包 → 返回地图
      └─ FORGE  → 装备合成与整理背包 → 返回地图
```

`GameState` 保存当前角色和累计拾取金币，并封装场景切换；可消费金币由 `BackpackManager` 独占，并通过 `gold_changed` 通知界面。`gaming.gd` 监听地图节点选择，根据节点类型打开对应面板或进入战斗。地图进度、背包装备和金币均由 Autoload 保存，因此切换场景后仍能延续当前对局。

### 3. 配置与数据模块

- **入口**：`scripts/game/config/game_config.gd`。
- **输入**：角色、装备、怪物、掉落、商店、锻造、战斗和地图 CSV。
- **处理**：`GameConfigData` 提供数值、数组、形状和嵌套字典解析；各 `*Data` 类负责将单行记录转换为领域数据。
- **输出**：`GameConfig.characters`、`equipment`、`monsters`、`shops`、`forges`、`battles`、`map_nodes` 等只读式配置索引。

配置层不直接操作场景；业务系统通过配置 ID 查询数据，再创建运行时对象或场景实例。新增内容应优先扩展 CSV 和对应 Data 类型，避免把平衡数值写死在 View 中。

### 4. 全局状态与场景模块

`GameState` 是一局游戏的总入口：开始新对局时重置累计拾取金币，通过 `BackpackManager.set_gold()` 初始化可消费金币，并调用 `BackpackManager.init_backpack()` 和 `MapManager.init_map()`；运行中负责查找玩家及切换 `main_menu`、`character_select`、`gaming`、`battle` 等场景。实际转场动画由 SceneManager 插件完成。

主界面模块由 `main_menu.gd`、`character_select.gd`、`character_card.gd`、`gaming.gd` 和 `game_over.gd` 组成，分别负责开始游戏、角色选择、对局面板调度及战斗结算。`PanelManager` 统一控制地图、背包、商店和锻造面板，避免各页面互相直接切换。

### 5. 背包与装备模块

- **核心数据**：`Equipment` 保存配置 ID、形状、旋转状态、网格位置和所在区域。
- **核心系统**：`BackpackManager` 维护可消费金币，以及装备区、存储区和锻造台的二维占用数组及装备字典。
- **核心能力**：初始化角色背包形状、寻找空位、验证边界/碰撞、放置、移除、跨网格移动和坐标转换。
- **表现组件**：`EquipmentCard` 负责装备图形、拖拽和旋转；`Package` 将管理器数据同步为卡牌。

`equip_changed` 驱动背包和锻造界面刷新。所有网格写操作应经过 `BackpackManager`，View 只负责把鼠标坐标转换为候选网格位置并展示合法性反馈。

### 6. 商店与锻造模块

**商店**根据当前地图节点的 `config_id` 读取 `ShopConfigData`，生成装备池并刷新货架。装备成功放入可用网格后，通过 `BackpackManager.spend_gold()` 原子校验并扣除金币；若扣款失败则回滚刚放入的装备。刷新和购买都依赖金币与空位校验。

**锻造**读取 `equipment_forge.csv`，收集锻造台中的材料 ID，与配方进行无序匹配；匹配成功时展示结果预览。确认锻造后消耗材料、创建高级装备，并尝试放入锻造结果/背包流程。`PanelManager` 复用统一拖拽逻辑，使装备可在背包、存储区和锻造台之间移动。

### 7. 地图模块

`MapManager` 将 `map_data.csv` 转为 `MapNode` 列表，保存当前地图、当前节点和访问状态。节点包含层号、索引、类型、业务配置 ID 以及通往下一层的连接。

`map.gd` 和 `MapNodeButton` 负责生成节点、连接线、拖动滚动及可达状态展示。第一次只能选择起点，之后只能进入当前节点 `connections` 中声明的节点。最终节点完成后，`check_and_init_next_map()` 尝试加载下一张地图；不存在下一张地图时结束本局。

### 8. 战斗模块

`battle.gd` 是战斗场景装配器：根据当前地图节点取得战斗配置，注册敌人、掉落物、出生点和可选 UI，并把射击与结算信号接入 `CombatManager`。

`CombatManager` 负责波次推进、敌人生成器调度、击杀统计、金币掉落和胜利判断；`EnemySpawner` 根据怪物 ID、数量、间隔和出生点实例化敌人。模块通过以下信号解耦：

- `damage_applied(result: DamageResult)`：伤害已经生效，UI 仅根据结果快照显示伤害数字和更新血条。
- `projectile_requested`：由 Shooter 请求，由战斗场景创建子弹。
- `enemy_killed`：记录击杀并生成金币掉落物。
- `gold_collected`：保留金币拾取这一战斗事件；可消费余额及界面刷新由 `BackpackManager.gold_changed` 驱动。
- `battle_ended`：触发胜负结算。

伤害执行链路为：武器 / 子弹 / 敌人 → `DamageRequest` → `CombatManager.apply_damage()` → `DamageSystem` → 目标 `take_damage()` → `DamageResult` → `damage_applied` → UI。`DamageSystem` 是由管理器持有的普通 `RefCounted` 对象，不新增 Autoload；目标通过 `current_hp` 和 `take_damage(float) -> bool` 提供受伤接口，并负责自己的无敌时间和死亡行为。

结果保存实际扣血量、剩余生命值、受击位置及死亡标记，显示层无需读取已经销毁的敌人位置。无效或被拒绝的伤害不发送通知；玩家死亡统一调用 `end_battle(false)`，战斗结束后拒绝新的伤害请求。伤害处理不依赖 HUD 是否存在。

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
