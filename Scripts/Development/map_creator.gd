extends CanvasLayer

@export var map_file_name_input : TextEdit

@export var new_map_width : int = 5
@export var new_map_height : int = 5


enum map_type
{
	WORLD,
	BATTLE,
}

var current_map_type : map_type


var current_brush : DataTile
var current_button: TextureButton

@onready var world_box : BoxContainer = $HWorldBox
@onready var battle_box : BoxContainer = $HBattleBox

#region Setup

# static func list_files_in_folder(folder_path : String, return_full_path : bool = false) -> Array[String]:
# 	var dir = DirAccess.open(folder_path)
# 	var scenes:Array[String] = []

# 	if dir:
# 		for file in dir.get_files():
# 			if return_full_path:
# 				scenes.append(folder_path + "/" + file)
# 			else:
# 				scenes.append(file)
# 	else:
# 		print("Error opening folder:", folder_path)
# 	dir = null
# 	return scenes



func _create_button(box : BoxContainer, map_tile : String):
	var tile = load(map_tile)

	var new_button = TextureButton.new()
	new_button.texture_normal = ResourceLoader.load(tile.texture_path)

	box.add_child(new_button)
	var lambda = func on_click():
		if current_button != null:
			current_button.modulate = Color.WHITE
		current_brush = tile
		current_button = new_button
		current_button.modulate = Color.DIM_GRAY

	new_button.pressed.connect(lambda)  # self._button_pressed


func _load_tiles(box : BoxContainer, path : String):

	var map_tiles_paths : Array[String] = TestTools.list_files_in_folder(path, true)
	for map_tile : String in map_tiles_paths:
		_create_button(box, map_tile)

func _ready():

	_load_tiles(battle_box, CFG.BATTLE_MAP_TILES_PATH)
	_load_tiles(world_box, CFG.WORLD_MAP_TILES_PATH)

#endregion


#region Tools

func grid_input(coord : Vector2i) -> void:
	if current_map_type == map_type.WORLD:
		W_GRID.tile_grid[coord.x][coord.y].type = current_brush.type
		W_GRID.tile_grid[coord.x][coord.y].get_node("Sprite2D").texture = ResourceLoader.load(current_brush.texture_path)
	else:
		B_GRID.tile_grid[coord.x][coord.y].type = current_brush.type
		B_GRID.tile_grid[coord.x][coord.y].get_node("Sprite2D").texture = ResourceLoader.load(current_brush.texture_path)


func _set_grid_type(new_type : map_type) -> void:
	if new_type == map_type.WORLD:
		current_map_type = map_type.WORLD
		world_box.visible = true
		battle_box.visible = false

	else:
		current_map_type = map_type.BATTLE
		world_box.visible = false
		battle_box.visible = true


func _optimize_grid_size(local_tile_grid : Array) -> Array:
	"""
	checks for the first and last non-sentinel tile placement in each grid row and column.
	Then it will remove all empty columns at map edges
	this function should be called during saving of a scene
	"""
	# # location of the first non sentinel tiles from:
	var left_pos : int = local_tile_grid.size()
	var right_pos : int = 0
	var top_pos : int = local_tile_grid[0].size()
	var bot_pos : int = 0
	for x in local_tile_grid.size():
		for y in local_tile_grid[0].size():
			if local_tile_grid[x][y].type != "sentinel":
				if left_pos > x:
					left_pos = x
				elif right_pos < x:
					right_pos = x
				if top_pos > y:
					top_pos = y
				if bot_pos < y:
					bot_pos = y
	for right in range(max(local_tile_grid.size() - right_pos - 1, 0)):
		local_tile_grid.pop_back()

	for left in range(max(left_pos, 0)):
		local_tile_grid.pop_front()

	var rows_at_the_back_to_remove : int = local_tile_grid[0].size() - bot_pos

	for column in local_tile_grid:
		for bot in range(max(rows_at_the_back_to_remove - 1, 0)):
			column.pop_back()

		for top in range(max(top_pos, 0)):
			column.pop_front()

	#print(left_pos, " ", right_pos, " ", top_pos, " ", bot_pos)
	return local_tile_grid


