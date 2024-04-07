# Singleton - WM
extends Node

#region Setup Parameters
"""
Current simplifications:
1 All players are host-seat
2 Basic same map
3 Same game parameters set as const

"""

var players : Array[Player] = []

#endregion


#region Variables

var current_player : Player

""" grid
contains:
	Places - Resource node /+ Neutral camp
	Cities
	Terrain blocks
	Sentinels
"""
# stores all location objects with common parent class "Place" as coordinates
var grid : Array = [] #Array[Array[Place]]


var selected_hero : Army  # Only army that has a hero can move (army can only have a single hero)

var combat_tile : Vector2i

#endregion


#region Main functions
	

func next_player_turn():
	var player_idx = players.find(current_player)
	if player_idx + 1 == players.size():
		current_player = players[0]
	else:
		current_player = players[player_idx + 1]

#endregion


#region Player Actions

func grid_input(cord : Vector2i):
	"""
	I no hero selected
	if owned city/army:
		select()

	II hero selected
	if enemy_present:
		attack()
	elif city/army:
		trade()
	elif can_move_there:
		move()
	"""

	var selected_spot_type : String = W_GRID.get_interactable_type(cord)

	if selected_hero == null:
		if selected_spot_type == "army":
			var army = W_GRID.get_army(cord)
			if current_player == army.controller:
				selected_hero = army
		elif selected_spot_type == "city":
			var city = W_GRID.get_city(cord)
			if city.controller == current_player:
				#TODO CITY you could select current city here
				city_show_interface(city)
		return
	
	else: # hero is selected
		#TEMP in future there will be pathfiding here
		if not GridManager.is_adjacent(selected_hero.cord, cord):
			selected_hero = null
			return

		if W_GRID.is_enemy_present(cord, current_player):
			start_combat(cord)

		if selected_spot_type == "army":
			var army = W_GRID.get_army(cord)
			if current_player == army.controller:
				# ARMY TRADE
				trade_armies(army)

		elif selected_spot_type == "city":
			var city = W_GRID.get_city(cord)
			if city.controller == current_player:
				# CITY TRADE
				trade_city(city)
				pass
		else:
			if not W_GRID.is_moveable(cord):
				W_GRID.change_hero_position(selected_hero, cord)




func trade_armies(second_army : Army):
	#TODO
	pass


#endregion


#region City Management


func trade_city(city : City):
	#TODO
	pass


func city_show_interface(city : City):
	print("city shows interface")

"""


"""

#endregion


#region Battles

func start_combat(cord : Vector2i):
	"""
	Starts a battle using Battle Manager (BM)
	"""
	print("start_combat")
	IM.raging_battle = true

	combat_tile = cord
	
	IM.switch_camera()

	var armies : Array[Army] = [selected_hero.army, W_GRID.get_army(combat_tile)]
	var battle_map : BattleMap = W_GRID.grid[combat_tile.x][combat_tile.y].battle_map

	BM.start_battle(armies, battle_map)


func end_of_battle():
	#TODO get result from Battle Manager
	var result : bool = BM.get_battle_result()
	if result:
		print("you won")
		kill_army(W_GRID.get_army(combat_tile)) # clear the tile of enemy presence
		W_GRID.change_hero_position(selected_hero, combat_tile)
	else:
		selected_hero = null
		print("hero died")
		kill_army(selected_hero)  # clear the tile where selected_hero was
	

func kill_army(army : Army):
	W_GRID.unit_grid[army.cord.x][army.cord.y] = null  # there can only be one army at a single tile
	army.queue_free()

# endregion


#region World End

func close_world():
	for hero in get_children():
		hero.queue_free()

	W_GRID.reset_data()

#endregion


#region World Setup

func start_world(world_map : WorldMap) -> void:

	var spawn_location = world_map.get_spawn_locations()

	for cord in spawn_location:
		print("spawn: ", cord + Vector2i(GridManager.border_size, GridManager.border_size))


	players = IM.get_active_players()

	assert(players.size() != 0, "ERROR WM.players is empty")
	
	current_player = players[0]


	IM.raging_battle = false

	W_GRID.generate_grid(world_map)
	
#endregion
