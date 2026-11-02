class_name CardPlantCactus
extends CardSpawnNeutral

func _init() -> void:
	super._init()
	id = "plant_cactus"
	icon_path = "res://assets/sprites/cards/icons/plant_cactus.png"
	name = "Plantar Cacto"
	description = "Planta um cacto numa casa escura vazia. Ele bloqueia a casa, e a peça que o derrubar pulando por cima é destruída."
	rarity = Rarity.RARE

func _make_piece(_owner_team: int) -> BoardPiece:
	return BoardPiece.make_cactus()

func _banner_text() -> String:
	return "UM CACTO BROTA!"

func _banner_color() -> Color:
	return Color(0.5, 0.85, 0.4)
