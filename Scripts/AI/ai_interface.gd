class_name AIInterface extends Node


var me : Player


func _init(controlled_player : Player):
	me = controlled_player


func play_move():
	print("ERROR", me, " AI interface has not been implemented")


#func _process(delta):
	#if not is_my_move():
		#return


#func is_my_move() -> bool:
	#if IM.raging_battle:
		#return BM.current_participant == me
	#return WM.current_player == me