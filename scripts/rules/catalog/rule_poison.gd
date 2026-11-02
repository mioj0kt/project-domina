class_name RulePoison
extends RuleCard

# [LEI INIMIGA] Quando o JOGADOR captura uma peça inimiga em QUALQUER casa do
# tabuleiro, a casa onde ela estava pega fogo (reusa Board.fire_tiles
# da carta Terra Queimada: quem pousar ali é destruído).
const FIRE_TURNS: int = 2

func _init() -> void:
	id = "poison"
	name = "Lei do Veneno"
	description = "[LEI INIMIGA] Quando você captura, a casa da peça pega fogo por 2 turnos: quem pousar nela é destruído."
	category = Category.BOARD
	scope = Scope.AI_ONLY
	priority = 45

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"piece_captured":
		return
	var attacker: BoardPiece = context.get("attacker")
	var pos: Vector2i = context.get("victim_pos", Vector2i(-1, -1))
	if attacker == null or attacker.owner_team != board.human_team_color or pos.x < 0:
		return
	board.fire_tiles[pos] = FIRE_TURNS
	board.rule_fired.emit(id)
