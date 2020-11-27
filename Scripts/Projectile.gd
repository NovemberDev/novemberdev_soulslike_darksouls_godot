extends Area

const FLY_SPEED = 5.0
var max_alive_time = 8.0
var fly_direction = Vector3.ZERO

func _ready():
	Globals.play_sound("magic_flying_0.wav", 5)
	connect("body_entered", self, "on_projectile_collision")

func _process(delta):
	max_alive_time -= delta
	if max_alive_time <= 0.0:
		queue_free()
	global_transform.origin -= fly_direction * FLY_SPEED * delta

func start(direction):
	fly_direction = direction.normalized()

func on_projectile_collision(target):
	if target.is_in_group("enemy"):
		target.take_damage(100)
		Globals.play_sound("magic_impact_0.wav", 5)
		$FX/MAGIC/AnimationPlayer.play("default")
		$MeshInstance.visible = false
		max_alive_time = 1.0
