extends Node

"""Bloodborne board game
Do walki staje postać gracz i jakiś potwór.
Gracz może w każdej turze walki wybrać jeden z listy ataków (3),
Ataki mają właściwości: prędkość, obrażenia, efekt
Potwór wybiera jeden losowy atak ze swojej puli

Ataki są wykonywane w kolejności ich prędkości.
(Przy takiej samej mogą odbyć się “równocześnie”)

Pula ataków potwora może zawierać takie same ataki. Każdy jego atak
wykorzystuje ten atak z puli. Po ich wyczerpaniu pula się resetuje.
{Pozwala to graczowi przewidywać ataki}

Opcjonalna mechanika:
(W oryginalnej planszówce jak gracz wykonał np. atak B, to musiał wykonać atak
A i C zanim mógł ponownie wykonać atak B, to możesz też dodać)


Lista efektów:
	Obecna tura:
		Ogłuszenie: następny atak przeciwnika w tej turze jest anulowany.
		Kradzież zdrowa: wylecz 1 punkt zdrowia utracony w tej turze
	Przyszłe tury:
		W następnej rundzie atak przeciwnika jest o 1 punkt
		obrażeń/prędkości słabszy

"""


class Fighter:
	var current_attacks = []  # used only by monster
	var attacks = []
	var health = 10
	var status = ""
	
	func take_damage(attack):
		health -= attack.damage
		status = attack.effect
	
	func player_combat():
		return attacks[randi_range(0, attacks.size())]
		
	
	func monster_combat():
		if current_attacks.size() == 0:
			current_attacks = attacks
		
		var chosen_attack_id = randi_range(0, current_attacks.size())
		var chosen_attack = current_attacks[chosen_attack_id]
		current_attacks.remove_at(chosen_attack_id)
		return chosen_attack
	



class Attack:
	var damage
	var speed
	var effect
	
	func _init(dmg=1, spd=2, eff=""):
		damage = dmg
		speed = spd
		effect = eff


func _ready():
	var player = Fighter.new()
	
	var attacks_data = [[2, 2, "stun"], [1, 3], [2, 2, "steal"], [3, 1, "damage"]]
	var list_of_attacks = []
	for attack in attacks_data:
		list_of_attacks.append(Attack.new(attack))
	player.attacks = list_of_attacks[0]
	
	var list_of_monsters = [1]
	
	
	
	while player.health > 0:
		var enemy = Fighter.new()
		var effects = ["", ""]
		while player.health > 0 and enemy.health > 0:
			var player_attack = player.player_combat()
			var enemy_attack = enemy.monster_combat()
			
			var sides = [[player, player_attack], [enemy, enemy_attack]]
			for side in sides:
				if side[0].status == "speed":
					side[1].speed -= 1
				elif side[0].status == "damage":
					side[1].damage -= 1
				
			
			
			if sides[0][1].speed < sides[0][1].speed:
				var temp = sides[0]
				sides[0] = sides[1]
				sides[1] = temp
			
			if sides[0][1].speed == sides[0][1].speed:
				sides[0][0].take_damage(sides[1][1])
				sides[1][0].take_damage(sides[0][1])

			else:
				sides[1][0].take_damage(sides[0][1])
				if sides[1][0].health > 0 and sides[0][1].effect != "stun":
					sides[0][0].take_damage(sides[1][1])
					if sides[1][1].effect == "steal":
						sides[1][0].health += 1

			
			'''if player_attack.speed > enemy_attack.speed:
				enemy.health -= player_attack.damage
				if enemy.health > 0 and player_attack.effect != "stun":
					player.health -= enemy_attack.damage
					if enemy_attack.effect == "steal":
						enemy.health += 1
				
			elif enemy_attack.speed > player_attack.speed:
				player.health -= enemy_attack.damage
				if player.health > 0 and enemy_attack.effect != "stun":
					enemy.health -= player_attack.damage
					if player_attack.effect == "steal":
						player.health += 1

			else:
				player.health -= enemy_attack.damage
				enemy.health -= player_attack.damage'''
			
			
			
		print("Player: ", player.health, "   Monster: ", enemy.health)
		



func _process(delta):
	pass
