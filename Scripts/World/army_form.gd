class_name ArmyForm
extends Node2D

var entity : Army

var coord:
	get: return entity.coord


var controller:
	get: return entity.controller

func _init():
	name = "ArmyForm"

func _process(_delta):
	var hero = entity.hero
	if hero:
		$MoveLabel.text = "Move %d / %d" % [hero.movement_points, hero.max_movement_points]
		$DescriptionLabel.text =  "%s\nlv %d (%d)" % [hero.hero_name, hero.level, hero.xp]
		$sprite_unit.modulate = Color.DIM_GRAY if not has_movement_points() \
				else Color.WHITE


static func create_hero_army(player : Player, hero_data : DataHero) -> ArmyForm:
	var result : ArmyForm = CFG.DEFAULT_ARMY_FORM.instantiate()
	result.name = hero_data.hero_name
	result.entity = Army.new()
	result.entity.controller = player
	result.entity.hero = Hero.create_hero(hero_data, player)
	result.get_node("sprite_unit").texture = \
		load(hero_data.data_unit.texture_path)
	return result

static func create_neutral_army(army_preset : PresetArmy) -> ArmyForm:
	var result : ArmyForm = CFG.DEFAULT_ARMY_FORM.instantiate()
	result.entity = Army.create_army_from_preset(army_preset)
	result.name = "Neutral_"+army_preset.resource_path.get_file()


	result.get_node("sprite_unit").texture = \
		load(army_preset.units[0].texture_path)

	result.get_node("sprite_unit").scale = Vector2(0.9, 0.9)
	result.get_node("MoveLabel").text = ""
	result.get_node("DescriptionLabel").text = ""

	return result


func has_movement_points() -> bool:
	return entity.hero.movement_points > 0


func place_on(tile):
	entity.coord = tile.coord
	position = tile.position


func move(tile):
	place_on(tile)


func spend_movement_point() -> void:
	assert(entity.hero.movement_points > 0)
	entity.hero.movement_points -= 1


func on_end_of_turn(player : Player):
	if player == entity.controller and entity.hero:
		entity.hero.movement_points = entity.hero.max_movement_points


func set_selected(is_selected : bool) -> void:
	$sprite_color.modulate = Color.RED if is_selected else Color.WHITE


func apply_losses(losses : Array[DataUnit]):
	entity.apply_losses(losses)
