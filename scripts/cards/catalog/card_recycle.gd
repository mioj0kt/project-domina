class_name CardRecycle
extends ActionCard

func _init() -> void:
	id = "recycle"
	icon_path = "res://assets/sprites/cards/icons/recycle.png"
	name = "Reciclar"
	description = "Devolve à sua mão a ultima carta usada neste duelo."
	rarity = Rarity.EPIC
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var deck_mgr = context.get("deck_mgr")
	return deck_mgr != null and not deck_mgr.discard_pile.is_empty()

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var deck_mgr = context.get("deck_mgr")
	if deck_mgr == null or deck_mgr.discard_pile.is_empty():
		return
	# Esta carta ainda esta na mao (e descartada pelo controller depois), entao
	# a mao pode ficar com 6 por um instante — ela mesma sai logo em seguida.
	var card: ActionCard = deck_mgr.discard_pile.pop_back()
	deck_mgr.hand.append(card)
	_pop_banner(context, "RECICLADA!", Color(0.45, 0.85, 0.55))
