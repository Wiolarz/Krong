class_name TileGridFast extends TileGridFastCpp


static func from(bgstate: BattleGridState):
	var new = TileGridFast.new()
	new.set_map_size(Vector2i(bgstate.width, bgstate.height))
	
	for x in bgstate.width:
		for y in bgstate.height:
			var i = Vector2i(x,y)
			var hex = bgstate._get_battle_hex(i)
			new.set_tile(i, 
				hex.can_be_moved_to,
				not hex.can_shoot_through,
				hex.swamp,
				hex.spawn_point_army_idx,
				hex.spawn_direction
			)
	return new
