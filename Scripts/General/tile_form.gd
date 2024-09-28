class_name TileForm

extends Area2D

var coord : Vector2i

var type : String = "sentinel"

var hex = null # WorldHex in world

var grid_type : GameSetupInfo.GameMode = GameSetupInfo.GameMode.WORLD


static func create_world_editor_tile(data_tile : DataTile, coord_ : Vector2i,
		new_position : Vector2) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result._set_coord(coord_)
	result.name = "Tile_%s_%s" % [ coord_.x, coord_.y ]
	result.position = new_position
	if data_tile:
		var image = load(data_tile.texture_path)
		result.type = data_tile.type
		result._set_texture(image)
	return result



## ugly, FIXME
static func create_world_tile_new(hex_ : WorldHex, coord_ : Vector2i, \
		new_position : Vector2) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	var image = hex_.get_image()
	result.type = "SENTINEL"
	if hex_.place:
		assert(coord_ == hex_.place.coord)
		result.type = hex_.place.get_type()
	result._set_coord(coord_)
	result._set_texture(image)
	result.name = "Tile_%s_%s" % [ coord_, result.type ]
	result.position = new_position
	result.hex = hex_
	return result


static func create_world_tile(data: DataTile, new_coord : Vector2i, \
		new_place : Place) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result._set_coord(new_coord)
	result._set_texture(load(data.texture_path))
	result.type = data.type
	result.place = new_place
	result.name = "Tile_" + str(new_coord) + "_" + data.type
	return result


static func create_battle_tile(data: DataTile, new_coord : Vector2i) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result.grid_type = GameSetupInfo.GameMode.BATTLE
	result.type = data.type
	result._set_coord(new_coord)
	result._set_texture(load(data.texture_path))
	result.name = "Tile_" + str(new_coord) + "_" + data.type
	return result


func _on_input_event(_viewport : Node, event : InputEvent, _shape_idx : int):
	# normal gameplay - on click
	if event.is_action_pressed("KEY_SELECT"):
		UI.grid_input_listener(coord, grid_type, false)

	# for map editor - on mouse move while button pressed
	if Input.is_action_pressed("KEY_SELECT"):
		UI.grid_input_listener(coord, grid_type, true)


func to_battle_grid_enum() -> int:
	match type:
		"sentinel":   return 1
		"wall":       return 1
		"":			  return 1 # IMPASSABLE
		"blue_spawn": return 0
		"red_spawn":  return 0
		"empty":      return 0
	assert(false, "Unknown tile type while converting to TGFast enum: %s (@%s)" % [type, coord])
	return 1


func _process(_delta):
	$PlaceLabel.text = ""
	if hex and hex.place: #TEMP
		$PlaceLabel.text = hex.place.get_map_description()


func controller_changed():
	$ControlerSprite.visible = true
	var color_name : String = hex.place.controller.get_player_color().name

	var path = "res://Art/player_colors/%s_color.png" % color_name
	var texture = load(path) as Texture2D
	assert(texture, "failed to load background " + path)
	$ControlerSprite.texture = texture


## for map editor only
func paint(brush : DataTile) -> void:
	type = brush.type
	$Sprite2D.texture = load(brush.texture_path)


func _set_coord(new_coord: Vector2i):
	coord = new_coord
	$CoordLabel.text = str(new_coord)

func _set_texture(texture: Texture2D):
	$Sprite2D.texture = texture


