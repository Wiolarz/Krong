class_name Player
extends Node


var player_name : String = ""

var bot_engine : AIInterface

# Gameplay
var faction : DataFaction
var goods : Goods = Goods.new()

# UI
var capital_city : City:
	get:
		if cities.size() == 0:
			return null
		return cities[0]
	set(_wrong_value):
		assert(false, "attempt to modify read only value of player capital_city")

var cities : Array[City]

var heroes : Array[Hero] = []


func use_bot(bot_enabled : bool):
	if bot_enabled == (bot_engine != null):
		return
	if not bot_enabled:
		remove_child(bot_engine)
		bot_engine = null
	else:
		bot_engine = ExampleBot.new(self)
		add_child(bot_engine)


func your_turn():
	#UI stuff to let player know its his turn,
	# in case play is AI, call his decision maker

	if NET.client: # AI is simulated on server only
		return

	if bot_engine != null:
		bot_engine.play_move()

	print("your move " + player_name)

## Checks if player has enough goods for purchase
func has_enough(cost : Goods) -> bool:
	return goods.has_enough(cost)

## If there are sufficient goods -> true + goods are substracted
func purchase(cost : Goods) -> bool:
	if goods.has_enough(cost):
		goods.subtract(cost)
		return true
	print("not enough money")
	return false
