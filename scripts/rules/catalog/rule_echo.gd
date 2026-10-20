class_name RuleEcho
extends RuleCard

# A primeira Carta de Ação usada em cada duelo (qualquer raridade) volta para
# a mão depois de resolvida. Quem aplica é ActionCardController, que consulta
# try_consume_echo() logo depois de descartar a carta.
var used_this_duel: bool = false

func _init() -> void:
	id = "echo"
	name = "Lei do Eco"
	description = "A primeira Carta que voce usar em cada duelo, de qualquer raridade, volta para a sua mão depois de usada."
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 60

func on_game_event(event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	if event_name == &"duel_started":
		used_this_duel = false

# true (e consome) se ainda não ecoou neste duelo.
func try_consume_echo() -> bool:
	if used_this_duel:
		return false
	used_this_duel = true
	return true
