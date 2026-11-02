class_name CardVerticalBridge
extends CardLineHop

func _init() -> void:
	id = "vertical_bridge"
	icon_path = "res://assets/sprites/cards/icons/vertical_bridge.png"
	name = "Ponte Vertical"
	description = "Cria uma ponte numa casa clara por 4 rodadas. Peças acima ou abaixo dela pulam para o outro lado, se a casa estiver livre."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func _vertical() -> bool:
	return true

func _bridge_name() -> String:
	return "PONTE VERTICAL!"
