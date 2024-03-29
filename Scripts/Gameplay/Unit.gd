extends Node2D

class_name AUnit


var CurrentRotation : int
var CurrentCord : Vector2i
var Controller : E.Player

var target_tile : HexTile
var target_rotation = rotation

var Symbols : Array[E.Symbols] = [ \
	E.Symbols.INVALID, E.Symbols.INVALID, E.Symbols.INVALID,
	E.Symbols.INVALID, E.Symbols.INVALID, E.Symbols.INVALID]

func _ready():
	var idx = -1
	for symbol_spot in get_node("Symbols").get_children():
		idx += 1
		var symbol = symbol_spot.get_children()
		if symbol.size() == 1:
			Symbols[idx] = symbol[0].type


func CanDefend(side : int) -> bool:
	return GetSymbol(side) == E.Symbols.SHIELD
		

func GetSymbol(side : int) -> E.Symbols:
	return Symbols[(side - CurrentRotation) % 6]

func Rotate(side : int):
	"""
	  360 / 6 = 60  degrees needed to rotate unit
	  
	  param Unit - Reference to the object we are rotating
	  param Direction
	"""
	CurrentRotation = side
	
	# 360 / 6 = 60 -> degrees needed to rotate unit
	# "Direction + 4" Accounts for global rotation setting for objects in the level
	rotation = deg_to_rad((60 * (side - 2)) + 30)  # TODO: -2 is "magic number" -- ?grid rotation
	#print(rotation, "   ", target_rotation)

func Move(target : HexTile):
	target_tile = target



func _physics_process(_delta):
	#if target_rotation != rotation:
		#rotation = move_toward(rotation, target_rotation, 0.1)
	
	if target_tile != null:	
		if BUS.animation_speed == BUS.animation_speed_values.INSTANT:
			position = target_tile.position
		else:
			position = position.move_toward(target_tile.position, BUS.animation_speed)
		#position.x = move_toward(position.x, target_tile.position.x, BUS.animation_speed)
		#position.y = move_toward(position.y, target_tile.position.y, BUS.animation_speed)
		if position.x == target_tile.position.x and position.y == target_tile.position.y:
			target_tile = null

func Destroy():
	queue_free()
