# Singleton - BM
class_name BattleManager extends GridNode2D

var _battle_is_ongoing : bool = false

var _battle_grid_state : BattleGridState # GAMEPLAY combat state

var _tile_grid : GenericHexGrid # Grid<TileForm> - VISUALs in a grid
var _unit_to_unit_form : Dictionary # gameplay unit to VISUAL mapping
var _grid_tiles_node : Node2D # parent for tiles VISUAL
var _unit_forms_node : Node2D # parent for units VISUAL

var _battle_ui : BattleUI
var _anim_queue : Array[AnimInQueue] = []
var latest_ai_cancel_token : CancellationToken

var _current_summary : DataBattleSummary = null

var _selected_unit : Unit

var _replay_data : BattleReplay
var _replay_is_playing : bool = false

var _batch_mode : bool = false # flagged true when recreating game state


func _ready():
	_battle_ui = load("res://Scenes/UI/BattleUi.tscn").instantiate()

	_grid_tiles_node = Node2D.new()
	_grid_tiles_node.name = "GRID"
	add_child(_grid_tiles_node)

	_unit_forms_node = Node2D.new()
	_unit_forms_node.name = "UNITS"
	add_child(_unit_forms_node)

	UI.add_custom_screen(_battle_ui)


func _process(_delta):
	_process_anim_queue()
	_check_clock_timer_tick()


#region Battle Setup

## x_offset is used to place battle to the right of world map
func start_battle(new_armies : Array[Army], battle_map : DataBattleMap, \
		battle_state : SerializableBattleState, x_offset : float) -> void:

	assert(_is_clear(), "cannot start battle map, map already loaded")

	_replay_data = BattleReplay.create(new_armies, battle_map)
	_replay_data.save()

	UI.ensure_camera_is_spawned()
	UI.go_to_custom_ui(_battle_ui)

	_battle_is_ongoing = true

	_current_summary = null
	deselect_unit()

	_battle_grid_state = BattleGridState.create(battle_map, new_armies)

	# GRAPHICS GRID:
	_load_map(battle_map)
	_grid_tiles_node.position.x = x_offset

	_battle_ui.load_armies(_battle_grid_state.armies_in_battle_state)

	if battle_state: # recreate state if present
		_batch_mode = true
		for m in battle_state.replay.moves:
			_perform_replay_move(m)
		_batch_mode = false

	# first turn does not get a signal emit
	_on_turn_started(_battle_grid_state.get_current_player())


func _load_map(map : DataBattleMap) -> void:
	assert(_is_clear(), "cannot load map, map already loaded")
	_tile_grid = GenericHexGrid.new(map.grid_width, map.grid_height, null)
	_unit_to_unit_form.clear()
	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var coord = Vector2i(x, y)
			var data = map.grid_data[x][y] as DataTile
			var tile_form = TileForm.create_battle_tile(data, coord)
			_tile_grid.set_hex(coord, tile_form)
			tile_form.position = to_position(coord)
			_grid_tiles_node.add_child(tile_form)


## space needed for battle tiles in global position
func get_bounds_global_position() -> Rect2:
	if _is_clear():
		push_warning("asking not initialized grid for camera bounding box")
		return Rect2(0, 0, 0, 0)
	var top_left_tile_position := get_tile_global_position(Vector2i(0,0))
	var bottom_right_tile_position  := \
			get_tile_global_position(Vector2i(_tile_grid.width-1, _tile_grid.height-1))
	var size : Vector2 = bottom_right_tile_position - top_left_tile_position
	return Rect2(top_left_tile_position, size)


#endregion


#region helpers

func get_player_color(player : Player) -> DataPlayerColor:
	if not _battle_is_ongoing:
		return CFG.NEUTRAL_COLOR
	if not player:
		return CFG.NEUTRAL_COLOR
	return player.get_player_color()


func get_current_slot_color() -> DataPlayerColor:
	if not _battle_is_ongoing:
		return CFG.NEUTRAL_COLOR
	var player = _battle_grid_state.get_current_player()
	if not player:
		return CFG.NEUTRAL_COLOR
	return player.get_player_color()


func get_current_turn() -> int:
	return _battle_grid_state.turn_counter


