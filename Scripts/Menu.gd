"""
ESC - exit game
F1 - restart level
F2 - maximize window
F3 - cheat codes (immortality)
"""

extends Node


var maximize = false
@onready var ui = $".."

func _ready():
	if maximize:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_delta):
	if Input.is_action_just_pressed("MENU"):
		ui.visible = not ui.visible
		get_tree().set_deferred("paused", ui.visible)



func _on_back_to_game_pressed():
	ui.visible = not ui.visible
	get_tree().set_deferred("paused", ui.visible)


func _on_restart_pressed():
	_on_back_to_game_pressed()
	get_tree().reload_current_scene()


func _on_full_screen_pressed():
		if not maximize:
			maximize = true
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)  # there is a grey border around the screen 
			# https://github.com/godotengine/godot/issues/63500
		else:
			maximize = false
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_quit_pressed():
	get_tree().quit()
