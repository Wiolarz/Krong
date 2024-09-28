# Singleton - CFG
extends Node

enum BotSpeed
{
	FREEZE = 0,
	NORMAL = 60,
	FAST = 1,
}
## dont set it lower than 2 * animation_speed_frames
## or ai will not wait for animations to finish
var bot_speed_frames : BotSpeed = BotSpeed.NORMAL

enum AnimationSpeed
{
	NORMAL = 20,
	INSTANT = 666,
}
## both rotation and move take this much time,
## so unit move takes between X and 2X
var animation_speed_frames : AnimationSpeed = AnimationSpeed.NORMAL

## battle map is placed this far to the right after world map bounds
const MAPS_OFFSET_X = 7000


#region Paths

const BATTLE_MAPS_PATH = "res://Resources/Battle/Battle_Maps/"
const UNITS_PATH = "res://Resources/Battle/Units/"
const HEROES_PATH = "res://Resources/Battle/Heroes/"
const BUILDINGS_PATH = "res://Resources/Factions/Buildings/"
const BATTLE_PRESETS_PATH = "res://Resources/Presets/Battle/"
const WORLD_MAPS_PATH = "res://Resources/World/World_maps/"
const SENTINEL_TILE_PATH = "res://Resources/World/World_tiles/sentinel.tres"
const BATTLE_MAP_TILES_PATH = "res://Resources/Battle/Battle_tiles/"
const WORLD_MAP_TILES_PATH = "res://Resources/World/World_tiles/"
const SYMBOLS_PATH = "res://Resources/Battle/Symbols/"
const BATTLE_BOTS_PATH = "res://Resources/Battle/Bots"

const REPLAY_DIRECTORY = "user://replays/"
const PLAYER_OPTIONS_PATH = "user://player_options.tres"

var FACTION_ELVES : DataFaction = load("res://Resources/Factions/elf.tres")
var FACTION_ORCS : DataFaction = load("res://Resources/Factions/orc.tres")
var FACTIONS_LIST : Array[DataFaction] = [
	FACTION_ELVES,
	FACTION_ORCS,
]



const UNIT_FORM_SCENE = preload("res://Scenes/Form/UnitForm.tscn")
var HEX_TILE_FORM_SCENE := load("res://Scenes/Form/TileForm.tscn") as PackedScene
const SUMMON_BUTTON_TEXTURE:Texture2D = preload("res://Art/battle_map/grass.png")

const DEFAULT_ARMY_FORM = preload("res://Scenes/Form/ArmyForm.tscn")


# Neutral Units armies
const HUNT_WOOD_PATH : String = "res://Resources/Presets/Army/hunt_wood/"
const HUNT_IRON_PATH : String = "res://Resources/Presets/Army/hunt_iron/"
const HUNT_RUBY_PATH : String = "res://Resources/Presets/Army/hunt_ruby/"

const OUTPOST_WOOD_PATH : String = "res://Resources/Presets/Army/outpost_defenders/outpost_wood_defender.tres"
const OUTPOST_IRON_PATH : String = "res://Resources/Presets/Army/outpost_defenders/outpost_iron_defender.tres"
const OUTPOST_RUBY_PATH : String = "res://Resources/Presets/Army/outpost_defenders/outpost_ruby_defender.tres"

#const HUNT_PATHS : Array[String] = [HUNT_WOOD_PATH, HUNT_IRON_PATH, HUNT_RUBY_PATH]


#endregion Paths


#region Colors

var TEAM_COLORS : Array[DataPlayerColor] = [
	DataPlayerColor.create("purple", Color(0.9, 0.2, 0.85)),
	DataPlayerColor.create("green", Color(0.0, 0.9, 0.0)),
	DataPlayerColor.create("yellow", Color(0.9, 0.8, 0.0)),
	DataPlayerColor.create("red", Color(1.0, 0.0, 0.0)),
	DataPlayerColor.create("blue", Color(0.0, 0.4, 1.0)),
	DataPlayerColor.create("orange", Color(0.9, 0.5, 0.0)),
]

var NEUTRAL_COLOR := \
	DataPlayerColor.create_with_texture("neutral", Color(0.5, 0.5, 0.5), \
		"gray_color")

var DEFAULT_TEAM_COLOR := \
	DataPlayerColor.create("gray", Color(0.5, 0.5, 0.5))


func get_team_color_at(index : int) -> DataPlayerColor:
	if not index in range(TEAM_COLORS.size()):
		return DEFAULT_TEAM_COLOR
	return TEAM_COLORS[index]

#endregion Colors


#region Battle maps

var DEFAULT_BATTLE_MAP : DataBattleMap = \
	load("res://Resources/Battle/Battle_Maps/basic5x5.tres")

var BIGGER_BATTLE_MAP : DataBattleMap = \
	load("res://Resources/Battle/Battle_Maps/8x7duel_10maxUnits.tres")

#endregion


#region Multiplayer

## URL for trying to determine external IP
## must support plain GET request
## that returns address as a single text line in the response body
const FETCH_EXTERNAL_IP_GET_URL = "https://api.ipify.org"

const POLYAPI_BASE_URL = "https://polyserver.onrender.com/"
# for tests:
# const POLYAPI_BASE_URL = "http://localhost:3001/"

#endregion Multiplayer


#region World Map properties

const HERO_LEVEL_CAP = 7

func get_start_goods() -> Goods:
	return Goods.new(10,5,3)

const WORLD_MOVABLE_TILES = [
	"empty",
	"iron_mine",
	"sawmill",
	"ruby_cave",
	"wood_hunt",
	"iron_hunt",
	"ruby_hunt",
	"elf_city",
	"orc_city",
]

#endregion World Map properties


#region Chess clock

const CHESS_CLOCK_BATTLE_TIME_PER_PLAYER_MS = 3 * 60 * 1000 * 69
const CHESS_CLOCK_BATTLE_TURN_INCREMENT_MS = 2 * 1000

#endregion chess clock


#region Debugging & tests

var debug_check_bmfast_integrity := true
var debug_check_bmfast_internals := true
var debug_mcts_max_saved_fail_replays := 16
var debug_mcts_save_failed_replays_to_file := true
var debug_save_failed_bmfast_integrity := true

#endregion


#region Player Options

var player_options : PlayerOptions

const DEFAULT_USER_NAME : String = "(( you ))"

var DEFAULT_MODE_IS_BATTLE : bool :
	get: return player_options.use_default_battle
var AUTO_START_GAME : bool :
	get: return player_options.autostart_map

var LAST_USED_BATTLE_PRESET : PresetBattle :
	get: return player_options.last_used_battle_preset
var LAST_USED_WORLD_PRESET : PresetWorld : # TODO implement this
	get: return player_options.last_used_world_preset

func save_last_used_for_host_setup(\
		address : String, port : int, username : String) -> void:
	player_options.login = username
	player_options.last_hosting_address_used = address
	player_options.last_hosting_port_used = port
	save_player_options()


func save_last_used_for_joining(\
		address : String, port : int,\
		username : String, randomise_join_login : bool) -> void:
	player_options.login = username
	player_options.randomise_join_login = randomise_join_login
	player_options.last_remote_host_address = address
	player_options.last_remote_host_port = port
	save_player_options()


func get_username() -> String:
	return player_options.login


func _init():
	if FileAccess.file_exists(PLAYER_OPTIONS_PATH):
		player_options = load(PLAYER_OPTIONS_PATH)
	if not player_options:
		player_options = PlayerOptions.new()
		save_player_options()

func save_player_options():
	ResourceSaver.save(player_options, PLAYER_OPTIONS_PATH)

#endregion Player Options
