class_name CardPlantTree
extends CardSpawnNeutral

func _init() -> void:
	super._init()
	id = "plant_tree"
	icon_path = "res://assets/sprites/cards/icons/plant_tree.png"
	name = "Plantar Arvore"
	description = "Faz brotar uma arvore numa casa escura vazia a sua escolha. Ela bloqueia a casa e nao anda; qualquer lado pode derruba-la pulando por cima (opcional, sem ouro)."
	rarity = Rarity.COMMON

func _make_piece(_owner_team: int) -> BoardPiece:
	return BoardPiece.make_tree()

func _banner_text() -> String:
	return "UMA ARVORE BROTA!"
