extends Area2D

signal death()

@export var max_health = [10, 5, 2]
var cur_health = max_health


func damage(bullet):
	#if bullet.is_class(Bullet):
	print(cur_health)
	var pierced_plates = 0  # value by which bullet is weakened if it managed to pierce the ship
	for plate in range(bullet.armor_pierce):  # depending on bullet piercing power, it damages more plates
		if plate >= cur_health.size():
			break
		pierced_plates += 1
		cur_health[plate] -= bullet.damage
	
	bullet.scrape(pierced_plates)
	
	print(cur_health)
	if cur_health[-1] <= 0:
		print("emitted death")
		emit_signal("death")
		return
	

	# PLATES REMOVAL
	# could be replaced with simply skipping 0HP plates
	var to_be_removed = []
	
	for i in range(cur_health.size()):
		if cur_health[i] <= 0:
			to_be_removed.append(i)
	
	var i = 0
	for removal in to_be_removed:
		cur_health.pop_at(removal - i)
		i += 1


	
	
			
