extends RigidBody

const PLAYER_DETECTION_RANGE = 10.0
const PLAYER_ATTACK_RANGE = 2.25
const WALK_SPEED = 2.25

var health = 100
var taunted = false
var distance_to_player = 0
var random_velocity_timer = 0.0
var random_velocity = Vector3.ZERO
var to_player_velocity = Vector3.ZERO
var around_player_velocity = Vector3.ZERO

var can_move = true
var can_hurt = false
var attack_timeout = 1.0

func _ready():
	$AnimationTree.active = true
	$Model/BackstabSensor.connect("body_exited", self, "on_backstab_exited")
	$Model/BackstabSensor.connect("body_entered", self, "on_backstab_entered")
	$Model/enemy_2/rig/Skeleton/BoneAttachment/Cylinder/Hurtbox.connect("body_entered", self, "on_hurtbox_entered")

func _process(delta):
	if !can_move: return
	distance_to_player = Globals.current_player.global_transform.origin.distance_to(global_transform.origin)
	
	# randomly walk around
	random_velocity_timer -= delta
	if random_velocity_timer <= 0.0:
		random_velocity_timer = 3.5
		if rand_range(0, 20) < 15:
			random_velocity = Vector3(rand_range(-1, 1), 0, rand_range(-1, 1)) * WALK_SPEED
	random_velocity = lerp(random_velocity, Vector3.ZERO, 0.01 * delta)
	
	# if Player is inside detection range
	if distance_to_player < PLAYER_DETECTION_RANGE:
		# taunt trigger
		if !taunted:
			set_action(0)
			taunted = true
		# look at player
		look_towards(Globals.current_player.global_transform.origin, delta)
		
		if distance_to_player > PLAYER_ATTACK_RANGE:
			to_player_velocity = lerp(to_player_velocity, (Globals.current_player.global_transform.origin - global_transform.origin).normalized() * WALK_SPEED, 5.0 * delta)
			around_player_velocity = Vector3.ZERO
		else:
			to_player_velocity = lerp(to_player_velocity, Vector3.ZERO, 5.0 * delta)
			# Circle around player
			if rand_range(0, 20) < 5:
				around_player_velocity -= $Model.global_transform.basis.x * sin(OS.get_ticks_msec()) * WALK_SPEED * 0.5
			# randomly attack
			attack_timeout -= delta
			if attack_timeout <= 0.0:
				attack_timeout = rand_range(0.5, 3.0)
				set_action(1)
		
		linear_velocity = to_player_velocity + around_player_velocity
	else:
		taunted = false
		linear_velocity = random_velocity
		look_towards(global_transform.origin + linear_velocity * 2.0, delta)
		
	$AnimationTree.set("parameters/state/current", int(Vector2(linear_velocity.x, linear_velocity.z) != Vector2.ZERO))
	linear_velocity.y = (1.0 - int($FloorSensor.is_colliding())) * -5

func look_towards(target, delta):
	$Model.global_transform.basis = $Model.global_transform.basis.slerp($Model.global_transform.looking_at(target, Vector3.UP).basis, 5.0 * delta)
	$Model.rotation = Vector3(0, $Model.rotation.y, 0)
	
func set_action(index):
	$AnimationTree.set("parameters/action/active", true)
	$AnimationTree.set("parameters/action_bs/blend_position", Vector2(index, 0))
	can_move = false

func take_damage(damage):
	health -= damage
	if health <= 0.0:
		disable_ai()
		Globals.play_sound("souls_0.wav", 5)
		$AnimationTree.set("parameters/state/current", 2)
		$FX.global_transform.origin = global_transform.origin
		$FX/SOUL/AnimationPlayer.play("default")
	else:
		set_action(2)
		
func backstab():
	disable_ai()
	set_action(3)

func disable_ai():
	can_hurt = false
	can_move = false
	mode = MODE_STATIC
	linear_velocity = Vector3.ZERO
	$CollisionShape.disabled = true
	$Model/BackstabSensor/CollisionShape.disabled = true
	$Model/enemy_2/rig/Skeleton/BoneAttachment/Cylinder/Hurtbox/CollisionShape.disabled = true

func on_hurtbox_entered(body):
	if can_hurt:
		if body.is_in_group("player"):
			body.take_damage(35)
			Globals.play_sound("fleshhit_" + str(randi()%3) + ".wav", rand_range(0, -5))
			$FX.global_transform.origin = $Model/enemy_2/rig/Skeleton/BoneAttachment/Cylinder/Hurtbox.global_transform.origin
			$FX/BLOOD/AnimationPlayer.play("default")
			$FX/SPARK/AnimationPlayer.play("default")
			can_hurt = false

func footstep():
	Globals.play_sound("step_" + str(randi()%9) + ".wav", rand_range(-15, -25))
func swing():
	Globals.play_sound("swords_" + str(randi()%4) + ".wav", rand_range(0, -5))
func hit():
	Globals.play_sound("swordhit_" + str(randi()%5) + ".wav", rand_range(0, -5))
	$FX.global_transform.origin = $Model/enemy_2/rig/Skeleton/BoneAttachment/Cylinder/Hurtbox.global_transform.origin
	$FX/SPARK/AnimationPlayer.play("default")
	
func on_backstab_entered(body):
	if body.is_in_group("player"):
		Globals.current_player.emit_signal("on_toggle_backstab", self, $Model/BackstabSensor.global_transform.origin, true)
func on_backstab_exited(body):
	if body.is_in_group("player"):
		Globals.current_player.emit_signal("on_toggle_backstab", self, $Model/BackstabSensor.global_transform.origin, false)
