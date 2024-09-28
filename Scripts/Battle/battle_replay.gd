class_name BattleReplay
extends Resource

## Time.get_datetime_string_from_system()
@export var timestamp : String
@export var battle_map : DataBattleMap
## per player [ list of units ] : Array[Array[DataUnit]]
@export var units_at_start = []
## list of all actions made by players
@export var moves : Array[MoveInfo] = []
@export var player_names : Array[String] = []


static func create(armies : Array[Army], c_battle_map: DataBattleMap):
	var result = BattleReplay.new()

	for army in armies:
		var player = IM.get_player_by_index(army.controller_index)

		var player_name = IM.get_player_name(player)
		result.player_names.append(player_name)

	result.timestamp = Time.get_datetime_string_from_system()
	result.battle_map = c_battle_map
	for a in armies:
		result.units_at_start.append(a.get_units_list())
	return result


func record_move(m : MoveInfo, time_left_ms : int) -> void:
	m.time_left_ms = time_left_ms
	moves.append(m)


func get_filename() -> String:
	var timestamp_for_filename = timestamp.replace(":", "_")
	var all_player_names = "_".join(player_names)
	return "%s-%s.tres" % [timestamp_for_filename, all_player_names]


func save():
	BattleReplay.prepare_replay_directory()
	ResourceSaver.save(self, CFG.REPLAY_DIRECTORY + get_filename())

func save_as(name: String):
	var replay = self.duplicate()
	replay.player_names.push_back(name)
	replay.save()

func get_player_name(army_idx : int) -> String:
	if not player_names or army_idx >= player_names.size():
		return "unknown"
	return player_names[army_idx]

static func prepare_replay_directory():
	DirAccess.make_dir_recursive_absolute(CFG.REPLAY_DIRECTORY)


static func has_replays():
	if not DirAccess.dir_exists_absolute(CFG.REPLAY_DIRECTORY):
		return false
	var replays = DirAccess.get_files_at(CFG.REPLAY_DIRECTORY)
	return replays.size() > 0
