class_name ShooterBase
extends Node2D
## 所有发射器的公共基类，负责定时、散射计算和发送子弹生成请求。

## 多发子弹之间的固定角度间隔。
const SPREAD_ANGLE: float = PI / 24.0

## 是否由内部计时器自动触发射击；敌方动画驱动的发射器会关闭此项。
@export var auto_fire: bool = true

## 发射器所属角色，用于阵营位置和径向方向计算。
var source: Node2D = null
## 当前射击使用的子弹配置快照。
var spec: ProjectileSpec = null
## 两次自动射击之间的秒数。
var fire_interval: float = 0.0
## 驱动自动射击的计时器。
var shoot_timer: Timer = null


## 获取或创建射击计时器，连接超时回调并同步启停状态。
func _ready() -> void:
	shoot_timer = get_node_or_null("ShootTimer") as Timer
	if shoot_timer == null:
		shoot_timer = Timer.new()
		shoot_timer.name = "ShootTimer"
		add_child(shoot_timer)
	if not shoot_timer.timeout.is_connected(_on_shoot_timeout):
		shoot_timer.timeout.connect(_on_shoot_timeout)
	_apply_timer_state()


## 初始化发射器的所属角色、子弹配置、射击间隔和自动射击模式。
func setup(
	new_source: Node2D,
	new_spec: ProjectileSpec,
	new_fire_interval: float,
	new_auto_fire: bool = true
) -> void:
	source = new_source
	spec = new_spec.snapshot() if new_spec != null else null
	fire_interval = new_fire_interval
	auto_fire = new_auto_fire
	_apply_timer_state()


## 装备属性变化后刷新子弹配置和射击间隔。
func refresh(new_spec: ProjectileSpec, new_fire_interval: float) -> void:
	spec = new_spec.snapshot() if new_spec != null else null
	fire_interval = new_fire_interval
	_apply_timer_state()


## 按给定方向生成一组发射请求，并通过 CombatManager 交给战斗场景创建子弹。
func request_fire(shoot_direction: Vector2) -> void:
	if source == null or not is_instance_valid(source):
		return
	if spec == null or spec.speed <= 0.0 or shoot_direction.is_zero_approx():
		return
	var count := maxi(spec.shot_count, 1)
	for index in count:
		var angle_offset := (index - (count - 1) * 0.5) * SPREAD_ANGLE
		var direction := shoot_direction.normalized().rotated(angle_offset)
		var request := ProjectileSpawnRequest.create(global_position, direction, spec)
		CombatManager.projectile_requested.emit(request)


## 计算目标方向并发起一次射击，供锁敌或动画驱动的发射器调用。
func fire_at(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	request_fire(target.global_position - global_position)


## 根据自动射击开关和射击间隔启动或停止计时器。
func _apply_timer_state() -> void:
	if shoot_timer == null:
		return
	if auto_fire and fire_interval > 0.0:
		shoot_timer.wait_time = fire_interval
		shoot_timer.start()
	else:
		shoot_timer.stop()


## 射击计时器超时钩子，由具体发射器实现方向选择逻辑。
func _on_shoot_timeout() -> void:
	pass
