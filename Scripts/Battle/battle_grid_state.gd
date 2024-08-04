class_name BattleGridState
extends GenericHexGrid

const STATE_SUMMONNING = "summonning"
const STATE_FIGHTING = "fighting"
const STATE_SACRIFICE = "sacrifice"
const STATE_MAGIC = "magic"
const STATE_BATTLE_FINISHED = "battle_finished"

const MOVE_IS_INVALID = -1

#TODO implement repeated moves detection
const STALEMATE_TURN_COUNT = 3 # number of repeated moves that fast forward Mana Cyclon Timer

var state : String = ""
var turn_counter : int = 0
var current_army_index : int = 0
var armies_in_battle_state : Array[ArmyInBattleState] = []

var currently_processed_move_info : MoveInfo = null

var number_of_mana_wells : int = 0
var cyclone_target : ArmyInBattleState


#region init

func _init(width_ : int, height_ : int):
	super(width_, height_, BattleHex.sentinel)


static func create(map: DataBattleMap, new_armies : Array[Army]) -> BattleGridState:
	var result := BattleGridState.new(map.grid_width, map.grid_height)
	result.state = STATE_SUMMONNING
	for army in new_armies:
		result.armies_in_battle_state.append(ArmyInBattleState.create_from(army, result))


	result.current_army_index = 0
	result.turn_counter = 0

	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var map_tile : DataTile = map.grid_data[x][y]
			var new_hex = BattleHex.create(map_tile)
			result.set_hex(Vector2i(x,y), new_hex)

			if new_hex and new_hex.is_mana_tile(): # MANA
				result.number_of_mana_wells += 1

	result.mana_values_changed()

	return result

#endregion


#region move_info support


func move_info_summon_unit(move_info : MoveInfo) -> Unit:
	assert(move_info.move_type == MoveInfo.TYPE_SUMMON)
	currently_processed_move_info = move_info
	var unit_data := move_info.summon_unit
	var coord := move_info.target_tile_coord
	var initial_rotation := _get_spawn_rotation(coord)
	var army_state := armies_in_battle_state[current_army_index]
	var unit := army_state.summon_unit(unit_data, coord, initial_rotation)
	move_info.army_idx = current_army_index
	move_info.original_rotation = initial_rotation

	_put_unit_on_grid(unit, coord)
	_switch_participant_turn()
	currently_processed_move_info = null
	return unit


## Unpacker of MoveInfo class |
## Calls specific methods based on 'move_info.move_type'
func move_info_execute(move_info : MoveInfo) -> void:
	currently_processed_move_info = move_info
	
	var source_tile_coord := move_info.move_source

	var unit = get_unit(source_tile_coord)


	match move_info.move_type:
		MoveInfo.TYPE_MOVE:
			var target_tile_coord := move_info.target_tile_coord
			var direction = GenericHexGrid.direction_to_adjacent(unit.coord, target_tile_coord)

			move_info.register_move_start(current_army_index, unit)
			_perform_move(unit, direction, target_tile_coord)
			move_info.register_whole_move_complete()

		MoveInfo.TYPE_SACRIFICE:
			turn_counter -= 1 #TEMP? Doesn't move the turn counter
			move_info.register_kill(_get_army_index(cyclone_target), unit)

			_kill_unit(unit)
		
		MoveInfo.TYPE_MAGIC:
			var target_tile_coord := move_info.target_tile_coord
			var spell = move_info.spell
			#var direction = GenericHexGrid.direction_to_adjacent(unit.coord, target_tile_coord)
			var direction = 0 #TEMP
			move_info.register_move_start(current_army_index, unit) # undo related

			_perform_magic(unit, direction, target_tile_coord, spell) # KEY FUNCTION

			move_info.register_whole_move_complete() # TEMP check what it was supposed to do
			
	turn_counter += 1
	currently_processed_move_info = null

	if battle_is_ongoing():
		_check_battle_end()  # Can change battle_is_ongoing result
	if battle_is_ongoing():
		_switch_participant_turn()



