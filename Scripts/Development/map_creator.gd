extends CanvasLayer


@export var save_box_input : TextEdit
@export var load_box_input : TextEdit

@export var new_map_width : int = 5
@export var new_map_height : int = 5


enum map_type
{
	WORLD,
	BATTLE,
}

var current_map_type : map_type

var world_map_tiles : Array[DataTile] = []

@onready var empty_battle_map : BattleMap = load("res://Resources/Battle_Maps/empty_map.tres")
@onready var empty_world_map : WorldMap = load("res://Resources/World_Maps/empty_map.tres")

@onready var current_brush : DataTile

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



func _ready():
	var world_map_tiles_paths : Array[String] = TestTools.list_files_in_folder("res://Resources/World_tiles/", true)
	for world_map_tile in world_map_tiles_paths:
		world_map_tiles.append(load(world_map_tile))
	
	var box = get_node("VWorldBox")

	current_brush = world_map_tiles[0]

	for button in world_map_tiles:
		var new_button = TextureButton.new()

		new_button.texture_normal = ResourceLoader.load(button.texture_path)

		box.add_child(new_button)
		var lambda = func on_click():
			current_brush = button
		
		new_button.pressed.connect(lambda)  # self._button_pressed

#endregion


#region Tools

func grid_input(cord : Vector2i) -> void:
	if current_map_type == map_type.WORLD:
		W_GRID.hex_grid[cord.x][cord.y].type = current_brush.type
		W_GRID.hex_grid[cord.x][cord.y].get_node("Sprite2D").texture = ResourceLoader.load(current_brush.texture_path)
	else:
		B_GRID.tile_grid[cord.x][cord.y].type = current_brush.type
		B_GRID.tile_grid[cord.x][cord.y].get_node("Sprite2D").texture = ResourceLoader.load(current_brush.texture_path)


func _set_grid_type(new_type : map_type) -> void:
	if new_type == map_type.WORLD:
		current_map_type = map_type.WORLD


	else:
		current_map_type = map_type.BATTLE

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
	
	print(left_pos, " ", right_pos, " ", top_pos, " ", bot_pos)
	return local_tile_grid
	




func open_draw_menu():
	visible = true

func hide_draw_menu():
	visible = false

func _toggle_menu_status():
	visible = not visible

#endregion


#region Buttons:

func _on_load_map_pressed():

	var map_to_load = load("res://Resources/" + load_box_input.text + ".tres")
	assert(map_to_load != null, "there is no selected map to be loaded")

	if map_to_load is WorldMap:
		WM.close_world()
		current_map_type = map_type.WORLD
		W_GRID.generate_grid(map_to_load)
	else:
		BM.end_of_battle()
		current_map_type = map_type.BATTLE
		B_GRID.generate_grid(map_to_load)




func _on_save_map_pressed():
	print("save map")
	var map_save_name : String = save_box_input.text

	var new_map
	var local_tile_grid : Array
	var save_path
	if current_map_type == map_type.WORLD:
		new_map = WorldMap.new()
		local_tile_grid = W_GRID.hex_grid
		save_path = "res://Resources/World_Maps/" + map_save_name + ".tres"
	else:
		new_map = BattleMap.new()
		local_tile_grid = B_GRID.tile_grid
		save_path = "res://Resources/Battle_Maps/" + map_save_name + ".tres"

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
	


func _on_new_world_map_pressed():
	_set_grid_type(map_type.WORLD)
	WM.close_world()


	var grid_data = []

	for tile_column in range(5):
		var current_column = []
		grid_data.append(current_column)
		for tile in range(5):
			var new_data_tile = load("res://Resources/World_tiles/sentinel.tres")

			current_column.append(new_data_tile)

	var new_map = WorldMap.new()
		
	new_map.grid_data = grid_data

	new_map.grid_height = grid_data.size()
	new_map.grid_width = grid_data[0].size()
	print(new_map.grid_height, " ", new_map.grid_width)

	W_GRID.generate_grid(new_map)


func _on_new_battle_map_pressed():
	_set_grid_type(map_type.BATTLE)

	B_GRID.generate_grid(empty_battle_map)


#endregion


