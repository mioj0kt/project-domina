class_name CardSteal
extends ActionCard

# Roubo: tira uma carta aleatória da mão do adversário e põe na sua.
# context["opp_deck_mgr"] = baralho do adversário (o controller de cada lado põe).
# context["steal_filter"] (opcional, IA) = ids aceitos: a IA só rouba carta que
# sabe usar.

func _init() -> void:
	id = "steal"
	icon_path = "res://assets/sprites/cards/icons/steal.png"
	name = "Roubo"
	description = "Rouba uma carta aleatória da mão do inimigo para a sua."
	rarity = Rarity.EPIC
	target_type = TargetType.NONE

static func candidates(context: Dictionary) -> Array:
	var opp = context.get("opp_deck_mgr")
	if opp == null:
		return []
	var filter = context.get("steal_filter", null)
	var out: Array = []
	for c in opp.hand:
		if filter == null or (filter as Array).has(c.id):
			out.append(c)
	return out

func can_play(_board: Board, _team: int, context: Dictionary = {}) -> bool:
	return not candidates(context).is_empty()

func execute(_board: Board, _target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var opp = context.get("opp_deck_mgr")
	var mine = context.get("deck_mgr")
	var pool: Array = candidates(context)
	if opp == null or mine == null or pool.is_empty():
		return
	var card: ActionCard = pool[randi() % pool.size()]
	opp.hand.erase(card)
	opp.hand_updated.emit()
	var main = context.get("main")
	if main != null and "ai_card_reveal_view" in main and main.ai_card_reveal_view != null:
		var by_player: bool = team == main.human_team
		var vp: Vector2 = main.get_viewport().get_visible_rect().size
		var top := Vector2(vp.x / 2.0, 75.0)
		var bottom := Vector2(vp.x / 2.0, vp.y - 110.0)
		main.ai_card_reveal_view.show_steal(card, top if by_player else bottom, bottom if by_player else top, by_player)
		await main.ai_card_reveal_view.sequence_finished
	mine.hand.append(card)
	mine.hand_updated.emit()
