class_name AIInterface extends Node


var me : Player


func _init(controlled_player : Player):
	me = controlled_player


func choose_move(_battle_state : BattleGridState) -> MoveInfo:
	assert(false, "ERROR: AI interface has not been implemented (for player %s)" % [me])
	return null
