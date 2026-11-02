class_name CardVision
extends ActionCard

const PEEK_COUNT: int = 3

func _init() -> void:
	id = "vision"
	icon_path = "res://assets/sprites/cards/icons/vision.png"
	name = "Visão"
	description = "Mostra as 3 cartas do topo do seu baralho e você leva 1 delas para a mão."
	rarity = Rarity.COMMON
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var deck_mgr = context.get("deck_mgr")
	return deck_mgr != null and not deck_mgr.draw_pile.is_empty()

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var deck_mgr = context.get("deck_mgr")
	var main_node = context.get("main")
	if deck_mgr == null or deck_mgr.draw_pile.is_empty():
		return
	# O topo do baralho é o fim da lista (compra = pop_back).
	var n: int = mini(PEEK_COUNT, deck_mgr.draw_pile.size())
	var top: Array = []
	for i in range(n):
		top.append(deck_mgr.draw_pile[deck_mgr.draw_pile.size() - 1 - i])

	var picked: ActionCard = top[0]
	if main_node != null and top.size() > 1:
		var modal := CardPeekModal.new()
		main_node.add_child(modal)
		modal.present(top)
		picked = await modal.chosen
		modal.queue_free()

	# A própria Visão ainda está na mão enquanto executa e sai logo depois (a mão
	# passa por 6 por um instante). Quem atualiza a UI é o descarte dela.
	deck_mgr.draw_pile.erase(picked)
	deck_mgr.hand.append(picked)
	_pop_banner(context, "VISÃO!", Color(0.55, 0.85, 1.0))
