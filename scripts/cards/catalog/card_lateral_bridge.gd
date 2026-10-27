class_name CardLateralBridge
extends CardLineHop

func _init() -> void:
	id = "lateral_bridge"
	icon_path = "res://assets/sprites/cards/icons/lateral_bridge.png"
	name = "Ponte Lateral"
	description = "Construa uma ponte numa casa clara a sua escolha por 4 rodadas. Todas as peças lado dela podem atravessar para o outro lado se a casa de destino estiver livre."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func _vertical() -> bool:
	return false

func _bridge_name() -> String:
	return "PONTE LATERAL!"
