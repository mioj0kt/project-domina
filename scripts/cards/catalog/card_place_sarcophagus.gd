class_name CardPlaceSarcophagus
extends CardSpawnNeutral

func _init() -> void:
	super._init()
	id = "place_sarcophagus"
	icon_path = "res://assets/sprites/cards/icons/place_sarcophagus.png"
	name = "Sarcófago"
	description = "Coloca um sarcófago numa casa escura vazia. Quem o derrubar pulando por cima solta uma múmia que é peça SUA, mesmo se foi o inimigo que derrubou."
	rarity = Rarity.EPIC

func _make_piece(owner_team: int) -> BoardPiece:
	var s := BoardPiece.make_sarcophagus()
	s.mummy_owner = owner_team
	return s

func _banner_text() -> String:
	return "UM SARCOFAGO SURGE!"

func _banner_color() -> Color:
	return Color(0.8, 0.7, 0.4)
