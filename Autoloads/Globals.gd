extends Node

var current_player

func play_sound(sound_name, db = -10):
	var player = AudioStreamPlayer.new()
	player.connect("finished", self, "on_audio_finished", [player])
	player.stream = load("res://Assets/Sounds/" + sound_name)
	get_node("/root").add_child(player)
	player.volume_db = db
	player.pitch_scale = Engine.time_scale
	player.play()

func on_audio_finished(player):
	player.queue_free()
