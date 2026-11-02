class_name CardLateralBridge
extends CardLineHop

func _init() -> void:
	id = "lateral_bridge"
	icon_path = "res://assets/sprites/cards/icons/lateral_bridge.png"
	name = "Ponte Lateral"
	description = "Cria uma ponte numa casa clara por 4 rodadas. Peças à esquerda ou à direita dela pulam para o outro lado, se a casa estiver livre."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func _vertical() -> bool:
	return false

func _bridge_name() -> String:
	return "PONTE LATERAL!"
