# Singleton B-GRID
extends GridNode2D

var tile_grid : GenericHexGrid # Grid<TileForm>

func load_map(map : DataBattleMap) -> void:
	assert(is_clear(), "cannot load map, map already loaded")
	tile_grid = GenericHexGrid.new(map.grid_width, map.grid_height, null)
	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var coord = Vector2i(x, y)
			var data = map.grid_data[x][y] as DataTile
			var tile_form = TileForm.create_battle_tile(data, coord)
			tile_grid.set_hex(coord, tile_form)
			tile_form.position = to_position(coord)
			tile_form.name = "Tile_" + data.type + "_" + str(coord)
			add_child(tile_form)


func is_clear() -> bool:
	return get_child_count() == 0 and tile_grid == null


func reset_data():
	tile_grid = null
	for c in get_children():
		c.queue_free()
		remove_child(c)


func get_tile(coord : Vector2i) -> TileForm:
	return tile_grid.get_hex(coord)


## for map editor only
func paint(coord : Vector2i, brush : DataTile) -> void:
	get_tile(coord).paint(brush)


func get_bounds_global_position() -> Rect2:
	if is_clear():
		push_warning("asking not initialized grid for camera bounding box")
		return Rect2(0, 0, 0, 0)
	var top_left_tile_form := get_tile(Vector2i(0,0))
	var bottom_right_tile_form := get_tile(Vector2i(tile_grid.width-1, tile_grid.height-1))
	var size : Vector2 = bottom_right_tile_form.global_position - top_left_tile_form.global_position
	return Rect2(top_left_tile_form.global_position, size)