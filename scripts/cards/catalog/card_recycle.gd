class_name CardRecycle
extends ActionCard

func _init() -> void:
	id = "recycle"
	icon_path = "res://assets/sprites/cards/icons/recycle.png"
	name = "Reciclar"
	description = "Devolve para a mão a última carta usada no duelo (menos outra Reciclar)."
	rarity = Rarity.RARE
	target_type = TargetType.NONE

# A carta que volta: a última do descarte que não seja uma Reciclar. Isso importa
# porque a IA descarta a carta ANTES do efeito (o jogador, depois): sem esse filtro
# a Reciclar da IA se devolvia para a mão e era usada de novo, sem fim.
static func pick_target(deck_mgr) -> ActionCard:
	if deck_mgr == null:
		return null
	for i in range(deck_mgr.discard_pile.size() - 1, -1, -1):
		var c: ActionCard = deck_mgr.discard_pile[i]
		if c.id != "recycle":
			return c
	return null

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	return pick_target(context.get("deck_mgr")) != null

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var deck_mgr = context.get("deck_mgr")
	var card: ActionCard = pick_target(deck_mgr)
	if card == null:
		return
	# Esta carta ainda pode estar na mão (o controller do jogador descarta depois),
	# então a mão pode ficar com 6 por um instante — ela mesma sai logo em seguida.
	deck_mgr.discard_pile.erase(card)
	deck_mgr.hand.append(card)
	_pop_banner(context, "RECICLADA!", Color(0.45, 0.85, 0.55))
