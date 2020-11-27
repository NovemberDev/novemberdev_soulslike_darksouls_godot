extends RigidBody

const GRAVITY = 12.5
const MAX_SPEED = 3.75
const SPRINT_SPEED = 2
const VIEW_SPEED = 7
const MOUSE_SENSITIVITY = 0.3
const JOY_SENSITIVITY = 7.5
const ROLL_STRENGTH = 0.6
const ROLL_STRENGTH_SIDEWAYS = 0.25
var health = 100
var magicka = 100
var stamina = 100

var yaw = 0.0
var pitch = 0.0
var can_hurt = false
var can_control = true
var can_take_damage = true
var direction = Vector3.ZERO
var view_direction = Vector3.ZERO
var roll_force = Vector3.ZERO
var parry_target = 0.0
var parry_val = 0.0
var lock_on_active
var lock_on_target
var direction_input

var backstab_target = null
var backstab_sensor_origin = null
var magic_projectile_scene = load("res://Scenes/MAGIC.tscn")

signal on_death
signal on_gesture
signal on_update_health
signal on_update_stamina
signal on_update_magicka
signal on_toggle_backstab

func _init():
	Globals.current_player = self
	
func _ready():
	$MODEL/Tree.active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	view_direction = $VIEW_ANCHOR.global_transform.basis.z
	connect("on_toggle_backstab", self, "toggle_backstab")
	connect("on_gesture", self, "gesture")
	$"MODEL/knight/knight_simplified/rig/Skeleton/BoneAttachment 2/sword/Hurtbox".connect("body_entered", self, "on_hurtbox_entered")

func _input(event):
	if event is InputEventMouseMotion:
		yaw = fmod(yaw - event.relative.x * MOUSE_SENSITIVITY, 360)
		pitch = max(min(pitch - event.relative.y * MOUSE_SENSITIVITY, 70), -50)
		$VIEW_ANCHOR.rotation_degrees = Vector3(pitch, yaw, 0)