## returns array of revived units
func undo(move_info : MoveInfo) -> Array[Unit]:
	var result = [] as Array[Unit]
	if move_info.move_type == MoveInfo.TYPE_SUMMON:
		current_army_index = move_info.army_idx
		armies_in_battle_state[current_army_index].unsummon(move_info.target_tile_coord)
		state = STATE_SUMMONNING

	if move_info.move_type == MoveInfo.TYPE_MOVE:
		# revert turn change
		current_army_index = move_info.army_idx
		turn_counter -= 1

		var actions_to_undo = move_info.actions_list.duplicate()
		# last action should be reversed first, else bugs will be created
		actions_to_undo.reverse()
		for a in actions_to_undo:
			if a is MoveInfo.KilledUnit:
				var u = _undo_kill(move_info, a)
				result.append(u)
			elif a is MoveInfo.PushedUnit:
				_undo_push(move_info, a)
			elif a is MoveInfo.LocomotionCompleted:
				_undo_main_locomotion(move_info)
			else :
				push_error("unknown action type %s - %s"%[a.get_class(), str(a)])

		# revert turn
		var unit := get_unit(move_info.move_source)
		unit.turn(move_info.original_rotation)

	return result


func _undo_main_locomotion(move_info : MoveInfo) -> void:
	var m_unit := get_unit(move_info.target_tile_coord)
	_change_unit_coord(m_unit, move_info.move_source)
	var m_hex = _get_battle_hex(move_info.move_source)
	m_unit.move(move_info.move_source, m_hex.swamp)


func _undo_kill(_move: MoveInfo , killed : MoveInfo.KilledUnit) -> Unit:
	var u := armies_in_battle_state[killed.army_idx].revive(killed)
	_put_unit_on_grid(u, u.coord)
	return u


func _undo_push(_move : MoveInfo , pushed : MoveInfo.PushedUnit) -> void:
	var p_unit := get_unit(pushed.to_coord)
	_change_unit_coord(p_unit, pushed.from_coord)
	var p_hex = _get_battle_hex(pushed.from_coord)
	p_unit.move(pushed.from_coord, p_hex.swamp)


func _perform_move(unit : Unit, direction : int, target_tile_coord : Vector2i) -> void:
	# TURN
	unit.turn(direction)
	if _process_symbols(unit):
		return
	currently_processed_move_info.register_turning_complete()
	# MOVE
	_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, _get_battle_hex(target_tile_coord).swamp)
	currently_processed_move_info.register_locomote_complete()
	if _process_symbols(unit):
		return


func _perform_magic(unit : Unit, direction : int, target_tile_coord : Vector2i, spell : BattleSpell) -> void:
	# TURN
	unit.turn(direction)
	if _process_symbols(unit): #TEMP think about design if there should a turn at all
		return
	currently_processed_move_info.register_turning_complete()

	# SPELLCAST
	"""_change_unit_coord(unit, target_tile_coord)
	unit.move(target_tile_coord, _get_battle_hex(target_tile_coord).swamp)
	currently_processed_move_info.register_locomote_complete()
	if _process_symbols(unit):
		return"""

#endregion move_info support


#region Symbols

## returns true when unit should stop processing further steps
## it died or battle ended
func _process_symbols(unit : Unit) -> bool:
	if _should_die_to_counter_attack(unit):
		_kill_unit(unit)
		return true
	_process_offensive_symbols(unit)
	if not battle_is_ongoing():
		return true
	return false


func _should_die_to_counter_attack(unit : Unit) -> bool:
	# Returns true if Enemy counter_attack can kill the target
	var adjacent = _get_adjacent_units(unit.coord)

	for side in range(6):
		if not adjacent[side]:
			continue # no unit
		if adjacent[side].controller == unit.controller:
			continue # no friendly fire
		if unit.get_symbol(side) == E.Symbols.SHIELD:
			continue # we have a shield
		var opposite_side := GenericHexGrid.opposite_direction(side)
		if adjacent[side].get_symbol(opposite_side) == E.Symbols.SPEAR:
			return true # enemy has a counter_attack
	return false


