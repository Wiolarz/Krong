class_name GameSetupInfo
extends RefCounted

## Game Setup in the lobby, currently used only in multiplayer [br]
## Map chosen, info on game slots setup (factions, colors, etc) [br]
## TODO: start using in single player [br]
## TODO: synch slot count etc with map when changing maps [br]
## WARNING not a resource because we refer to players, sessions
## and other temporary objects that should not be saved

enum GameMode {
	UNKNOWN, ## forces to initialize
	WORLD, ## full map with heroes and economy
	BATTLE, ## single battle only, no economy
	MAP_EDITOR, ## special mode only for map editing
}

var game_mode : GameMode = GameMode.WORLD
var world_map : DataWorldMap ## used only in full world mode
var battle_map : DataBattleMap ## used only in battle mode
var slots : Array[Slot] ## slot for each player color on the map picked

func is_in_mode_world():
	return game_mode == GameMode.WORLD

func is_in_mode_battle():
	return game_mode == GameMode.BATTLE

func is_bot(player_index : int) -> bool:
	return slots[player_index].is_bot()

func has_slot(player_index : int) -> bool:
	return player_index >= 0 and player_index < slots.size()


func set_team(slot_index : int, team_idx : int):
	slots[slot_index].team = team_idx

## Gameplay setting a unit to memory
func set_unit(slot_index : int, unit_index : int, unit_data : DataUnit):
	slots[slot_index].units_list[unit_index] = unit_data

func set_battle_bot(slot_index: int, path: String):
	slots[slot_index].battle_bot_path = path

func to_dictionary(local_username : String = "") -> Dictionary:
	var result = {
		"game_mode": game_mode_to_str(),
		"world_map": DataWorldMap.get_network_id(world_map),
		"battle_map": DataBattleMap.get_network_id(battle_map),
		"slots": [],
	}
	for slot in slots:
		result["slots"].append({
			"occupier": GameSetupInfo.occupier_prepare_for_network( \
					slot.occupier, local_username),
			"faction": slot.faction.get_network_id(),
			"color": slot.color,
			"units_list": GameSetupInfo.units_list_prepare_for_network( \
					slot.units_list),
			"team": slot.team,
		})
	return result


static func from_dictionary(dict : Dictionary, \
		local_username : String = "") -> GameSetupInfo:
	var result = GameSetupInfo.new()
	if "game_mode" in dict and dict["game_mode"] is String:
		result.game_mode = GameSetupInfo.game_mode_from_str(dict["game_mode"])
	if "world_map" in dict and dict["world_map"] is String:
		result.world_map = DataWorldMap.from_network_id(dict["world_map"])
	if "battle_map" in dict and dict["battle_map"] is String:
		result.battle_map = DataBattleMap.from_network_id(dict["battle_map"])
	if "slots" in dict and dict["slots"] is Array:
		for i in dict["slots"].size():
			var read_slot : Dictionary = dict["slots"][i]
			var new_slot : Slot = Slot.new()
			new_slot.index = i
			if "occupier" in read_slot:
				new_slot.occupier = occupier_receive_from_network( \
					read_slot["occupier"], local_username)
			if "faction" in read_slot and read_slot["faction"] is String:
				new_slot.faction = \
					DataFaction.from_network_id(read_slot["faction"])
			if "color" in read_slot and read_slot["color"] is int:
				new_slot.color = read_slot["color"]
			if "units_list" in read_slot and read_slot["units_list"] is Array:
				new_slot.units_list = \
						GameSetupInfo.units_list_receive_from_network(read_slot["units_list"])
			if "team" in read_slot and read_slot["team"] is int:
				new_slot.team = read_slot["team"]
			result.slots.append(new_slot)
	return result


func game_mode_to_str() -> String:
	return GameMode.keys()[game_mode].to_lower()


static func game_mode_from_str(mode_as_str : String) -> GameMode:
	mode_as_str = mode_as_str.to_lower()
	for mode in GameMode.keys():
		if mode.to_lower() == mode_as_str:
			return GameMode[mode]
	push_error("Unknown game mode: \"%s\"" % mode_as_str)
	return GameMode.UNKNOWN


static func occupier_prepare_for_network(occupier, local_username : String):
	if occupier is String and occupier == "":
		return local_username
	return occupier


static func occupier_receive_from_network(occupier, local_username : String):
	if occupier is String and occupier == local_username:
		return ""
	if occupier is String or occupier is int:
		return occupier
	push_error("invalid occupier received ", occupier)


