class_name E
extends Object


## Symbols for units in battle, assigned to each side of a hex
enum Symbols
{
	EMPTY,
	# CLASSIC
	SPEAR,
	AXE,
	SHIELD,
	BOW,
	PUSH,  # weak push power
	# Items
	STRONG_AXE,
	STRONG_SPEAR,
	STAFF,
	
	STRONG_SHIELD,
	ATTACK_SHIELD,
	
	TOWERSHIELD,
	STRONG_TOWERSHIELD,

	FIST,  # STRONG PUSH
	MACE,  # NORMAL PUSH
	DAGGER,

	# Parry
	SWORD,
	GREAT_SWORD,

	# Parry Break
	SCYTHE,
	SICKLE,
}


enum PlayerType
{
	OBSERVER,
	HUMAN,
	BOT,
}

enum CameraPosition {WORLD, BATTLE}

enum WorldMapTiles
{
	SENTINEL,

	# fundamental game logic
	EMPTY,
	WALL,

	# UI based menu interfaces
	CITY,
	PLACE,

	# undefined
	DEPOSIT,
}


static func symbol_to_name(s : Symbols) -> String:
	return Symbols.keys()[s]


static func player_type_to_name(pt : PlayerType) -> String:
	return PlayerType.keys()[pt].to_lower()


static func world_map_tile_to_name(wmt : WorldMapTiles) -> String:
	return WorldMapTiles.keys()[wmt].to_lower()


func _init():
	assert(false, "do not instantiate this class, it's static only")

