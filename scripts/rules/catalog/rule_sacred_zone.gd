class_name RuleSacredZone
extends RuleCard

const MAX_USES: int = 2
var uses: int = 0

func _init() -> void:
	id = "sacred_zone"
	name = "Zona Sagrada"
	description = "Suas peças comuns viram Dama ao pisar numa das 4 casas centrais. Vale só 2 vezes por duelo."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 32

func check_custom_promotion(piece: BoardPiece, to_pos: Vector2i, board: RefCounted) -> bool:
	if piece.is_king or uses >= MAX_USES:
		return false
	return board.is_center_tile(to_pos.y, to_pos.x)

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:
		&"duel_started":
			uses = 0
		&"on_promotion":
			var p: BoardPiece = context.get("piece")
			var pos: Vector2i = context.get("pos", Vector2i(-1, -1))
			if p != null and p.owner_team == board.human_team_color and pos.x >= 0 and board.is_center_tile(pos.y, pos.x):
				uses += 1

func get_promotion_trigger_banner(to_pos: Vector2i, _piece: BoardPiece = null, board: RefCounted = null) -> Dictionary:
	if board != null and not board.is_center_tile(to_pos.y, to_pos.x):
		return {}
	return {"text": "ZONA SAGRADA!", "color": Color(1.0, 0.9, 0.3)}