## tells if there is battle state that is important and should be serialized
func battle_is_active() -> bool:
	return _battle_is_ongoing


#TODO: simplify
func can_show_battla_camera() -> bool:
	return _battle_is_ongoing


#TODO: WM should remember if its waiting for battle to end or not,
# BM should not care
func should_block_world_interaction() -> bool:
	return _battle_is_ongoing


## converts from coordinates like 3,5 to actual position like 1200,300
func get_tile_global_position(coord : Vector2i) -> Vector2:
	return _tile_grid.get_hex(coord).global_position


## checks if map was cleaned properly, usually used for asserts
func _is_clear() -> bool:
	return _grid_tiles_node.get_child_count() == 0 \
			and _unit_forms_node.get_child_count() == 0 \
			and _tile_grid == null

#endregion helpers


#region Ongoing battle

func _on_turn_started(player : Player) -> void:
	if not _battle_is_ongoing:
		return

	_battle_ui.start_player_turn(_battle_grid_state.current_army_index)

	if not player:
		print("uncontrolled army's turn")
		return

	# trigger AI analysis
	print("your move %s - %s" % [player.get_player_name(), player.get_player_color().name])

	if player.bot_engine and not NET.client: # AI is simulated on server only
		print("AI starts thinking")
		
		var my_cancel_token = CancellationToken.new()
		#assert(latest_ai_cancel_token == null)
		latest_ai_cancel_token = my_cancel_token
		
		var bot = player.bot_engine
		
		var thinking_begin_s = Time.get_ticks_msec() / 1000.0
		var move = await bot.choose_move(_battle_grid_state)
		await _ai_thinking_delay(thinking_begin_s) # moving too fast feels weird
		
		bot.cleanup_after_move()
		if _battle_grid_state == null: # Player quit to main menu before finishing
			return
		
		if not my_cancel_token.is_canceled():
			assert(_battle_grid_state.is_move_possible(move), "AI tried to perform an invalid move")
			_perform_ai_move(move)
			latest_ai_cancel_token = null




func perform_network_move(move_info : MoveInfo) -> void:
	_perform_move_info(move_info)


func _perform_replay_move(move_info : MoveInfo) -> void:
	_battle_grid_state.set_displayed_time_left_ms(move_info.time_left_ms)
	_perform_move_info(move_info)


func undo() -> void:
	if _replay_data.moves.is_empty():
		return
	if not battle_is_active():
		return

	cancel_pending_ai_move()

	var last_move := _replay_data.moves.pop_back() as MoveInfo
	var new_units = _battle_grid_state.undo(last_move)
	for n in new_units:
		_on_unit_summoned(n)
	_battle_ui.refresh_after_undo(_battle_grid_state.is_during_summoning_phase())
	_end_move()


## STUB
func redo() -> void:
	push_warning("not implemented")
	pass


## IMPORTANT FUNCTION -> called when tile is clicked
func grid_input(coord : Vector2i) -> void:
	if not _battle_is_ongoing:
		print("battle finished, input ignored")
		return

	if _replay_is_playing:
		print("replay playing, input ignored")
		return

	if _anim_queue.size() > 0:
		print("anim playing, input ignored")
		return

	var current_player : Player =  _battle_grid_state.get_current_player()
	if current_player != null and current_player.bot_engine:
		print("ai playing, input ignored")
		return

	var move_info : MoveInfo

	match _battle_grid_state.state:
		BattleGridState.STATE_SUMMONNING:
			move_info = _grid_input_summon(coord)
		BattleGridState.STATE_FIGHTING:
			if _battle_ui.selected_spell == null:
				move_info = _grid_input_fighting(coord)
			else:
				move_info = _grid_input_magic(coord)
		BattleGridState.STATE_SACRIFICE:
			move_info = _grid_input_sacrifice(coord)

	if move_info:
		if NET.client:
			NET.client.queue_request_move(move_info)
			return # dont perform move, send it to server

		_perform_move_info(move_info)


