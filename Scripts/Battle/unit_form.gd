class_name UnitForm
extends Node2D

var unit : Unit

var _target_tile : TileForm
var _move_speed : float

var _target_rotation_degrees : float
var _rotation_speed : float

var _play_death_anim : bool


static func create(new_unit : Unit) -> UnitForm:
	var result = CFG.UNIT_FORM_SCENE.instantiate()
	result.name = new_unit.template.unit_name
	result.unit = new_unit
	new_unit.waits_for_form = true
	new_unit.unit_turned.connect(result.on_unit_turned)
	new_unit.unit_moved.connect(result.on_unit_moved)
	new_unit.unit_died.connect(result.on_unit_died)
	new_unit.select_request.connect(result.set_selected)

	result.apply_graphics(new_unit.template)

	result.global_position = B_GRID.get_tile(new_unit.coord).global_position
	result.rotation_degrees = new_unit.unit_rotation * 60
	result.get_node("sprite_unit").rotation = -result.rotation


	return result

## HACK, this is for visuals only for summon UI
## no underlying Unit exists
static func create_for_summon_ui(template: DataUnit) -> UnitForm:
	var result = CFG.UNIT_FORM_SCENE.instantiate()
	result.apply_graphics(template)
	return result


func _physics_process(delta):
	if _animate_rotation():
		return
	if _animate_movement():
		return
	_animate_death(delta)


func on_unit_turned():
	var new_side = unit.unit_rotation
	_target_rotation_degrees = (60 * (new_side))

	var current_rotation_degrees = fmod(rotation_degrees + 360, 360)
	var relative_rotation = _target_rotation_degrees - current_rotation_degrees
	_rotation_speed = abs(relative_rotation) / CFG.animation_speed_frames


func on_unit_moved():
	var new_coord = unit.coord
	var tile = B_GRID.get_tile(new_coord)

	_target_tile = tile
	_move_speed = (tile.global_position - global_position).length() / CFG.animation_speed_frames


func on_unit_died():
	_play_death_anim = true


func _animate_rotation() -> bool:
	if abs(fmod(rotation_degrees, 360) - _target_rotation_degrees) < 0.1:
		return false

	if CFG.animation_speed_frames == CFG.AnimationSpeed.INSTANT:
		rotation_degrees = _target_rotation_degrees
		$sprite_unit.rotation = -rotation
		unit.anim_end.emit()
		return true

	var current_rotation_degrees = fmod(rotation_degrees + 360, 360)
	var relative_rotation = _target_rotation_degrees - current_rotation_degrees
	#print(relative_rotation, "  ", p_direction, "   ", current_rotation)
	if relative_rotation < 0:
		relative_rotation += 360
	if relative_rotation > 180:
		relative_rotation -= 360
	var this_frame_rotation = clamp(relative_rotation, -1, 1) * _rotation_speed
	if abs(relative_rotation) < abs(this_frame_rotation):
		rotation = deg_to_rad(_target_rotation_degrees)
		unit.anim_end.emit()
	else:
		rotation += deg_to_rad(this_frame_rotation)
	$sprite_unit.rotation = -rotation
	return true


func _animate_movement() -> bool:
	if _target_tile == null:
		return false

	if CFG.animation_speed_frames == CFG.AnimationSpeed.INSTANT:
		position = _target_tile.position
		unit.anim_end.emit()
		return true

	global_position = global_position.move_toward(_target_tile.global_position, _move_speed)
	if (global_position - _target_tile.global_position).length_squared() < 0.01:
		global_position = _target_tile.global_position
		_target_tile = null
		unit.anim_end.emit()
	return true


func _animate_death(delta) -> bool:
	if not _play_death_anim:
		return false

	scale.x -= 3 * delta
	if scale.x < 0:
		scale.x = 0
		_play_death_anim = false
		unit.anim_end.emit()
	scale.y = scale.x
	return true


func set_selected(is_selected : bool):
	var c = Color.RED if is_selected else Color.WHITE
	$sprite_unit.modulate = c


func apply_graphics(template : DataUnit):
	var unit_texture = load(template.texture_path) as Texture2D
	_apply_unit_texture(unit_texture)
	for dir in range(0,6):
		var symbol_texture = template.symbols[dir].texture_path
		_apply_symbol_sprite(dir, symbol_texture)


## WARNING: called directly in UNIT EDITOR
func _apply_symbol_sprite(dir : int, texture_path : String) -> void:
	var symbol_sprite = $"Symbols".get_children()[dir].get_child(0).get_child(0)
	if texture_path == null or texture_path.is_empty():
		symbol_sprite.texture = null
		symbol_sprite.hide()
		return
	symbol_sprite.texture = load(texture_path)
	symbol_sprite.show()


## WARNING: called directly in UNIT EDITOR
func _apply_unit_texture(texture : Texture2D) -> void:
	$sprite_unit.texture = texture