func open_draw_menu():
	visible = true
	_on_new_world_map_pressed()

func hide_draw_menu():
	visible = false

func _toggle_menu_status():
	visible = not visible

#endregion


#region Buttons:

func _on_load_map_pressed():
	var map_path = CFG.WORLD_MAPS_PATH
	if current_map_type == map_type.BATTLE:
		map_path = CFG.BATTLE_MAPS_PATH
	map_path += map_file_name_input.text + ".tres"
	var map_to_load = load(map_path)
	assert(map_to_load != null, "there is no selected map to be loaded")
	WM.close_world()
	BM.close_battle()
	if map_to_load is WorldMap:
		_set_grid_type(map_type.WORLD)
		W_GRID.generate_grid(map_to_load)
	else:
		_set_grid_type(map_type.BATTLE)
		B_GRID.generate_grid(map_to_load)


func _on_save_map_pressed():
	print("save map")
	var map_save_name : String = map_file_name_input.text

	var new_map
	var local_tile_grid : Array
	var save_path
	if current_map_type == map_type.WORLD:
		new_map = WorldMap.new()
		local_tile_grid = W_GRID.tile_grid
		save_path = CFG.WORLD_MAPS_PATH + map_save_name + ".tres"
	else:
		new_map = BattleMap.new()
		local_tile_grid = B_GRID.tile_grid
		save_path = CFG.BATTLE_MAPS_PATH + map_save_name + ".tres"

	var grid_data = []

	local_tile_grid = _optimize_grid_size(local_tile_grid.duplicate(true))

	for tile_column in local_tile_grid:
		var current_column = []
		grid_data.append(current_column)
		for tile in tile_column:
			var new_data_tile = DataTile.create_data_tile(tile)

			current_column.append(new_data_tile)


	new_map.grid_data = grid_data

	new_map.grid_height = grid_data[0].size()
	new_map.grid_width = grid_data.size()

	ResourceSaver.save(new_map, save_path)

	print("end save map")


func _generate_empty_map(size_x : int = 5, size_y : int = 5) -> Array: # -> Array[Array[DataTile]]
	WM.close_world()
	BM.close_battle()
	var grid_data = []

	for tile_column in range(size_x):
		var current_column = []
		grid_data.append(current_column)
		for tile in range(size_y):
			var new_data_tile = load(CFG.SENTINEL_TILE_PATH)

			current_column.append(new_data_tile)

	return grid_data



func _on_new_world_map_pressed():
	_set_grid_type(map_type.WORLD)
	world_box.get_children()[0].pressed.emit()  # default tile choice

	var new_map = WorldMap.new()
	var grid_data = _generate_empty_map()
	new_map.grid_data = grid_data

	new_map.grid_height = grid_data.size()
	new_map.grid_width = grid_data[0].size()
	#print(new_map.grid_height, " ", new_map.grid_width)

	W_GRID.generate_grid(new_map)


func _on_new_battle_map_pressed():
	_set_grid_type(map_type.BATTLE)
	battle_box.get_children()[0].pressed.emit()  # default tile choice

	var grid_data = _generate_empty_map()

	var new_map = BattleMap.new()

	new_map.grid_data = grid_data

	new_map.grid_height = grid_data.size()
	new_map.grid_width = grid_data[0].size()
	#print(new_map.grid_height, " ", new_map.grid_width)

	B_GRID.generate_grid(new_map)


#endregion

func _on_open_button_pressed():
	$FileDialog.root_subfolder = CFG.WORLD_MAPS_PATH \
		 if current_map_type == map_type.WORLD else CFG.BATTLE_MAPS_PATH
	$FileDialog.show()


func _on_file_dialog_file_selected(path : String):
	map_file_name_input.text = path.get_file().trim_suffix(".tres")
	_on_load_map_pressed()

func _on_back_button_pressed():
	hide()
	IM.go_to_main_menu()
