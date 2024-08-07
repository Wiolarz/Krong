class_name BattleSpell extends Resource

@export var name : String = ""
@export var icon_path : String = ""

## used to debug
func _to_string() -> String:
	return "BattleSpell: " + name





func enchanted_unit_dies() -> void:
	match name:
		"Vengeance":
			#get_unit(target_tile_coord).effects.append(spell)
			#print(get_unit(target_tile_coord).effects)
			print("zemsta")
			pass
		_:
			return
