extends Control

func _ready():
	$Label_Backstab.visible = false
	$PanelContainer_Gestures.visible = false
	$PanelContainer_Gestures/VBoxContainer/HBoxContainer/Button_0.connect("pressed", self, "on_gesture", [0])
	$PanelContainer_Gestures/VBoxContainer/HBoxContainer/Button_1.connect("pressed", self, "on_gesture", [1])
	Globals.current_player.connect("on_update_health", self, "update_health")
	Globals.current_player.connect("on_update_stamina", self, "update_stamina")
	Globals.current_player.connect("on_update_magicka", self, "update_magicka")
	Globals.current_player.connect("on_toggle_backstab", self, "toggle_backstab")
	Globals.current_player.connect("on_death", self, "die")
	

func _process(delta):
	if Input.is_action_just_pressed("gp_menu"):
		$PanelContainer_Gestures.visible = !$PanelContainer_Gestures.visible
	if $PanelContainer_Gestures.visible:
		if Input.is_action_just_pressed("gp_dpad_l"):
			$PanelContainer_Gestures/VBoxContainer/HBoxContainer/Button_0.emit_signal("pressed")
			$PanelContainer_Gestures.visible = false
		if Input.is_action_just_pressed("gp_dpad_r"):
			$PanelContainer_Gestures/VBoxContainer/HBoxContainer/Button_1.emit_signal("pressed")
			$PanelContainer_Gestures.visible = false

func toggle_backstab(target, sensor_origin, enabled):
	$Label_Backstab.visible = enabled

func update_health(value):
	$HBoxContainer_Stats/VBoxContainer/ProgressBar_health.value = float(value)
func update_stamina(value):
	$HBoxContainer_Stats/VBoxContainer/ProgressBar_stamina.value = float(value)
func update_magicka(value):
	$HBoxContainer_Stats/VBoxContainer/ProgressBar_magicka.value = float(value)

func on_gesture(index):
	print("yes")
	Globals.current_player.emit_signal("on_gesture", index)
func die():
	$DEATH/AnimationPlayer.play("default")
func restart():
	get_tree().reload_current_scene()