func _process_offensive_symbols(unit : Unit) -> void:
	var adjacent := _get_adjacent_units(unit.coord)

	for side in range(6):
		var unit_weapon = unit.get_symbol(side)
		if unit_weapon in [E.Symbols.EMPTY, E.Symbols.SHIELD]:
			continue # We don't have any weapon
		if unit_weapon == E.Symbols.BOW:
			_process_bow(unit, side)
			continue # bow is special case
		if not adjacent[side]:
			continue # nothing to interact with
		if adjacent[side].controller == unit.controller:
			continue # no friendly fire

		var enemy = adjacent[side]
		if unit_weapon == E.Symbols.PUSH:
			_push_enemy(enemy, side)
			continue # push is special case
		var opposite_side := GenericHexGrid.opposite_direction(side)
		if enemy.get_symbol(opposite_side) == E.Symbols.SHIELD:
			continue # enemy defended
		_kill_unit(enemy)


func _process_bow(unit : Unit, side : int) -> void:
	var target := _get_shot_target(unit.coord, side)

	if target == null:
		return # no target
	if target.controller == unit.controller:
		return # no friendly fire
	var opposite_side := GenericHexGrid.opposite_direction(side)
	if target.get_symbol(opposite_side) == E.Symbols.SHIELD:
		return  # blocked by shield

	_kill_unit(target)


func _push_enemy(enemy : Unit, direction : int) -> void:
	var target_coord := GenericHexGrid.distant_coord(enemy.coord, direction, 1)

	if not _is_movable(target_coord):
		# Pushing outside the map
		_kill_unit(enemy)
		return

	var target := get_unit(target_coord)
	if target != null:
		# Spot isn't empty
		_kill_unit(enemy)
		return

	currently_processed_move_info.register_push(enemy, target_coord)

	# MOVE for PUSH (no rotate)
	_change_unit_coord(enemy, target_coord)
	enemy.move(target_coord, _get_battle_hex(target_coord).swamp)

	# check for counter_attacks
	if _should_die_to_counter_attack(enemy):
		_kill_unit(enemy)

#endregion


#region helpers

func get_current_player() -> Player:
	return armies_in_battle_state[current_army_index].army_reference.controller


func _get_battle_hex(coord : Vector2i) -> BattleHex:
	return get_hex(coord)


func get_unit(coord : Vector2i) -> Unit:
	return _get_battle_hex(coord).unit


func _is_movable(coord : Vector2i) -> bool:
	return _get_battle_hex(coord).can_be_moved_to


func _get_adjacent_units(coord : Vector2i) -> Array[Unit]:
	var result : Array[Unit] = []
	for dir in range(6):
		var target_coord := GenericHexGrid.adjacent_coord(coord, dir)
		result.append(get_unit(target_coord))
	return result


func _get_shot_target(coord : Vector2i, direction : int) -> Unit:
	var target_coord := GenericHexGrid.adjacent_coord(coord, direction)
	var hex := _get_battle_hex(target_coord)
	while not hex.unit and not hex.blocks_shots():
		target_coord = GenericHexGrid.adjacent_coord(target_coord, direction)
		hex = _get_battle_hex(target_coord)
	return hex.unit


func is_move_valid(unit : Unit, coord : Vector2i) -> bool:
	return _get_move_direction_if_valid(unit, coord) != MOVE_IS_INVALID


## Returns `MOVE_IS_INVALID` if move is incorrect
## or a turn direction `E.GridDirections` if move is correct
func _get_move_direction_if_valid(unit : Unit, coord : Vector2i) -> int:
	"""
		For move to be valid, target coord
		- is a neighbor of the unit
		- allows movement
		- can be occupied by a new unit:
			- is empty
			- contains a unit that would be killed/pushed by the move

		@param unit to move
		@param coord target coord for unit to move to
		@return MOVE_IS_INVALID (-1) if move is illegal, direction otherwise
	"""

	var move_direction := GenericHexGrid.direction_to_adjacent(unit.coord, coord)
	# not adjacent
	if move_direction == TILES_NOT_ADJACENT:
		return MOVE_IS_INVALID

	var hex = _get_battle_hex(coord)
	if not hex.can_be_moved_to:
		return MOVE_IS_INVALID

	var unit_on_target = hex.unit
	# empty field
	if not unit_on_target:
		return move_direction

	if not _can_kill_or_push(unit, unit_on_target, move_direction):
		return MOVE_IS_INVALID

	return move_direction


