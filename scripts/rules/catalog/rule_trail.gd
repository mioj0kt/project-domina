class_name RuleTrail
extends RuleCard

const FIRE_TURNS: int = 1

func _init() -> void:
	id = "trail"
	name = "Lei do Rastro"
	description = "A casa de onde sua Dama saiu pega fogo por 1 turno: quem pousar nela é destruído."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 47

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	var piece: BoardPiece
	var from_pos := Vector2i(-1, -1)
	if event_name == &"step_moved":
		piece = context.get("piece")
		from_pos = context.get("from", from_pos)
	elif event_name == &"piece_captured":
		piece = context.get("attacker")
		from_pos = context.get("attacker_from", from_pos)
	else:
		return
	if piece == null or not piece.is_king or not applies_to_team(piece.owner_team, board.human_team_color) or from_pos.x < 0:
		return
	board.ignite(from_pos, FIRE_TURNS, piece.owner_team == board.human_team_color)
	board.rule_fired.emit(id)