static func units_list_prepare_for_network(to_serialize: Array[DataUnit]) -> Array[String]:
	var result : Array[String] = []
	for u in to_serialize:
		result.append(DataUnit.get_network_id(u))
	return result


static func units_list_receive_from_network(serialized: Array) -> Array[DataUnit]:
	var result :Array[DataUnit] = []
	for s in serialized:
		result.append(DataUnit.from_network_id(s))
	return result


func set_battle_map(map : DataBattleMap):
	assert(game_mode == GameMode.BATTLE, "setting battle map in game mode: " + str(game_mode))
	battle_map = map

	var slots_number = map.player_slots.keys().size()
	set_slots_number(slots_number)

	for slot_idx in slots.size():
		slots[slot_idx].set_units_length(map.player_slots[slot_idx + 1])


func set_world_map(map: DataWorldMap):
	assert(game_mode == GameMode.WORLD, "setting world map in game mode: " + str(game_mode))

	world_map = map

	var map_slots_size = 2

	while slots.size() > map_slots_size:
		slots.pop_back()

	var taken_colors = []
	for slot in slots:
		taken_colors.append(slot.color)

	while slots.size() < map_slots_size:
		var slot = GameSetupInfo.Slot.new()
		slots.append(slot)
		var faction_idx = wrap(slots.size()-1, 0, CFG.FACTIONS_LIST.size())
		slot.faction = CFG.FACTIONS_LIST[faction_idx]
		slot.color = 0

		while slot.color in taken_colors:
			slot.color += 1

		taken_colors.append(slot.color)


static func create_empty() -> GameSetupInfo:
	var slot_count = 2
	var result = GameSetupInfo.new()
	result.slots.resize(slot_count)
	for i in range(slot_count):
		result.slots[i] = GameSetupInfo.Slot.new()
		result.slots[i].faction = CFG.FACTIONS_LIST[i]
		result.slots[i].color = i
		result.slots[i].index = i
	return result


func set_slots_number(number : int) -> void:

	# first we remove unused slots
	while slots.size() > number:
		slots.pop_back()

	# check which colors are used to avoid assigning them to new slots
	var taken_colors = []
	for slot in slots:
		taken_colors.append(slot.color)

	# add new slots
	while slots.size() < number:
		var index = slots.size()
		var slot = GameSetupInfo.Slot.new()
		slots.append(slot)

		slot.faction = CFG.FACTIONS_LIST[0]
		slot.color = 0
		slot.index = index

		while slot.color in taken_colors:
			slot.color += 1

		taken_colors.append(slot.color)



## Info for a single slot
class Slot extends RefCounted: # check if this is good base

	## occupier identifies who uses this slot [br]
	## its an `int` or a `String` [br]
	## `int` -> AI level eg. 1 [br]
	## `String == ""` -> we (local player) [br]
	## `String != ""` -> remote player with specified network name [br]
	var occupier = ""
	var battle_bot_path: String = ""

	## index of color see `CFG.TEAM_COLORS`
	var color : int = 0

	var faction : DataFaction = null

	## for battle only mode
	var units_list : Array[DataUnit] = [null,null,null,null,null]

	## used for some simpleness at player in world
	var index : int = -1

	var team : int = 0

	func _init():
		if CFG.player_options.use_default_AI_players:
			occupier = 0


	func is_bot() -> bool:
		return occupier is int


	func is_local() -> bool:
		return occupier.is_empty()


	func set_units_length(value : int) -> void:
		units_list.resize(value)


	## for "Custom battles" unit list creation
	## ignores empty values in units_list
	func get_units_list() -> Array[DataUnit]:
		var non_empty : Array[DataUnit] = []
		for unit in units_list:
			if not unit:
				continue
			non_empty.append(unit)
		return non_empty

	## for replays
	func set_units(new_units : Array[DataUnit]) -> void:
		for idx in range(units_list.size()):
			if idx >= new_units.size():
				units_list[idx] = null
				continue
			units_list[idx] = new_units[idx]


	func get_occupier_name(all_slots: Array[Slot]) -> String:
		if is_bot():
			return _get_bot_name(all_slots)
		if occupier == "":
			return NET.get_current_login()
		return occupier as String


	func _get_bot_name(all_slots: Array[Slot]) -> String:
		var number_of_ais : int = 0
		var index_of_this_ai : int = 0
		for slot in all_slots:
			if slot.is_bot():
				if slot == self:
					index_of_this_ai = number_of_ais
				number_of_ais += 1
		if number_of_ais == 1:
			return "AI"
		return "AI %s" % index_of_this_ai
