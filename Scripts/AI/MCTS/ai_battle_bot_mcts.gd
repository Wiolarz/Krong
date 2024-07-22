class_name AIBattleBotMCTS extends AIInterface

@export var iterations = 100000


func choose_move(state: BattleGridState) -> MoveInfo:
	
	var unit_array = []
	var bm = BattleManagerFast.from(state, unit_array)
	var mcts = BattleMCTSManager.new()
	mcts.set_root(bm)
	
	mcts.iterate(iterations, OS.get_processor_count())
	var unit = mcts.get_optimal_move_unit(0)
	var position = mcts.get_optimal_move_position(0)
	
	if unit_array[unit] is DataUnit: # Summon
		return MoveInfo.make_summon(unit_array[unit], position)
	else: # Move
		return MoveInfo.make_move(unit_array[unit].coord, position)