func _process(delta):
	emit_signal("on_update_health", health)
	emit_signal("on_update_stamina", stamina)
	emit_signal("on_update_magicka", magicka)
	if health < 0: return
	direction = Vector3.ZERO
	direction_input = Vector2.ZERO
	
	if can_control:
		direction_input.y -= Input.get_action_strength("gp_movement_d") - Input.get_action_strength("gp_movement_u")
		direction_input.x -= Input.get_action_strength("gp_movement_l") - Input.get_action_strength("gp_movement_r")
		direction -= $VIEW_ANCHOR.global_transform.basis.z * direction_input.y - $VIEW_ANCHOR.global_transform.basis.x * direction_input.x
		direction.y = 0.0
		
		parry_target = int(Input.is_action_pressed("gp_attack_secondary"))
		
		if Input.is_action_pressed("gp_movement_sprint"):
			stamina -= delta * 10.0
		
		if Input.is_action_just_pressed("gp_attack_weak") and stamina >= 10.0:
			stamina -= 10.0
			$MODEL/Tree.set("parameters/attack/active", true)
			$MODEL/Tree.set("parameters/attack_bs/blend_position", Vector2(0, 0))
			can_control = false
		if Input.is_action_just_pressed("gp_attack_strong") and stamina >= 25.0:
			stamina -= 25.0
			
			if backstab_target != null:
				$MODEL/Tree.set("parameters/backstab/active", true)
				global_transform.origin = Vector3(backstab_sensor_origin.x, 0.2, backstab_sensor_origin.z)
				$MODEL.look_at(backstab_target.global_transform.origin, Vector3.UP)
				$MODEL.rotation = Vector3(0, $MODEL.rotation.y + PI, 0)
				linear_velocity = Vector3.ZERO
				backstab_target.backstab()
			else:
				$MODEL/Tree.set("parameters/attack/active", true)
				$MODEL/Tree.set("parameters/attack_bs/blend_position", Vector2(1, 0))
			can_control = false
		if Input.is_action_just_pressed("gp_attack_magic")  and stamina >= 25.0 and magicka >= 50.0:
			Globals.play_sound("magic_0.wav", 5)
			stamina -= 25.0
			$MODEL/Tree.set("parameters/attack/active", true)
			$MODEL/Tree.set("parameters/attack_bs/blend_position", Vector2(2, 0))
			can_control = false
		
		if Input.is_action_just_pressed("gp_roll") and stamina >= 25.0:
			stamina -= 25.0
			can_control = false
			roll_force = direction.normalized() * ROLL_STRENGTH
			$MODEL/Tree.set("parameters/roll_bs/blend_position", Vector2(0, 1))
			if !lock_on_active:
				view_direction = direction
				$MODEL.global_transform.basis = $MODEL.global_transform.looking_at(global_transform.origin - view_direction * 2.0, Vector3.UP).basis
			else:
				if direction_input.x != 0:
					roll_force = ($MODEL.global_transform.basis.z.normalized() - $MODEL.global_transform.basis.x.normalized() * direction_input.x) * ROLL_STRENGTH_SIDEWAYS
				$MODEL/Tree.set("parameters/roll_bs/blend_position", direction_input)
			$MODEL/Tree.set("parameters/roll/active", true)
			roll_force.y = 0
	
	if lock_on_active:
		$lockon.global_transform.origin = lock_on_target.global_transform.origin + Vector3.UP * 1.25
		$VIEW_ANCHOR.look_at(lock_on_target.global_transform.origin, Vector3.UP)
		$MODEL.look_at(lock_on_target.global_transform.origin + ($MODEL.global_transform.origin - lock_on_target.global_transform.origin).normalized() * 20.0, Vector3.UP)
		$MODEL.rotation = Vector3(0, $MODEL.rotation.y, 0)
		if lock_on_target.health <= 0.0:
			lock_on_target = null
			lock_on_active = false
			$lockon.visible = false
	else:
		yaw = fmod(yaw + (Input.get_action_strength("gp_look_l") - Input.get_action_strength("gp_look_r")) * JOY_SENSITIVITY, 360)
		pitch = max(min(pitch + (Input.get_action_strength("gp_look_u") - Input.get_action_strength("gp_look_d")) * JOY_SENSITIVITY, 70), -50)
		$VIEW_ANCHOR.rotation_degrees = Vector3(pitch, yaw, 0)
	
	if direction != Vector3.ZERO:
		view_direction = lerp(view_direction, direction, delta * VIEW_SPEED)
		$direction.look_at(global_transform.origin - linear_velocity * 2.0, Vector3.UP)
		linear_velocity = lerp(linear_velocity, view_direction.normalized() * (MAX_SPEED + SPRINT_SPEED * int(Input.is_action_pressed("gp_movement_sprint"))), delta * VIEW_SPEED)
		if !lock_on_active:
			$MODEL.global_transform.basis = $MODEL.global_transform.basis.slerp($MODEL.global_transform.looking_at(global_transform.origin - view_direction * 2.0, Vector3.UP).basis, delta * VIEW_SPEED)
	else:
		linear_velocity = lerp(linear_velocity, Vector3.ZERO, delta * 5.0)
		
	linear_velocity += roll_force
	linear_velocity.y -= GRAVITY * delta
	linear_velocity.y = clamp(linear_velocity.y, -GRAVITY, GRAVITY)
	
	# Local look at to the View anchor node the ClippedCamera is attached to
	$VIEW_ANCHOR/ClippedCamera.transform = $VIEW_ANCHOR/ClippedCamera.transform.looking_at(Vector3.ZERO, Vector3.UP)
	
	$MODEL/Tree.set("parameters/speed/scale", 0.1 + linear_velocity.length() / 10.0)
	
	if $FloorSensor.is_colliding():
		if !lock_on_active:
			$MODEL/Tree.set("parameters/state/current", int(Vector2(linear_velocity.x, linear_velocity.z).length() >= 0.5))
			if Input.is_action_pressed("gp_movement_sprint"):
				$MODEL/Tree.set("parameters/state/current", 5)
		else:
			if direction == Vector3.ZERO:
				$MODEL/Tree.set("parameters/state/current", 0)
			else:
				if Input.is_action_pressed("gp_movement_u"):
					$MODEL/Tree.set("parameters/state/current", 1)
				if Input.is_action_pressed("gp_movement_d"):
					$MODEL/Tree.set("parameters/state/current", 2)
				if Input.is_action_pressed("gp_movement_l"):
					$MODEL/Tree.set("parameters/state/current", 3)
				if Input.is_action_pressed("gp_movement_r"):
					$MODEL/Tree.set("parameters/state/current", 4)
		
	parry_val = lerp(parry_val, parry_target, delta * 9.0)
	$MODEL/Tree.set("parameters/parry/blend_amount", parry_val)

	if Input.is_action_just_pressed("gp_lock"):
		if lock_on_target != null:
			lock_on_target = null
			lock_on_active = false
			$lockon.visible = false
		else:
			var closest = null
			var closest_distance = INF
			for enemy in get_node("../../ENEMIES").get_children():
				if enemy.health > 0.0:
					if closest == null:
						closest = enemy
					else:
						if enemy.global_transform.origin.distance_to(global_transform.origin) < closest_distance:
							closest = enemy
							closest_distance = enemy.global_transform.origin.distance_to(global_transform.origin)
			if closest != null:
				lock_on_active = true
				$lockon.visible = true
				lock_on_target = closest
	
	magicka = clamp(magicka + delta * 5.0, 0, 100)
	
	if !Input.is_action_pressed("gp_attack_secondary"):
		stamina = clamp(stamina + delta * 5.0, 0, 100)