## can i kill/push this enemy in melee if i attack in specified direction
func _can_kill_or_push(me : Unit, other_unit : Unit, attack_direction : int):
	# - attacker has no attack symbol on front
	# - attacker has push symbol on front (no current unit has it)
	# - attacker has some attack symbol
	#   - defender has shield

	if other_unit.controller == me.controller:
		return false

	match me.get_front_symbol():
		E.Symbols.EMPTY:
			# can't deal with enemy_unit
			return false
		E.Symbols.SHIELD:
			# can't deal with enemy_unit
			return false
		E.Symbols.PUSH:
			# push ignores enemy_unit shields etc
			return true
		_:
			# assume other attack symbol
			# Does enemy_unit has a shield?
			var defense_direction = GenericHexGrid.opposite_direction(attack_direction)
			var defense_symbol = other_unit.get_symbol(defense_direction)

			if defense_symbol == E.Symbols.SHIELD:
				return false
			# no shield, attack ok
			return true


func _get_player_army(player : Player) -> BattleGridState.ArmyInBattleState:
	for army in armies_in_battle_state:
		if army.army_reference.controller == player:
			return army
	assert(false, "No army for player " + str(player))
	return null


func _get_army_index(army : BattleGridState.ArmyInBattleState):
	var result = armies_in_battle_state.find(army)
	return result


func is_during_summoning_phase() -> bool:
	return state == STATE_SUMMONNING

#endregion helpers


#region Gameplay Events

func _switch_participant_turn() -> void:
	var prev_player := armies_in_battle_state[current_army_index]
	var prev_idx = current_army_index
	current_army_index += 1
	current_army_index %= armies_in_battle_state.size()
	print(NET.get_role_name(), " _switch_participant_turn ", current_army_index)

	if state == STATE_SUMMONNING:
		var skip_count = 0
		# skip players with nothing to summon
		while armies_in_battle_state[current_army_index].units_to_summon.size() == 0:
			current_army_index += 1
			current_army_index %= armies_in_battle_state.size()
			skip_count += 1
			# no player has anything to summon, go to next phase
			if skip_count == armies_in_battle_state.size():
				_end_summoning_state()
				break

	elif state == STATE_FIGHTING:
		
		while not armies_in_battle_state[current_army_index].can_fight():
			current_army_index += 1
			current_army_index %= armies_in_battle_state.size()

		if prev_idx > current_army_index: # Cyclone timer update
			cyclone_target.cyclone_timer -= 1

			if cyclone_target.cyclone_timer == 0:
				current_army_index = _get_army_index(cyclone_target)
				state = STATE_SACRIFICE

	var next_player := armies_in_battle_state[current_army_index]
	# chess clock is updated in  turn_ended() and turn_started()
	prev_player.turn_ended()
	next_player.turn_started()


func _end_summoning_state() -> void:
	state = STATE_FIGHTING
	current_army_index = 0


func _change_unit_coord(unit : Unit, target_coord : Vector2i) -> void:
	_remove_unit(unit)
	_put_unit_on_grid(unit, target_coord)


func _remove_unit(unit : Unit) -> void:
	var hex := _get_battle_hex(unit.coord)
	assert(hex.unit == unit, "incorrect remove unit, coord desync")
	hex.unit = null


func _kill_unit(target : Unit) -> void:
	var target_army_index := _find_army_idx(target.controller)
	currently_processed_move_info.register_kill(target_army_index, target)

	_get_player_army(target.controller).kill_unit(target)
	_check_battle_end()


## TODO implement repeated moves detection
func end_stalemate() -> void:
	pass

#endregion Gameplay Events


#region Summon Phase

func current_player_can_summon_on(coord : Vector2i) -> bool:
	return _can_summon_on(current_army_index, coord)


func _can_summon_on(army_idx : int, coord : Vector2i) -> bool:
	var hex := _get_battle_hex(coord)
	return  hex.spawn_point_army_idx == army_idx and hex.unit == null


func _get_spawn_rotation(coord : Vector2i) -> int:
	return _get_battle_hex(coord).spawn_direction


