class_name CardPlaceSarcophagus
extends CardSpawnNeutral

func _init() -> void:
	super._init()
	id = "place_sarcophagus"
	icon_path = "res://assets/sprites/cards/icons/place_sarcophagus.png"
	name = "Sarcofago"
	description = "Faz surgir um sarcofago numa casa escura vazia a sua escolha. Quando alguem o derrubar (pulando por cima), uma MUMIA nasce no lugar: uma peca comum SUA, mesmo que o inimigo o tenha derrubado."
	rarity = Rarity.EPIC

func _make_piece(owner_team: int) -> BoardPiece:
	var s := BoardPiece.make_sarcophagus()
	s.mummy_owner = owner_team
	return s

func _banner_text() -> String:
	return "UM SARCOFAGO SURGE!"

func _banner_color() -> Color:
	return Color(0.8, 0.7, 0.4)
