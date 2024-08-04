class_name BattleUI
extends CanvasLayer

@onready var players_box : BoxContainer = $Players

@onready var units_box : BoxContainer = $Units

@onready var camera_button : Button = $SwitchCamera

@onready var summary_container : Container = $SummaryContainer

@onready var clock = $TurnsBG/ClockLeft
@onready var turns = $TurnsBG/TurnCount

@onready var cyclone = $CycloneTimer/CycloneTarget

@onready var book = $SpellBook

var armies_reference : Array[BattleGridState.ArmyInBattleState]

var selected_unit : DataUnit = null
var selected_unit_button : TextureButton = null
var current_player : int = 0


func _ready():
	pass


func _process(_delta):
	if BM.battle_is_active():
		update_clock()
		update_cyclone()


func update_cyclone():
	var timer : int = BM.get_cyclone_timer()
	var target : Player = BM.get_cyclone_target()

	#TEMP
	var target_color = BM.get_player_color(target)
	cyclone.modulate = target_color.color

	
	if timer == 0:
		cyclone.text = "%s Sacrifice" % [target_color.name]
	else:
		cyclone.text = "%s %d turns" % [target_color.name, timer]


func update_clock() -> void:
	var miliseconds_left = BM.get_current_time_left_ms()
	var seconds = miliseconds_left/1000.0
	var minutes = floor(seconds / 60)
	seconds -= minutes * 60
	var ms = 1000*(seconds-floor(seconds))

	clock.text = "%2.0f : %02.0f : %03.0f" % [minutes, floor(seconds), ms]
	clock.modulate = BM.get_current_slot_color().color

	turns.text = "Turn %d" % [BM.get_current_turn()]


func get_text_for(controller : Player, selected : bool):
	var prefix = " > " if selected else ""
	var player_name = "Neutral"
	if controller:
		player_name = controller.get_player_name()
	return prefix + "Player " + player_name


func load_armies(army_list : Array[BattleGridState.ArmyInBattleState]):
	# Disable "Switch camera" button for non world map gameplay
	camera_button.disabled = IM.game_setup_info.game_mode != GameSetupInfo.GameMode.WORLD

	# save armies
	armies_reference = army_list

	# removing placeholder elements
	while players_box.get_child_count() > 1:
		var c = players_box.get_child(1)
		c.queue_free()
		players_box.remove_child(c)

	units_box.show()

	var idx = 0
	for army in army_list:
		var controller = army.army_reference.controller
		# create player buttons
		var n = Button.new()
		n.text = get_text_for(controller, idx == 0)
		if controller:
			n.modulate = controller.get_player_color().color
		else:
			n.modulate = Color.GRAY
		n.pressed.connect(func select(): on_player_selected(idx, true))
		players_box.add_child(n)
		idx += 1


func load_spells(spells : Array[BattleSpell]) -> void:
	book.text = spells[0].name


func reset_spells() -> void:
	book.text = "Book"


func start_player_turn(army_index : int):
	on_player_selected(army_index, false)


func on_player_selected(army_index : int, preview : bool = false):
	selected_unit = null
	selected_unit_button = null

	if not preview:
		current_player = army_index

	for i in range(armies_reference.size()):
		var is_currently_active := (i == current_player)
		var controller = armies_reference[i].army_reference.controller
		var button := players_box.get_child(i + 1) as Button
		button.text = get_text_for(controller, is_currently_active)


	# clean bottom row
	for old_buttons in units_box.get_children():
		old_buttons.queue_free()

	var units_controller : Player = armies_reference[army_index].army_reference.controller
	var bg_color : DataPlayerColor = CFG.NEUTRAL_COLOR
	if units_controller:
		bg_color = units_controller.get_player_color()
	for unit in armies_reference[army_index].units_to_summon:
		var b := TextureButton.new()
		b.texture_normal = CFG.SUMMON_BUTTON_TEXTURE

		var unit_display := UnitForm.create_for_summon_ui(unit, bg_color)
		unit_display.position = b.texture_normal.get_size()/2
		b.add_child(unit_display)

		units_box.add_child(b)
		var lambda = func on_click():
			if (current_player != army_index):
				return
			if selected_unit_button:
				selected_unit_button.modulate = Color.WHITE
			selected_unit = unit
			selected_unit_button = b
			selected_unit_button.modulate = Color.RED
		b.pressed.connect(lambda)


func unit_summoned(summon_phase_end : bool):
	selected_unit = null
	selected_unit_button = null

	units_box.visible = not summon_phase_end


func refresh_after_undo(summon_phase_active : bool):
	units_box.visible = summon_phase_active


func _on_switch_camera_pressed():
	UI.switch_camera()
	if UI.current_camera_position == E.CameraPosition.WORLD:
		camera_button.text = "Show Battle"
	else :
		camera_button.text = "Show World"


func _on_menu_pressed():
	IM.toggle_in_game_menu()
