class_name AIInterface extends Node

var me : Player


func set_player(controlled_player: Player):
	me = controlled_player

func choose_move(_battle_state : BattleGridState) -> MoveInfo:
	assert(false, "ERROR: AI interface has not been implemented (for player %s)" % [me])
	# dead code, just to force godot to not throw warnings on awaiting and mark this method as async
	await Signal()
	return null

func cleanup_after_move():
	pass