func _put_unit_on_grid(unit : Unit, coord : Vector2i) -> void:
	var hex := _get_battle_hex(coord)
	assert(hex.can_be_moved_to, "summoning unit to an invalid tile")
	assert(not hex.unit, "summoning unit to an occupied tile")
	hex.unit = unit

#endregion Summon Phase


#region Timer

## in miliseconds
func get_current_time_left() -> int:
	return armies_in_battle_state[current_army_index].get_time_left_ms()


## only for Replays
func set_displayed_time_left_ms(time_left_ms : int) -> void:
	armies_in_battle_state[current_army_index].set_time_left_ms(time_left_ms)

#endregion Timer


#region Mana Cyclone Timer

func mana_values_changed() -> void:
	## Occurs any time mana values are changed (cheap function)
	## It may change the cyclone_target
	var current_worst = armies_in_battle_state[0]
	var current_best = armies_in_battle_state[-1]
	for army in armies_in_battle_state:
		if current_worst.mana_points > army.mana_points: 
			# TODO write documentation explaining that better defensive positions have those later in the array
			current_worst = army
		if current_best.mana_points < army.mana_points:
			current_best = army
	
	cyclone_target = current_worst
	var mana_difference = current_best.mana_points - current_worst.mana_points
 
	var new_cylone_counter = (number_of_mana_wells * 10) * max(1, (5 - mana_difference))
	#new_cylone_counter = 1 # use to test

	if current_worst.cyclone_timer == 0:  # Cycle killed a unit now it resets
		current_worst.cyclone_timer = new_cylone_counter
	elif current_worst.cyclone_timer > new_cylone_counter:
		current_worst.cyclone_timer = new_cylone_counter

	
func cyclone_get_current_target() -> Player:
	return cyclone_target.army_reference.controller


func cyclone_get_current_target_turns_left() -> int:
	return cyclone_target.cyclone_timer


#endregion Mana Cyclone Timer


#region Magic

func is_spell_target_valid(unit : Unit, coord : Vector2i) -> bool:
	return true #TEMP

#endregion


#region End Battle

func _kill_army(army_idx : int):
	armies_in_battle_state[army_idx].kill_army()
	if battle_is_ongoing():
		_check_battle_end()


func battle_is_ongoing() -> bool:
	return state != STATE_BATTLE_FINISHED



func _check_battle_end() -> void:
	if state == STATE_BATTLE_FINISHED:
		return

	var armies_alive = 0
	for a in armies_in_battle_state:
		if a.can_fight():
			armies_alive += 1

	if armies_alive < 2:
		state = STATE_BATTLE_FINISHED
		return


func force_win_battle():
	for army_idx in range(armies_in_battle_state.size()):
		if army_idx == current_army_index:
			continue
		_kill_army(army_idx)


func surrender_on_timeout():
	_kill_army(current_army_index)


func force_surrender():
	for army_idx in range(armies_in_battle_state.size()):
		if army_idx != current_army_index:
			continue
		_kill_army(army_idx)

#endregion End Battle


#region AI Helpers

func get_possible_moves() -> Array[MoveInfo]:
	if is_during_summoning_phase():
		return _get_all_spawn_moves()

	return _get_all_unit_moves()


func _get_summon_tiles(player : Player) -> Array[Vector2i]:
	var army_idx = _find_army_idx(player)
	var result : Array[Vector2i] = []
	for x in range(width):
		for y in range(height):
			var coord := Vector2i(x,y)
			if _can_summon_on(army_idx, coord):
				result.append(coord)
	return result


func _get_not_summoned_units(player : Player) -> Array[DataUnit]:
	for a in armies_in_battle_state:
		if a.army_reference.controller == player:
			return a.units_to_summon.duplicate()
	assert(false, "ai asked for units to summon but it doesn't control any army")
	return []


func _get_units(player : Player) -> Array[Unit]:
	var idx = _find_army_idx(player)
	return armies_in_battle_state[idx].units


func _find_army_idx(player : Player) -> int:
	for idx in range(armies_in_battle_state.size()):
		if armies_in_battle_state[idx].army_reference.controller == player:
			return idx
	assert(false, "ai asked for army idx for player who doesnt control any army")
	return -1