func _check_for_stalemate() -> bool:
	assert(BattleGridState.STALEMATE_TURN_REPEATS == 2,
	" _check_for_stalemate has wrong STALEMATE_TURN_REPEATS value
	later parts of this function version wasn't made in mind with more repeats allowed")
	var limit = BattleGridState.STALEMATE_TURN_REPEATS

	# if number of the armies were to change during last few moves, then it wouldn't be a stalemate
	var alive_armies = []
	for army in _battle_grid_state.armies_in_battle_state:
		if army.can_fight():
			alive_armies.append(army)

	# equation determines the shortest scenario to achieve a stalemate
	# later we jump back X move behind, so it makes it safe to do so
	if _replay_data.moves.size() < limit * alive_armies.size() * 2:
		return false

	var go_back_value = limit * alive_armies.size() + 1
	for player_idx in range(alive_armies.size()):
		var old_move = _replay_data.moves[-go_back_value - player_idx]
		var new_move = _replay_data.moves[-player_idx - 1]

		if new_move.move_type != MoveInfo.TYPE_MOVE or old_move.move_type != new_move.move_type:
			return false
		if old_move.move_source != new_move.move_source or \
			old_move.target_tile_coord != new_move.target_tile_coord:
				return false
	return true

func  _end_move() -> void:
	if _battle_grid_state.battle_is_ongoing():
		if _check_for_stalemate():
			_battle_grid_state.end_stalemate() # could end the battle

	if _battle_grid_state.battle_is_ongoing():
		_on_turn_started(_battle_grid_state.get_current_player())
	else :
		_on_battle_ended()

#endregion Ongoing battle


#region AI Support

func cancel_pending_ai_move() ->  void:
	if latest_ai_cancel_token:
		latest_ai_cancel_token.cancel()
		latest_ai_cancel_token = null


func _ai_thinking_delay(thinking_begin_s) -> void:
	var max_seconds = CFG.bot_speed_frames / 60.0
	var seconds = max(0.01, max_seconds - (Time.get_ticks_msec()/1000.0 - thinking_begin_s))
	await get_tree().create_timer(seconds).timeout
	while IM.is_game_paused() or CFG.bot_speed_frames == CFG.BotSpeed.FREEZE:
		await get_tree().create_timer(0.1).timeout


func _perform_ai_move(move_info : MoveInfo) -> void:
	_perform_move_info(move_info)


func ai_move() -> void:
	if latest_ai_cancel_token:
		push_warning("ai is already moving, dont stack two simultaneous ai moves race")
		return
	var move := AiBotStateRandom.choose_move_static(_battle_grid_state)
	_perform_ai_move(move)

#endregion AI Support


#region Summon Phase

## handles spawning unit form when unit is spawned on a gameplay map
## also connects animation related signals
func _on_unit_summoned(unit : Unit) -> void:
	var form := UnitForm.create(unit)
	_unit_forms_node.add_child(form)
	_unit_to_unit_form[unit] = form

	# apply correct BM position offset in world battles
	form.global_position = get_tile_global_position(unit.coord)

	_battle_ui.unit_summoned(not _battle_grid_state.is_during_summoning_phase())

	unit.unit_died.connect(_on_unit_killed.bind(unit))
	unit.unit_turned.connect(_on_unit_turned.bind(unit))
	unit.unit_moved.connect(_on_unit_moved.bind(unit))


## handles player input while during the summoning phase
func _grid_input_summon(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_SUMMONNING, \
			"_grid_input_summon called in an incorrect state")

	if _battle_ui.selected_unit == null:
		return null # no unit selected to summon on ui

	if not _battle_grid_state.current_player_can_summon_on(coord):
		return null

	print(NET.get_role_name(), " input - summoning unit")
	return MoveInfo.make_summon(_battle_ui.selected_unit, coord)


#endregion Summon Phase


#region Mana Cyclone Timer

func get_cyclone_target() -> Player:
	return _battle_grid_state.cyclone_get_current_target()


func get_cyclone_timer() -> int:
	return _battle_grid_state.cyclone_get_current_target_turns_left()

#endregion Mana Cyclone Timer


#region Fighting Phase

## Turn timer unit sacrifice (Stalemate prevention mechanic)
func _grid_input_sacrifice(coord : Vector2i) -> MoveInfo:
	## TODO:
	## input should be locked to the person that is bound to make a sacrifice,
	## which could be a different player than a current one also it occurs at round start

	assert(_battle_grid_state.state == _battle_grid_state.STATE_SACRIFICE, \
			"_grid_input_fighting called in an incorrect state")

	var new_unit : Unit = _battle_grid_state.get_unit(coord)
	if new_unit and new_unit.controller == _battle_grid_state.cyclone_target.army_reference.controller:

		# Reselect the same target OR new one if that
		return MoveInfo.make_sacrifice(coord)
	return null


## Selected Unit -> instead of moving casts a spell
func _grid_input_magic(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_FIGHTING, \
			"_grid_input_magic called in an incorrect state")

	if _battle_ui.selected_spell == null:
		return null # no spell selected to cast on ui

	if not _battle_grid_state.is_spell_target_valid(_selected_unit, coord, _battle_ui.selected_spell):
		return null

	var move_info = MoveInfo.make_magic(_selected_unit.coord, coord, _battle_ui.selected_spell)
	deselect_unit()

	return move_info


## Either Unit selection or a command to move
func _grid_input_fighting(coord : Vector2i) -> MoveInfo:
	assert(_battle_grid_state.state == _battle_grid_state.STATE_FIGHTING, \
			"_grid_input_fighting called in an incorrect state")


	if _try_select_unit(coord) or _selected_unit == null:
		# used in scenarios:
		# - selected a new unit
		# - clicked a tile with no ally units, when no unit was selected
		return null

	# get_move_direction() returns MOVE_IS_INVALID on impossible moves, handles scenarios like
	# - spot is not adjacent (MOVE_IS_INVALID)
	# - spot is empty (dir)
	# - spot is not movable (MOVE_IS_INVALID)
	# - there is an enemy that can be killed by the move (dir)
	# - there is enemy that cannot be killed by the move (MOVE_IS_INVALID)
	if not _battle_grid_state.is_move_valid(_selected_unit, coord):
		return null

	var move_info = MoveInfo.make_move(_selected_unit.coord, coord)
	deselect_unit()

	return move_info



## Select friendly Unit on a given coord [br]
## returns true if unit was selected
func _try_select_unit(coord : Vector2i) -> bool:
	var new_unit : Unit = _battle_grid_state.get_unit(coord)
	if not new_unit:
		return false
	if new_unit.controller != _battle_grid_state.get_current_player():
		return false

	# deselect visually old unit if new one selected
	if _selected_unit:
		deselect_unit()

	_selected_unit = new_unit
	_unit_to_unit_form[_selected_unit].set_selected(true)

	# attempt to display spells available to selected unit
	_show_spells(_selected_unit)

	return true


## Main way to deselect unit -> use every time, its safe
func deselect_unit() -> void:
	if _selected_unit:
		_unit_to_unit_form[_selected_unit].set_selected(false)
	_selected_unit = null
	_battle_ui.selected_spell = null
	_battle_ui.reset_spells()



func _show_spells(unit : Unit) -> void:
	if unit.spells.size() == 0:
		return

	#TODO? check here if selected unit is preview mode only (controlled by another player)
	_battle_ui.load_spells(_battle_grid_state.current_army_index , unit.spells)


## Executes given move_info [br]
## used by input moves, replays, network and AI
func _perform_move_info(move_info : MoveInfo) -> void:
	if not _battle_is_ongoing:
		return
	print(NET.get_role_name(), " performing move ", move_info)


	_replay_data.record_move(move_info, get_current_time_left_ms())
	_replay_data.save()
	if NET.server:
		NET.server.broadcast_move(move_info)

	match move_info.move_type:
		MoveInfo.TYPE_MOVE, MoveInfo.TYPE_SACRIFICE, MoveInfo.TYPE_MAGIC:
			_battle_grid_state.move_info_execute(move_info)

		MoveInfo.TYPE_SUMMON:
			var unit : Unit = _battle_grid_state.move_info_summon_unit(move_info)
			_on_unit_summoned(unit)

		_ :
			assert(false, "Move move_type not supported in perform, " + str(move_info.move_type))

	_end_move()


func _on_unit_killed(unit: Unit) -> void:
	if _batch_mode:
		_unit_to_unit_form[unit].update_death_immediately()
	else:
		_anim_queue.push_back(AnimInQueue.create_die(_unit_to_unit_form[unit]))
	_unit_to_unit_form.erase(unit)


func _on_unit_turned(unit: Unit) -> void:
	if _batch_mode:
		_unit_to_unit_form[unit].update_turn_immediately()
	else:
		_anim_queue.push_back(AnimInQueue.create_turn(_unit_to_unit_form[unit]))


func _on_unit_moved(unit: Unit) -> void:
	if _batch_mode:
		_unit_to_unit_form[unit].update_death_immediately()
	else:
		_anim_queue.push_back(AnimInQueue.create_move(_unit_to_unit_form[unit]))


#endregion Fighting Phase


#region Battle End

func close_when_quiting_game() -> void:
	deselect_unit()
	_clear_anim_queue()
	_reset_grid_and_unit_forms()


## called when battle simulation decided battle was won
func _on_battle_ended() -> void:
	print("ending battle")
	if not _battle_is_ongoing:
		assert(false, "battle ended when it was not ongoing...")
		return
	_battle_is_ongoing = false
	deselect_unit()

	await get_tree().create_timer(1).timeout # TEMP, don't exit immediately
	while _replay_is_playing:
		await get_tree().create_timer(0.1).timeout

	_current_summary = _create_summary()
	if WM.world_game_is_active():
		_close_battle()
		# show battle summary over world map
		UI.ui_overlay.show_summary(_current_summary, null)
	else:
		UI.ui_overlay.show_summary(_current_summary, _close_battle)


func _close_battle() -> void:
	var state_for_world = _battle_grid_state.armies_in_battle_state
	_clear_anim_queue()
	_turn_off_battle_ui()
	_reset_grid_and_unit_forms()
	deselect_unit()

	if not WM.world_game_is_active():
		print("end of test battle")
		IM.go_to_main_menu()
		return

	WM.end_of_battle(state_for_world)


func _turn_off_battle_ui() -> void:
	_battle_ui.hide()
	UI.switch_camera()


func _reset_grid_and_unit_forms() -> void:
	_battle_is_ongoing = false
	_tile_grid = null
	_unit_to_unit_form.clear()
	Helpers.remove_all_children(_grid_tiles_node)
	Helpers.remove_all_children(_unit_forms_node)
	_battle_grid_state = null

## Major function which fully generates information panel at the end of the battle
func _create_summary() -> DataBattleSummary:
	var summary := DataBattleSummary.new()

	var armies_in_battle_state := _battle_grid_state.armies_in_battle_state

	var winning_team : int
	var winning_team_players : Array[Player] = []
	# Search for winning team
	for army_in_battle in armies_in_battle_state:
		if army_in_battle.can_fight():
			winning_team = army_in_battle.team
			break

	# Generate information for every player
	for army_in_battle in armies_in_battle_state:
		var player_stats := DataBattleSummaryPlayer.new()

		# Generate casulties info
		if army_in_battle.dead_units.size() == 0:
			player_stats.losses = "< none >"
		else:
			for dead in army_in_battle.dead_units:
				var unit_description = "%s\n" % dead.unit_name
				player_stats.losses += unit_description

		var army_controller_index : int = army_in_battle.army_reference.controller_index
		var army_controller = IM.get_player_by_index(army_controller_index)

		# generates player names for their info column
		player_stats.player_description = IM.get_full_player_description(army_controller)

		if army_in_battle.team == winning_team:
			player_stats.state = "winner"
			winning_team_players.append(army_controller)

			# TEMP solution - better color system described in TODO notes
			var color_description = CFG.NEUTRAL_COLOR
			if army_controller:
				color_description = army_controller.get_player_color()
			summary.color = color_description.color
		else:
			player_stats.state = "loser"
		summary.players.append(player_stats)

	# Summary title creation
	assert(winning_team_players.size() > 0, "Battle resulted in no winners")
	var team_name = 'Neutral'
	if winning_team_players[0]: # neutral is null, so we check
		team_name = "Team %s" % winning_team_players[0].team
	summary.title = "%s wins" % [team_name]
	var sep = " : "
	for player in winning_team_players:
		if not player: # neutral
			continue
		summary.title += sep + IM.get_player_color(player).name
		sep = ", "

	return summary

#endregion Battle End


#region Replays

func perform_replay(replay : BattleReplay) -> void:
	_replay_is_playing = true

	for m in replay.moves:
		if not _battle_is_ongoing:
			return # terminating battle while watching
		_perform_replay_move(m)
		await _replay_move_delay()
	_replay_is_playing = false


func _replay_move_delay() -> void:
	await get_tree().create_timer(CFG.bot_speed_frames/60).timeout
	while IM.is_game_paused() or CFG.bot_speed_frames == CFG.BotSpeed.FREEZE:
		await get_tree().create_timer(0.1).timeout
		if not _battle_is_ongoing:
			return # terminating battle while watching


## gets replay of current battle, but containing only moves -- used in
## serialization of whole game state
func get_ripped_replay() -> BattleReplay:
	var result = BattleReplay.new()
	result.moves = _replay_data.moves.duplicate()
	return result

#endregion Replays


#region cheats

func force_win_battle():
	_battle_grid_state.force_win_battle()
	_end_move()


func force_surrender():
	_battle_grid_state.force_surrender()
	_end_move()


#endregion cheats


#region map editor

func load_editor_map(map : DataBattleMap) -> void:
	_load_map(map)


func unload_for_editor() -> void:
	_reset_grid_and_unit_forms()


func paint(coord : Vector2i, brush : DataTile) -> void:
	(_tile_grid.get_hex(coord) as TileForm).paint(brush)


func editor_get_hexes_copy_as_array() -> Array: #Array[Array[TileForm]]
	return _tile_grid.hexes.duplicate(true)

#endregion map editor


#region Chess clock

## called every frame by _process
func _check_clock_timer_tick() -> void:
	if not _battle_grid_state or not _battle_grid_state.battle_is_ongoing():
		return # no battle
	if _battle_grid_state.get_current_time_left() > 0:
		return # player still has time

	_battle_grid_state.surrender_on_timeout()
	_end_move()

## safe clock getter
func get_current_time_left_ms() -> int:
	if _battle_grid_state && _battle_grid_state.battle_is_ongoing():
		return _battle_grid_state.get_current_time_left()
	return 0

#endregion Chess clock


#region anim queue

## called every frame by _process
func _process_anim_queue() -> void:
	if _anim_queue.size() == 0:
		return
	if not _anim_queue[0].started:
		_anim_queue[0].start()
	if _anim_queue[0].ended:
		_anim_queue.pop_front()
		return
	if not _anim_queue[0]._unit_form:
		var broken = _anim_queue.pop_front()
		push_warning("poping broken animation from the queue " + str(broken))


func _clear_anim_queue():
	for anim in _anim_queue:
		anim.on_anim_end()
	_anim_queue.clear()


class AnimInQueue:
	var started : bool
	var ended : bool
	var debug_name : String
	var _unit_form : UnitForm
	var _animate : Callable


	static func create_turn(unit_form_ : UnitForm) -> AnimInQueue:
		var result = AnimInQueue.new()
		result.debug_name = "turn_"+unit_form_.entity.template.unit_name
		result._unit_form = unit_form_
		unit_form_.anim_end.connect(result.on_anim_end)
		result._animate = func () : if (unit_form_): unit_form_.start_turn_anim()
		return result


	static func create_move(unit_form_ : UnitForm) -> AnimInQueue:
		var result = AnimInQueue.new()
		result.debug_name = "move_"+unit_form_.entity.template.unit_name
		result._unit_form = unit_form_
		unit_form_.anim_end.connect(result.on_anim_end)
		result._animate = func () : if (unit_form_): unit_form_.start_move_anim()
		return result


	static func create_die(unit_form_ : UnitForm) -> AnimInQueue:
		var result = AnimInQueue.new()
		result.debug_name = "die_"+unit_form_.entity.template.unit_name
		result._unit_form = unit_form_
		unit_form_.anim_end.connect(result.on_anim_end)
		result._animate = func () : if (unit_form_): unit_form_.start_death_anim()
		return result


	func start() -> void:
		started = true
		_animate.call()


	func on_anim_end() -> void:
		ended = true
		_unit_form.anim_end.disconnect(on_anim_end)


	func _to_string():
		return debug_name

#endregion anim queue
