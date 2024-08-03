class_name DataUnit

extends Resource


@export var unit_name : String
@export var texture_path : String
@export var symbols : Array[DataSymbol] = [null,null,null,null,null,null]
@export var cost : Goods = Goods.new()
@export var required_building : DataBuilding = null
@export var level : int = 1
@export var mana : int = 0

static func get_network_id(unit : DataUnit) -> String:
	if not unit:
		return ""
	assert(unit.resource_path.begins_with(CFG.UNITS_PATH), \
			"unit serialization not supported")
	return unit.resource_path.trim_prefix(CFG.UNITS_PATH)


static func from_network_id(network_id : String) -> DataUnit:
	if network_id.is_empty():
		return null
	print("loading DataUnit - ","%s/%s" % [ CFG.UNITS_PATH, network_id ])
	return load("%s/%s" % [ CFG.UNITS_PATH, network_id ]) as DataUnit