## not summons, only units already placed
func _get_all_unit_moves() -> Array[MoveInfo]:
	var legal_moves : Array[MoveInfo] = []
	var my_units := _get_units(get_current_player())

	for unit in my_units:
		for side in range(6):
			var new_coord = GenericHexGrid.adjacent_coord(unit.coord, side)
			var move_dir = _get_move_direction_if_valid(unit, new_coord)
			if move_dir != BattleGridState.MOVE_IS_INVALID:
				legal_moves.append(MoveInfo.make_move(unit.coord, new_coord))
	return legal_moves


func _get_all_spawn_moves() -> Array[MoveInfo]:
	var legal_moves: Array[MoveInfo] = []
	var me = get_current_player()
	var spawn_tiles = _get_summon_tiles(me)
	var units = _get_not_summoned_units(me)
	for unit in units:
		for spawn_tile in spawn_tiles:
			legal_moves.append(MoveInfo.make_summon(unit, spawn_tile))

	return legal_moves


## only legal moves are supported
func filter_only_kill_moves(all_moves: Array[MoveInfo]) -> Array[MoveInfo]:
	var all_kill_moves : Array[MoveInfo] = []
	for move in all_moves:
		if _is_kill_move(move):
			all_kill_moves.append(move)

	return all_kill_moves


## only legal moves are supported
func _is_kill_move(move : MoveInfo) -> bool:

	if move.move_type != MoveInfo.TYPE_MOVE:
		return false # summons don't kill

	var me = get_current_player()
	var unit_on_target_field = get_unit(move.target_tile_coord)
	if unit_on_target_field != null \
			and unit_on_target_field.controller != me:
		# can move into a unit and kill it
		# if it couldn't move would not be legal
		return true

	# BOW
	var attacker = get_unit(move.move_source)
	var move_direction = GenericHexGrid.direction_to_adjacent( \
			move.move_source, move.target_tile_coord);
	for side in range(6):
		var opposite_side = GenericHexGrid.opposite_direction(side)
		var symbol = attacker.get_symbol_when_rotated(side, move_direction)
		if symbol == E.Symbols.BOW:
			var target : Unit = _get_shot_target(move.move_source, side)
			if target != null and target.controller != me \
					and target.get_symbol(opposite_side) != E.Symbols.SHIELD:
				# can shoot enemy in this direction
				return true

	# check for enemies near new field
	var target_adjacent_units = _get_adjacent_units(move.target_tile_coord)
	# check for enemy spears
	for side in 6:
		var enemy = target_adjacent_units[side]
		if enemy and enemy.controller != me:
			var opposite_side = GenericHexGrid.opposite_direction(side)
			if enemy.get_symbol(opposite_side) == E.Symbols.SPEAR:
				if attacker.get_symbol_when_rotated(move_direction, side) != E.Symbols.SHIELD:
					# will die to spear befor it can kill, no-go
					return false
	# check for unprotected attacker symbols
	for side in 6:
		var enemy = target_adjacent_units[side]
		if not enemy or enemy.controller == me:
			continue
		# TODO detect killing pushes
		var opposite_side = GenericHexGrid.opposite_direction(side)
		if enemy.get_symbol(opposite_side) == E.Symbols.SHIELD:
			continue
		var attack_symbol =  attacker.get_symbol_when_rotated(move_direction, side)
		if attack_symbol == E.Symbols.SWORD or attack_symbol == E.Symbols.SPEAR:
			return true
	return false


#endregion


#region Subclasses


