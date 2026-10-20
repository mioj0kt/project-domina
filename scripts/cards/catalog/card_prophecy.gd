class_name CardProphecy
extends ActionCard

func _init() -> void:
	id = "prophecy"
	icon_path = "res://assets/sprites/cards/icons/prophecy.png"
	name = "Profecia"
	description = "Revela qual jogada o inimigo pretende fazer no próximo turno dele."
	rarity = Rarity.RARE
	target_type = TargetType.NONE

func execute(board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("predicted_ai_move" in main_node):
		return

	var search_depth = 3 if max(board.rows, board.cols) >= 10 else 4
	var ai_team = main_node.ai_team if "ai_team" in main_node else Board.BLACK
	var predicted = CheckersAI.get_best_move(board, search_depth, ai_team)

	if predicted.size() > 0:
		main_node.predicted_ai_move = predicted
