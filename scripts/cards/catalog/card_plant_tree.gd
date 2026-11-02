class_name CardPlantTree
extends CardSpawnNeutral

func _init() -> void:
	super._init()
	id = "plant_tree"
	icon_path = "res://assets/sprites/cards/icons/plant_tree.png"
	name = "Plantar Árvore"
	description = "Planta uma árvore numa casa escura vazia. Ela bloqueia a casa, e qualquer lado pode derrubá-la pulando por cima (opcional)."
	rarity = Rarity.COMMON

func _make_piece(_owner_team: int) -> BoardPiece:
	return BoardPiece.make_tree()

func _banner_text() -> String:
	return "UMA ARVORE BROTA!"