class BattleHex:
	var unit : Unit
	var spawn_point_army_idx : int = -1
	var spawn_direction : int
	var can_be_moved_to : bool = true
	var can_shoot_through : bool = true
	var swamp : bool = false # TODO REFACTOR THIS NAME
	var mana : bool = false

	static var sentinel: BattleHex = BattleHex.create_sentinel()


	static func get_spawn_direction(army_id:int) -> int:
		match army_id:
			0: return GenericHexGrid.GridDirections.RIGHT
			2: return GenericHexGrid.GridDirections.TOP_RIGHT
			3: return GenericHexGrid.GridDirections.BOTTOM_LEFT
			_: return GenericHexGrid.GridDirections.LEFT


	static func create_sentinel():
		var result = BattleHex.new()
		result.can_be_moved_to = false
		result.can_shoot_through = false
		return result


	static func create(data : DataTile):
		if data.type == "sentinel":
			return null

		var result = BattleHex.new()

		if data.type.substr(1) == "_player_spawn":
			result.spawn_point_army_idx = data.type[0].to_int() - 1
			result.spawn_direction = get_spawn_direction(result.spawn_point_army_idx)
			return result


		match data.type:
			"hole":
				result.can_be_moved_to = false
			"wall":
				result.can_be_moved_to = false
				result.can_shoot_through = false
			"swamp":
				result.swamp = true
			"empty":
				pass
			"mana_well":
				result.mana = true
			_:
				pass #TODO push error that tile type is not supported

		return result


	func blocks_shots() -> bool:
		return not can_shoot_through
	

	func is_mana_tile() -> bool:
		return mana


class ArmyInBattleState:
	var battle_grid_state : WeakRef # BattleGridState
	var army_reference : Army

	var units_to_summon : Array[DataUnit] = []
	var units : Array[Unit] = []
	var dead_units : Array[DataUnit] = []

	var mana_points : int = 1
	var cyclone_timer : int = 100

	## when turn started - for local time calculation
	var turn_start_timestamp
	##  miliseconds on the clock when turn started - will be synched in multiplayer
	var start_turn_clock_time_left_ms = CFG.CHESS_CLOCK_BATTLE_TIME_PER_PLAYER_MS
	## time to add when turn ends
	var turn_increment_ms = CFG.CHESS_CLOCK_BATTLE_TURN_INCREMENT_MS


	static func create_from(army : Army, state : BattleGridState) -> ArmyInBattleState:
		var result = ArmyInBattleState.new()
		result.battle_grid_state = weakref(state)
		result.army_reference = army
		for unit : DataUnit in army.units_data:
			result.units_to_summon.append(unit)
			
			result.mana_points += unit.mana # MANA

		result.turn_started() # TEMP - FIXME - better init for chess clock

		return result


	func turn_started() -> void:
		turn_start_timestamp = Time.get_ticks_msec()


	func get_time_left_ms() -> int:
		var turn_time_local_passed_ms = Time.get_ticks_msec() - turn_start_timestamp
		return start_turn_clock_time_left_ms - turn_time_local_passed_ms


	func set_time_left_ms(time_left_ms : int) -> void:
		turn_start_timestamp = Time.get_ticks_msec()
		start_turn_clock_time_left_ms = time_left_ms


	func turn_ended() -> void:
		start_turn_clock_time_left_ms = get_time_left_ms()
		start_turn_clock_time_left_ms += turn_increment_ms


	func kill_unit(target : Unit) -> void:
		print("killing ", target.coord, " ",target.template.unit_name)
		if target.template.mana > 0:
			mana_points -= target.template.mana
			battle_grid_state.get_ref().mana_values_changed()

		units.erase(target)
		dead_units.append(target.template)
		#gdlint: ignore=private-method-call
		battle_grid_state.get_ref()._remove_unit(target)
		target.unit_killed()


	func revive(kill_info : MoveInfo.KilledUnit) -> Unit:
		var unit = kill_info.respawn()
		unit.controller = army_reference.controller
		dead_units.erase(unit.template)
		units.append(unit)
		return unit


	func kill_army() -> void:
		dead_units.append_array(units_to_summon)
		units_to_summon.clear()
		for unit_idx in range(units.size() - 1, -1, -1):
			kill_unit(units[unit_idx])


	func can_fight() -> bool:
		return units.size() > 0 or units_to_summon.size() > 0


	func summon_unit(unit_data : DataUnit, coord:Vector2i, rotation:int) -> Unit:
		units_to_summon.erase(unit_data)
		var result = Unit.create(army_reference.controller, unit_data, coord, rotation)
		units.append(result)
		return result


	func unsummon(coord : Vector2i):
		var target = battle_grid_state.get_ref().get_unit(coord)
		units.erase(target)
		units_to_summon.append(target.template)
		#gdlint: ignore=private-method-call
		battle_grid_state.get_ref()._remove_unit(target)
		target.unit_killed()

#endregion Subclasses
