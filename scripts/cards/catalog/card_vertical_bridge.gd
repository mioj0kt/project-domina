class_name CardVerticalBridge
extends CardLineHop

func _init() -> void:
	id = "vertical_bridge"
	icon_path = "res://assets/sprites/cards/icons/vertical_bridge.png"
	name = "Ponte Vertical"
	description = "Construa uma ponte numa casa clara a sua escolha por 4 rodadas. Todas as peças ao lado dela podem atravessar para o outro lado se a casa de destino estiver livre."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func _vertical() -> bool:
	return true

func _bridge_name() -> String:
	return "PONTE VERTICAL!"
