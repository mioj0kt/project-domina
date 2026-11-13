class_name RuleEarlyPromotion
extends RuleCard

func _init() -> void:
	id = "early_promotion"
	name = "Promoção Relâmpago"
	description = "Suas peças viram Dama já na penúltima fileira."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	priority = 30

func check_custom_promotion(piece: BoardPiece, to_pos: Vector2i, board: RefCounted) -> bool:
	if piece.is_king:
		return false
	
	# Promove na penúltima linha (se estiver subindo)
	if piece.owner_team == board.human_team_color and to_pos.y <= 1:
		return true
	elif piece.owner_team == board.ai_team_color and to_pos.y >= (board.rows - 2):
		return true
		
	return false

func get_promotion_trigger_banner(to_pos: Vector2i, piece: BoardPiece = null, board: RefCounted = null) -> Dictionary:
	# Só quando foi ESTA lei que coroou: a peça parou na penúltima fileira dela
	# (na última a coroação é a normal).
	var early_row: bool = to_pos.y == 1
	if piece != null and board != null and piece.owner_team != board.human_team_color:
		early_row = to_pos.y == board.rows - 2
	if early_row:
		return {"text": "PROMOÇÃO RELAMPAGO!", "color": Color(1.0, 0.85, 0.25)}
	return {}
