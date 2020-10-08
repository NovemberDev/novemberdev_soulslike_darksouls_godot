extends RigidBody

const GRAVITY = 1.0
const MAX_SPEED = 2
const MOUSE_SENSITIVITY = 0.3
const INITIAL_CAM_ORIGIN = Vector3(0, 0, 3.0)

var yaw = 0.0
var pitch = 0.0
var cam_origin = INITIAL_CAM_ORIGIN
var direction : Vector3 = Vector3.ZERO
var view_direction : Vector3 = Vector3.ZERO
var parry_target = 0.0
var parry_val = 0.0

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
	
	direction = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		direction -= $VIEW_ANCHOR.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += $VIEW_ANCHOR.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= $VIEW_ANCHOR.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += $VIEW_ANCHOR.global_transform.basis.x
	
	direction.y = 0.0
	
	if direction != Vector3.ZERO:
		view_direction = lerp(view_direction, direction, delta * 2.5)
		$direction.look_at(global_transform.origin - linear_velocity * 2.0, Vector3.UP)
		linear_velocity = lerp(linear_velocity, view_direction.normalized() * MAX_SPEED, delta * 5.0)
		$MODEL.global_transform.basis = $MODEL.global_transform.basis.slerp($MODEL.global_transform.looking_at(global_transform.origin - view_direction * 2.0, Vector3.UP).basis, delta * 5.0)
	else:
		linear_velocity = lerp(linear_velocity, Vector3.ZERO, delta * 5.0)
	
	linear_velocity.y -= GRAVITY * delta
	linear_velocity.y = clamp(linear_velocity.y, -1.0, GRAVITY)
	
	# Local look at to the View anchor node the ClippedCamera is attached to
	$VIEW_ANCHOR/ClippedCamera.transform = $VIEW_ANCHOR/ClippedCamera.transform.looking_at(Vector3.ZERO, Vector3.UP)
	$VIEW_ANCHOR/ClippedCamera.transform.origin = cam_origin
	
	$MODEL/Tree.set("parameters/speed/scale", 0.1 + linear_velocity.length() / 10.0)
	
	if $FloorSensor.is_colliding():
		$MODEL/Tree.set("parameters/state/current", int(Vector2(linear_velocity.x, linear_velocity.z).length() >= 0.5))
	
	if Input.is_mouse_button_pressed(2):
		parry_target = 1.0
	else:
		parry_target = 0.0
	
	if Input.is_mouse_button_pressed(1):
		$MODEL/Tree.set("parameters/attack/active", true)
	
	if Input.is_key_pressed(KEY_E):
		$MODEL/Tree.set("parameters/gesture/active", true)
	
	parry_val = lerp(parry_val, parry_target, delta * 9.0)
	
	$MODEL/Tree.set("parameters/parry/blend_amount", parry_val)
		
	#else:
	#	$MODEL/Tree.set("parameters/state/current", 2)
	
#	if $MODEL/gdquest_mannequin/root/foot_l.is_colliding():
#		$MODEL/gdquest_mannequin/root/Skeleton/foot_l_ik.start()
#		print("setting")
#		var i = $MODEL/gdquest_mannequin/root/Skeleton.find_bone("footl")
#		var t = $MODEL/gdquest_mannequin/root/Skeleton.get_bone_global_pose(i)
#		t.origin = ($MODEL/gdquest_mannequin/root/foot_l.get_collision_point() - $MODEL/gdquest_mannequin/root/Skeleton.global_transform.origin) + Vector3(0, 0.1, 0)
#		#t = t.looking_at(t.origin - $MODEL/gdquest_mannequin/root/Skeleton.global_transform.basis.z, Vector3.UP)
#		$MODEL/gdquest_mannequin/root/Skeleton/foot_l_pos.global_transform.origin = $MODEL/gdquest_mannequin/root/foot_l.get_collision_point()
#		$MODEL/gdquest_mannequin/root/Skeleton.set_bone_global_pose_override(i, t, 1.0, true)
#	else:
#		$MODEL/gdquest_mannequin/root/Skeleton.clear_bones_global_pose_override()
