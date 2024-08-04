class_name Unit
extends RefCounted # default

signal unit_died()
signal unit_turned()
signal unit_moved()

var controller : Player

## units constant stats resource
var template : DataUnit

## coordinates on a battle grid
var coord : Vector2i

## see E.GridDirections, int for convinience
var unit_rotation : int

## unit died
var dead : bool

var spells : Array[BattleSpell] = []

var is_on_swamp : bool = false


static func create(new_controller : Player, \
		new_template : DataUnit, \
		new_coord : Vector2i, \
		new_rotation : GenericHexGrid.GridDirections) -> Unit:
	var result = Unit.new()
	result.controller = new_controller
	result.template = new_template
	result.coord = new_coord
	result.unit_rotation = new_rotation
	result.spells = new_template.spells
	return result


## turns unit front to a given side, can be awaited see waits_for_form
func turn(side : GenericHexGrid.GridDirections):
	if side == unit_rotation:
		return
	unit_rotation = side
	print("emit turn [turn]")
	unit_turned.emit()


## puts unit to a given coordinate, can be awaited see waits_for_form
func move(new_coord : Vector2i, is_swamp : bool):
	is_on_swamp = is_swamp

	var old = coord
	coord = new_coord
	print("emit move [move] %s %s" % [str(old), str(new_coord)])
	unit_moved.emit()


## kills unit, can be awaited see waits_for_form
func unit_killed():
	dead = true
	unit_died.emit()


func can_defend(side : int) -> bool:
	return get_symbol(side) == E.Symbols.SHIELD


## gets symbol facing specified directin on the battle map
func get_symbol(side_world : int) -> E.Symbols:
	return get_symbol_when_rotated(side_world, unit_rotation)


## gets symbol facing specified directin on the battle map, if unit was rotated in given dir
func get_symbol_when_rotated(side_world : int, hypotetical_rotation : int) -> E.Symbols:
	if is_on_swamp:
		return E.Symbols.EMPTY
	var side_local : int = GenericHexGrid.rotate_clockwise( \
			side_world as GenericHexGrid.GridDirections, -hypotetical_rotation)
	return template.symbols[side_local].type


func get_front_symbol() -> E.Symbols:
	if is_on_swamp:
		return E.Symbols.EMPTY
	return template.symbols[GenericHexGrid.DIRECTION_FRONT].type


func get_player_color() -> DataPlayerColor:
	if not controller:
		return CFG.NEUTRAL_COLOR
	return controller.get_player_color()
