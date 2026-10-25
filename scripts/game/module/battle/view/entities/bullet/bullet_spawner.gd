class_name BulletSpawner
extends Node
## 战斗场景中的统一子弹工厂，根据发射请求选择场景并创建子弹实例。

## 三种子弹类型对应的场景资源。
const NORMAL_BULLET_SCENE: PackedScene = preload(
	"res://scene/battle/entities/bullet/normal_bullet.tscn"
)
const PIERCING_BULLET_SCENE: PackedScene = preload(
	"res://scene/battle/entities/bullet/piercing_bullet.tscn"
)
const EXPLOSIVE_BULLET_SCENE: PackedScene = preload(
	"res://scene/battle/entities/bullet/explosive_bullet.tscn"
)

## 所有运行时子弹节点的统一父节点。
@export var bullet_container: Node2D = null


## 设置子弹实例的父容器。
func setup(container: Node2D) -> void:
	bullet_container = container


## 延迟处理生成请求，避免在信号或物理查询刷新期间修改场景树。
func spawn(request: ProjectileSpawnRequest) -> void:
	if CombatManager.owns_node(self):
		call_deferred("_spawn_now", request, CombatManager.battle_id)


func cleanup() -> void:
	bullet_container = null


## 验证请求、实例化匹配类型的子弹，并加入子弹容器。
func _spawn_now(request: ProjectileSpawnRequest, battle_id: int) -> void:
	if not CombatManager.is_current_battle(battle_id) or not CombatManager.owns_node(self):
		return
	if bullet_container == null or not is_instance_valid(bullet_container):
		return
	if request == null or request.spec == null:
		return
	if request.direction.is_zero_approx() or request.spec.speed <= 0.0:
		return
	var bullet_scene := _scene_for_type(request.spec.bullet_type)
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate() as BulletBase
	if bullet == null:
		return
	bullet.setup(request)
	bullet_container.add_child(bullet)


## 返回子弹类型对应的场景；未知类型返回 null。
func _scene_for_type(type: BulletType.Type) -> PackedScene:
	match type:
		BulletType.Type.NORMAL:
			return NORMAL_BULLET_SCENE
		BulletType.Type.PIERCING:
			return PIERCING_BULLET_SCENE
		BulletType.Type.EXPLOSIVE:
			return EXPLOSIVE_BULLET_SCENE
		_:
			return null