func cancel_roll():
	roll_force = Vector3.ZERO
	can_control = true

func take_damage(damage):
	if health <= 0.0: return
	if !can_take_damage: return
	can_control = false
	if parry_val >= 0.75:
		stamina -= 25.0
		$MODEL/Tree.set("parameters/parry_hit/active", true)
		return
	health -= damage
	if health <= 0.0:
		linear_velocity = Vector3.ZERO
		$MODEL/Tree.set("parameters/state/current", 6)
		Globals.play_sound("souls_0.wav", 5)
		$FX.global_transform.origin = global_transform.origin
		$FX/SOUL/AnimationPlayer.play("default")
		emit_signal("on_death")
	$MODEL/Tree.set("parameters/parry_hit/active", true)
	
func on_hurtbox_entered(body):
	if can_hurt:
		if body.is_in_group("enemy"):
			body.take_damage(35)
			hurt()
			can_hurt = false

func footstep():
	Globals.play_sound("step_" + str(randi()%9) + ".wav", rand_range(-15, -25))
func swing():
	Globals.play_sound("swords_" + str(randi()%4) + ".wav", rand_range(0, -5))
func hurt():
	Globals.play_sound("fleshhit_" + str(randi()%3) + ".wav", rand_range(0, -5))
	$FX.global_transform.origin = $"MODEL/knight/knight_simplified/rig/Skeleton/BoneAttachment 2/sword/Hurtbox".global_transform.origin
	$FX/BLOOD/AnimationPlayer.play("default")
	$FX/SPARK/AnimationPlayer.play("default")

func launch_magic():
	$FX.global_transform.origin = $"MODEL/knight/knight_simplified/rig/Skeleton/BoneAttachment 2/sword/Hurtbox".global_transform.origin
	$FX/MAGIC/AnimationPlayer.play("default")
	var projectile = magic_projectile_scene.instance()
	projectile.global_transform.origin = $"MODEL/knight/knight_simplified/rig/Skeleton/BoneAttachment 2/sword".global_transform.origin
	get_node("/root").add_child(projectile)
	if lock_on_active:
		projectile.start((projectile.global_transform.origin - lock_on_target.global_transform.origin))
	else:
		projectile.start(-$MODEL.global_transform.basis.z)
	magicka -= 50

func toggle_backstab(target, sensor_origin, enabled):
	if enabled:
		backstab_target = target
		backstab_sensor_origin = sensor_origin
	else:
		backstab_target = null
		backstab_sensor_origin = null

func gesture(index):
	$MODEL/Tree.set("parameters/gesture/active", true)
	$MODEL/Tree.set("parameters/gesture_bs/blend_position", Vector2(index, 0))
	can_control = false
