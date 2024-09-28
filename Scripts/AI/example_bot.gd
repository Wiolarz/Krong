class_name ExampleBot
extends AIInterface

"""
Bot with a state determined by tags
"""


enum TAG \
{
	IDLE,
	ATTACK,
	DEFEND,
}

var tags_set: Dictionary = {} # [TAG -> null] used as Hash set

var current_state : AiBotState


func _ready():
	pass
	#name = "ExampleBot"
	#add_child(AiBotStateRandom.new([], me))
	#add_child(AiBotState.new([TAG.DEFEND], me)) # default state should crash the game
	#current_state = get_children()[0]


func add_tag(tag : TAG):
	if tags_set.has(tag):
		return
	tags_set[tag] = null
	# update state


func remove_tag(tag : TAG):
	if tags_set.has(tag):
		tags_set.erase(tag)
	# update state


func choose_move(battle_state : BattleGridState) -> MoveInfo:
	return current_state.choose_move(battle_state)
