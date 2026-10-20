class_name CardRestock
extends ActionCard

func _init() -> void:
	id = "restock"
	icon_path = "res://assets/sprites/cards/icons/restock.png"
	name = "Reabastecer"
	description = "Descarta as outras cartas da mão e compra a mesma quantidade."
	rarity = Rarity.COMMON
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var deck_mgr = context.get("deck_mgr")
	if deck_mgr == null or deck_mgr.draw_pile.is_empty():
		return false
	# Precisa de pelo menos uma OUTRA carta na mao pra trocar.
	return deck_mgr.hand.size() > 1

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var deck_mgr = context.get("deck_mgr")
	if deck_mgr == null:
		return

	var others: Array = deck_mgr.hand.filter(func(c): return c != self)
	var swap: int = min(others.size(), deck_mgr.draw_pile.size())
	for i in range(swap):
		var card: ActionCard = others[i]
		deck_mgr.hand.erase(card)
		deck_mgr.discard_pile.append(card)

	deck_mgr.draw_cards(swap)
	deck_mgr.hand_updated.emit()
	_pop_banner(context, "MAO RENOVADA!", Color(0.95, 0.8, 0.35))
