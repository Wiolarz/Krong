extends Node

#class_name rps_dice_1


"List of heroes:	
	Berserker - [] [1d20] hp15
	Ice Mage - [-1TD] [1d4] hp 10
	Ranger - [] [2d6] hp 8
	
	Knight [] [1d12 1d] hp 6
	"


static func test():
	print(10)


func ver1():
	# p player
	# e enemy
	# a attacker  d defender
	var p_weapon = [6, 6]
	var e_weapon = [4, 4]
	
	var p_hp = 20
	var e_hp = 12
	
	while e_hp > 0 and p_hp > 0:
		#player attack
		e_hp -= randi_range(1, p_weapon[0])
		
		p_hp -= randi_range(1, e_weapon[0])
		
	
	print(p_hp, " ", e_hp)


static func ver2():
	
	# p player
	# e enemy
	# a attacker  d defender
	var p_weapon = [6, 6]
	var e_weapon = [4, 4]
	
	var p_hp = 20
	var e_hp = 12
	
	while e_hp > 0 and p_hp > 0:
		#player attack
		e_hp -= randi_range(1, p_weapon[0])
		
		p_hp -= randi_range(1, e_weapon[0])
		
	
	print(p_hp, " ", e_hp)


func shout(a = 0, ):
	print("xyz")

func ver3():
	var tester1 = Fighter.new("Tank")
	var tester2 = Hero.new("Tank")
	
	
	
	#var ab = call(shout())
	#ab
	#ab
	#tester1.use_spell()
	
	
	
	for attempts in range(0):
			
		var fighter1 = Fighter.new("Tank")
		var fighter2 = Fighter.new("Mage")
		
		
		if fighter1.magic != null:
			fighter2.dmg.remove_at(0)
		
		if fighter2.magic != null:
			fighter1.dmg.remove_at(0)
		
		while fighter1.hp > 0 and fighter2.hp > 0:
			# 1 fighter attack
			var attack = 0
			for dice in fighter1.dmg:
				attack += randi_range(1, dice)
			fighter2.hp -= attack
			
			attack = 0
			for dice in fighter2.dmg:
				attack += randi_range(1, dice)
			fighter1.hp -= attack
			
		print(fighter1.hp, "  ", fighter2.hp)


class Fighter:
	var hp = 1
	var dmg = [1]
	var magic = null
	
	func _init(hero_type):
		if hero_type == "Tank":
			hp = 20
			dmg = [20]
		elif hero_type == "Rouge":
			hp = 12
			dmg = [6, 6]
		elif hero_type == "Mage":
			hp = 8
			dmg = [4]
			magic = Spell.new("remove_max")
	func use_spell():
		print("magic")

class Spell:
	var uses = 1
	var effect = null
	func _init(spell_name):
		effect = spell_name
		
	func use(target):
		while uses > 0:
			
			if effect == "remove_max":
				if target.dmg.size > 0:
					uses -= 1
					target.dmg.sort()
					target.dmg.remove_at(0)
				else:
					break
	
class Hero:
	extends Fighter
	
	
	
	func use_spell():
		print("elo")
	
	


class Rouge:
	
	var hp = 12
	var dmg = [6, 6]
	var magic = null

class Mage:
	var hp = 6
	var dmg = [4]
	var magic = 1

var game_state = 1

var player_input = 0

var tank_hp = 20
var rouge_hp = 12
var tank_dmg = [20]
var rouge_dmg = [6, 6]
 

var player_squad
var enemy_squad



func ver2_5():
	print(player_squad)
	print(enemy_squad)
	# INPUT
	if player_input >= player_squad.size():
		player_input = 0  # correcting player's mistake if they choose a fighter that isn't alive anymore
	var enemy_input = randi_range(0, 1)
	if enemy_input >= enemy_squad.size():
		enemy_input = 0 
		
		
	var enemy_damage = 0
	var player_damage = 0
	
	for dice in player_squad[player_input][1]:
		player_damage += randi_range(1, dice)
	
	for dice in enemy_squad[enemy_input][1]:
		enemy_damage += randi_range(1, dice)
	
	
	player_squad[player_input][0] -= enemy_damage
	enemy_squad[enemy_input][0] -= player_damage
	print("player hp-", player_squad[player_input][0], " player_dmg-", player_damage)
	print("enemy hp-", enemy_squad[enemy_input][0], " enemy_dmg-", enemy_damage)
	# removing dead fighters
	if player_squad[player_input][0] <= 0:
		player_squad.remove_at(player_input)
	if enemy_squad[enemy_input][0] <= 0:
		enemy_squad.remove_at(enemy_input)
	
	# checking win conditions
	if enemy_squad.size() == 0 and player_squad.size() == 0:
		print("DRAW")
		game_state = 0
	
	elif enemy_squad.size() == 0:
		print("YOU WON")
		game_state = 0
		
	elif player_squad.size() == 0:
		print("YOU LOST")
		game_state = 0
		
	

func _ready():
	print("Start  version 2_5")
	setup_game()
	ver2_5()

func setup_game():
	player_squad = [[tank_hp, tank_dmg], [tank_hp, tank_dmg]]
	enemy_squad = [[rouge_hp, rouge_dmg], [rouge_hp, rouge_dmg]]

func _process(delta):
	player_input = 0
	if Input.is_action_just_pressed("KEY_1"):
		player_input = 1
	elif Input.is_action_just_pressed("KEY_2"):
		player_input = 2
	if player_input > 0:
		print(player_input)
		if game_state == 1:
			ver2_5()
		elif player_input == 1:
			setup_game() # restart game
			game_state = 1
		else:
			get_tree().quit()
