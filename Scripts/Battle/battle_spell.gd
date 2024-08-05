class_name BattleSpell extends Resource

@export var name : String = ""
@export var icon_path : String = ""
const xd = 1


func _to_string() -> String:
	return "BattleSpell: " + name
