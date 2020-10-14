extends RigidBody

const GRAVITY = 5.0
const MAX_SPEED = 3.2
const VIEW_SPEED = 7
const MOUSE_SENSITIVITY = 0.3
const JOY_SENSITIVITY = 7.5
const ROLL_STRENGTH = 12.0
const INITIAL_CAM_ORIGIN = Vector3(0, 0, 2.5)

var yaw = 0.0
var pitch = 0.0
var can_control = true
var can_control_temp_timer = 0.0
var cam_origin = INITIAL_CAM_ORIGIN
var direction : Vector3 = Vector3.ZERO
var view_direction : Vector3 = Vector3.ZERO
var roll_force : Vector3 = Vector3.ZERO
var parry_target = 0.0
var parry_val = 0.0
var lock_on_active
var lock_on_target

func _ready():
	$MODEL/Tree.active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	view_direction = $VIEW_ANCHOR.global_transform.basis.z

func _input(event):
	if event is InputEventMouseMotion:
		yaw = fmod(yaw - event.relative.x * MOUSE_SENSITIVITY, 360)
		pitch = max(min(pitch - event.relative.y * MOUSE_SENSITIVITY, 70), -50)
		$VIEW_ANCHOR.rotation_degrees = Vector3(pitch, yaw, 0)
		

func _process(delta):
	
	can_control_temp_timer -= delta
	if can_control_temp_timer <= 0.0:
		can_control = true
	
	direction = Vector3.ZERO
	
	if can_control:
		if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("gp_movement_u"):
			direction -= $VIEW_ANCHOR.global_transform.basis.z
		if Input.is_key_pressed(KEY_S)  or Input.is_action_pressed("gp_movement_d"):
			direction += $VIEW_ANCHOR.global_transform.basis.z
		if Input.is_key_pressed(KEY_A)  or Input.is_action_pressed("gp_movement_l"):
			direction -= $VIEW_ANCHOR.global_transform.basis.x
		if Input.is_key_pressed(KEY_D)  or Input.is_action_pressed("gp_movement_r"):
			direction += $VIEW_ANCHOR.global_transform.basis.x
		if lock_on_active:
			if Input.is_action_pressed("gp_movement_u"):
				$MODEL/Tree.set("parameters/state/current", 1)
			if Input.is_action_pressed("gp_movement_d"):
				$MODEL/Tree.set("parameters/state/current", 2)
			if Input.is_action_pressed("gp_movement_l"):
				$MODEL/Tree.set("parameters/state/current", 3)
			if Input.is_action_pressed("gp_movement_r"):
				$MODEL/Tree.set("parameters/state/current", 4)
		if Input.is_mouse_button_pressed(2) or Input.is_action_pressed("gp_attack_secondary"):
			parry_target = 1.0
		else:
			parry_target = 0.0
		if Input.is_mouse_button_pressed(1) or Input.is_action_just_pressed("gp_attack_weak"):
			$MODEL/Tree.set("parameters/attack/active", true)
			can_control = false
			can_control_temp_timer = 1.0
		if Input.is_key_pressed(KEY_E):
			$MODEL/Tree.set("parameters/gesture/active", true)
			can_control = false
			can_control_temp_timer = 2.0
		if Input.is_action_just_pressed("gp_roll"):
			can_control = false
			can_control_temp_timer = 1.0
			roll_force = direction.normalized() * ROLL_STRENGTH
			if !lock_on_active:
				view_direction = direction
				$MODEL.global_transform.basis = $MODEL.global_transform.looking_at(global_transform.origin - view_direction * 2.0, Vector3.UP).basis
			$MODEL/Tree.set("parameters/roll_state/current", 2)
			if lock_on_active:
				if Input.is_action_pressed("gp_movement_d"):
					$MODEL/Tree.set("parameters/roll_state/current", 3)
				elif Input.is_action_pressed("gp_movement_r"):
					$MODEL/Tree.set("parameters/roll_state/current", 1)
				elif Input.is_action_pressed("gp_movement_l"):
					$MODEL/Tree.set("parameters/roll_state/current", 0)
			$MODEL/Tree.set("parameters/roll/active", true)
	
	if !lock_on_active:
		if Input.get_action_strength("gp_look_l") + Input.get_action_strength("gp_look_r") != 0:
			yaw = fmod(yaw + (Input.get_action_strength("gp_look_l") - Input.get_action_strength("gp_look_r")) * JOY_SENSITIVITY, 360)
		if Input.get_action_strength("gp_look_u") + Input.get_action_strength("gp_look_d") != 0:
			pitch = max(min(pitch + (Input.get_action_strength("gp_look_u") - Input.get_action_strength("gp_look_d")) * JOY_SENSITIVITY, 70), -50)
		$VIEW_ANCHOR.rotation_degrees = Vector3(pitch, yaw, 0)
	else:
		$VIEW_ANCHOR.look_at(lock_on_target.global_transform.origin, Vector3.UP)
		$MODEL.look_at(lock_on_target.global_transform.origin + ($MODEL.global_transform.origin - lock_on_target.global_transform.origin).normalized() * 20.0, Vector3.UP)
	
	direction.y = 0.0
	
	if direction != Vector3.ZERO:
		view_direction = lerp(view_direction, direction, delta * VIEW_SPEED)
		$direction.look_at(global_transform.origin - linear_velocity * 2.0, Vector3.UP)
		linear_velocity = lerp(linear_velocity, view_direction.normalized() * MAX_SPEED, delta * VIEW_SPEED)
		if !lock_on_active:
			$MODEL.global_transform.basis = $MODEL.global_transform.basis.slerp($MODEL.global_transform.looking_at(global_transform.origin - view_direction * 2.0, Vector3.UP).basis, delta * VIEW_SPEED)
	else:
		linear_velocity = lerp(linear_velocity, Vector3.ZERO, delta * 5.0)
		
	linear_velocity += roll_force
	linear_velocity.y -= GRAVITY * delta
	linear_velocity.y = clamp(linear_velocity.y, -GRAVITY, GRAVITY)
	
	# Local look at to the View anchor node the ClippedCamera is attached to
	$VIEW_ANCHOR/ClippedCamera.transform = $VIEW_ANCHOR/ClippedCamera.transform.looking_at(Vector3.ZERO, Vector3.UP)
	$VIEW_ANCHOR/ClippedCamera.transform.origin = cam_origin
	
	$MODEL/Tree.set("parameters/speed/scale", 0.1 + linear_velocity.length() / 10.0)
	
	if $FloorSensor.is_colliding():
		if !lock_on_active:
			$MODEL/Tree.set("parameters/state/current", int(Vector2(linear_velocity.x, linear_velocity.z).length() >= 0.5))
		else:
			if direction == Vector3.ZERO:
				$MODEL/Tree.set("parameters/state/current", 0)
		
	parry_val = lerp(parry_val, parry_target, delta * 9.0)
	roll_force = lerp(roll_force, Vector3.ZERO, delta * 20.0)
	
	$MODEL/Tree.set("parameters/parry/blend_amount", parry_val)

	if Input.is_action_just_pressed("gp_lock"):
		if lock_on_target != null:
			lock_on_target = null
			lock_on_active = false
		else:
			lock_on_active = true
			lock_on_target = get_node("../../StaticBody")
