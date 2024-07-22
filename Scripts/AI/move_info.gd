class_name MoveInfo
extends Resource

const TYPE_MOVE = "move"
const TYPE_SUMMON = "summon"

@export var move_type: String = ""
@export var summon_unit: DataUnit
@export var move_source: Vector2i
@export var target_tile_coord: Vector2i

# REPLAY ONLY DATA:
@export var time_left_ms : int

# for undo, do not serialize

## index of the army that performed the move, used to recreate proper current player
var army_idx : int = -1
## used to recreate proper main unit rotation
var original_rotation : int = -1
## sequence of KilledUnit, PushedUnit, LocomotionCompleted in order they happended
var actions_list : Array = []


static func make_move(src : Vector2i, dst : Vector2i) -> MoveInfo:
	var result:MoveInfo = MoveInfo.new()
	result.move_type = TYPE_MOVE
	result.move_source = src
	result.target_tile_coord = dst
	return result


static func make_summon(unit : DataUnit, dst : Vector2i) -> MoveInfo:
	var result:MoveInfo = MoveInfo.new()
	result.move_type = TYPE_SUMMON
	result.summon_unit = unit
	result.target_tile_coord = dst
	return result


func to_network_serializable() -> Dictionary:
	return {
		"move_type" : move_type,
		"move_source" : move_source,
		"target_tile_coord": target_tile_coord,
		"summon_unit": DataUnit.get_network_id(summon_unit),
	}


static func from_network_serializable(dict : Dictionary) -> MoveInfo:
	match dict["move_type"]:
		MoveInfo.TYPE_SUMMON:
			return MoveInfo.make_summon( \
				DataUnit.from_network_id(dict["summon_unit"]),\
					dict["target_tile_coord"])
		MoveInfo.TYPE_MOVE:
			return MoveInfo.make_move(dict["move_source"],
					dict["target_tile_coord"])
	push_error("move_type not supported: ", dict["move_type"])
	return null


#region notyfications for undo

func register_move_start(army_idx_ : int, unit:Unit) -> void:
	army_idx = army_idx_
	original_rotation = unit.unit_rotation
	actions_list = []


func register_turning_complete() -> void:
	pass


func register_kill(killed_unit_army_idx : int, killed_unit : Unit) -> void:
	var record = KilledUnit.create(killed_unit_army_idx, killed_unit)
	actions_list.append(record)


func register_push(pushed_unit : Unit, goal_coord : Vector2i) -> void:
	var record = PushedUnit.create(pushed_unit.coord, goal_coord)
	actions_list.append(record)


func register_locomote_complete() -> void:
	actions_list.append(LocomotionCompleted.new())


func register_whole_move_complete() -> void:
	pass

#endregion notyfications for undo

func _to_string() -> String:
	if move_type == TYPE_SUMMON:
		return TYPE_SUMMON + " " + str(target_tile_coord) + " " + summon_unit.unit_name
	return move_type + " " + str(target_tile_coord) + " from " + str(move_source)


class KilledUnit:
	var army_idx: int
	var template : DataUnit
	var coord : Vector2i
	var unit_rotation : int

	static func create(army_idx_:int, unit:Unit) -> KilledUnit:
		var result = KilledUnit.new()
		result.army_idx = army_idx_
		result.coord = unit.coord
		result.template = unit.template
		result.unit_rotation = unit.unit_rotation
		return result

	func respawn() -> Unit:
		var result = Unit.new()
		result.coord = coord
		result.template = template
		result.unit_rotation = unit_rotation
		return result


class PushedUnit:
	var from_coord : Vector2i
	var to_coord : Vector2i

	static func create(from_coord_:Vector2i, to_coord_:Vector2i) -> PushedUnit:
		var result = PushedUnit.new()
		result.from_coord = from_coord_
		result.to_coord = to_coord_
		return result

## marker for when main unit switched tile
class LocomotionCompleted:
	pass
