class_name BattleSetup
extends Control

const PLAYER_SLOT_PANEL_PATH = "res://Scenes/UI/Lobby/BattlePlayerSlotPanel.tscn"

var game_setup : GameSetup

var player_slot_panels: Array[BattlePlayerSlotPanel]= []

var client_side_map_label : Label

@onready var player_list = \
	$Slots/ColorRect/PlayerList

@onready var maps_list : OptionButton = \
	$MapSelect/ColorRect/MapList

@onready var presets_list : OptionButton = \
	$PresetSelect/ColorRect/PresetList


#region Initial Setup

func _ready():
	fill_maps_list()
	fill_presets_list()

	var number_of_presets = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_PRESETS_PATH, true, true).size()
	if number_of_presets > 0:
		if CFG.LAST_USED_BATTLE_PRESET:
			apply_preset(CFG.LAST_USED_BATTLE_PRESET)
		else:
			_on_preset_list_item_selected(0)


func fill_maps_list() -> void:
	var maps = IM.get_battle_maps_list()
	maps_list.clear()
	for map_name in maps:
		maps_list.add_item(map_name)


func fill_presets_list() -> void:
	var presets = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_PRESETS_PATH, true, true)
	presets_list.clear()
	for preset in presets:
		presets_list.add_item(preset.trim_prefix(CFG.BATTLE_PRESETS_PATH))




## Called upon join, applies changes to the UI to make it Client UI not Host UI
func make_client_side() -> void:
	$MapSelect/Label.text = "Selected map"
	maps_list.queue_free()
	maps_list = null
	client_side_map_label = Label.new()
	client_side_map_label.text = "some map"
	$MapSelect/ColorRect.add_child(client_side_map_label)
	var presets = $PresetSelect
	presets.queue_free()

#endregion


## Updates UI to match GameState in IM
func refresh() -> void:
	for index in range(player_slot_panels.size()):
		_refresh_slot(index)

	if client_side_map_label:
		var map_name = DataBattleMap.get_network_id(IM.game_setup_info.battle_map)
		client_side_map_label.text = map_name


## Updates BattlePlayerSlotPanel to match GameState in IM
func _refresh_slot(index : int) -> void:
	if index < 0 or index >= player_slot_panels.size():
		push_error("no ui slot to refresh on index ", index)
		return

	var ui_slot : BattlePlayerSlotPanel = player_slot_panels[index]
	var logic_slot : GameSetupInfo.Slot = \
		IM.game_setup_info.slots[index] if IM.game_setup_info.has_slot(index) \
			else null
	var color : DataPlayerColor = CFG.DEFAULT_TEAM_COLOR
	var username : String = ""
	var faction : DataFaction = null
	var take_leave_button_state : BattlePlayerSlotPanel.TakeLeaveButtonState =\
		BattlePlayerSlotPanel.TakeLeaveButtonState.GHOST
	if logic_slot:
		ui_slot.set_army(logic_slot.units_list)
		if logic_slot.occupier is String:
			if logic_slot.occupier == "":
				username = NET.get_current_login()
				take_leave_button_state = \
					BattlePlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_YOU
			else:
				username = logic_slot.occupier
				take_leave_button_state = \
					BattlePlayerSlotPanel.TakeLeaveButtonState.TAKEN_BY_OTHER
		else:
			username = "Computer\nlevel %d" % logic_slot.occupier
			take_leave_button_state = \
				BattlePlayerSlotPanel.TakeLeaveButtonState.FREE
		faction = logic_slot.faction
		color = CFG.get_team_color_at(logic_slot.color)
	ui_slot.set_visible_color(color.color)
	ui_slot.set_visible_name(username)
	ui_slot.set_visible_take_leave_button_state(take_leave_button_state)
	ui_slot.setup_ui = self
	ui_slot.set_bot(logic_slot.battle_bot_path)


func slot_to_index(slot) -> int:
	return player_slot_panels.find(slot)


#region Changing settings

## add missing path and calls apply_preset()
func _on_preset_list_item_selected(index) -> void:
	var preset_file = presets_list.get_item_text(index)
	var preset_data : PresetBattle = \
			load(CFG.BATTLE_PRESETS_PATH + "/" + preset_file)
	apply_preset(preset_data)

	# TODO - verify if its neccesary to imrpove on this simple solution
	CFG.player_options.last_used_battle_preset = preset_data
	CFG.save_player_options()


func apply_preset(preset : PresetBattle):
	var map_name = preset.battle_map.resource_path.get_file()
	var found_a_map : bool = false
	for i in range(maps_list.item_count):
		if maps_list.get_item_text(i) == map_name:
			maps_list.select(i)
			_on_map_list_item_selected(i)
			found_a_map = true
			break
	assert(found_a_map, "preset map not present in map pool")

	for player_idx in preset.armies.size():
		var army = preset.armies[player_idx]
		player_slot_panels[player_idx].apply_army_preset(army)

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)


func _on_map_list_item_selected(index):
	var map_name : String = maps_list.get_item_text(index)
	var map : DataBattleMap = load(CFG.BATTLE_MAPS_PATH + "/" + map_name)
	IM.game_setup_info.set_battle_map(map)

	prepare_player_slots()

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)


func prepare_player_slots() -> void:
	player_slot_panels = []
	for slot in player_list.get_children():
		player_list.remove_child(slot)
		slot.queue_free()

	var max_number_of_players : int = IM.game_setup_info.slots.size()

	for slot in IM.game_setup_info.slots:
		var slot_scene : BattlePlayerSlotPanel = load(PLAYER_SLOT_PANEL_PATH).instantiate()
		player_slot_panels.append(slot_scene)
		slot_scene.setup_ui = self

		player_list.add_child(slot_scene)

		slot_scene.fill_team_list(max_number_of_players)

	refresh()



func try_to_take_slot(slot) -> bool: # true means something changed
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_take_slot(index)
	if changed:
		_refresh_slot(index)
	return changed


func try_to_leave_slot(slot) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_leave_slot(index)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_color_slot(slot : BattlePlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_color_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed


func cycle_faction_slot(slot : BattlePlayerSlotPanel, backwards : bool) -> bool:
	if not game_setup:
		return false
	var index : int = slot_to_index(slot)
	var changed = game_setup.try_to_cycle_faction_slot(index, backwards)
	if changed:
		_refresh_slot(index)
	return changed

#endregion
