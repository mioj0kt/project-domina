class_name CardCoinOfDestiny
extends ActionCard

func _init() -> void:
	id = "coin_of_destiny"
	icon_path = "res://assets/sprites/cards/icons/coin_of_destiny.png"
	name = "Moeda do Destino"
	description = "Escolha uma peça aliada comum e gire a moeda: se cair na cor dela, vira Dama na hora. Senão, a peça é perdida."
	rarity = Rarity.COMMON
	target_type = TargetType.ALLY_PIECE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	return not piece.is_king

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return

	var main_node = context.get("main")
	if main_node == null or not ("card_coin_flip_view" in main_node) or main_node.card_coin_flip_view == null:
		# Sem view de moeda disponível — resolve na sorte sem animação
		# (não deveria acontecer em jogo normal, só uma rede de segurança).
		if randi() % 2 == 0:
			piece.is_king = true
		else:
			board.grid[target_pos.y][target_pos.x] = Board.EMPTY
		return

	main_node.is_resolving_card_effect = true

	var coin_view: CoinFlipView = main_node.card_coin_flip_view

	var center = main_node.board_offset + Vector2(
		board.cols * main_node.cell_size / 2.0,
		board.rows * main_node.cell_size / 2.0
	)
	# Favorável = a moeda cair na cor da peça escolhida.
	coin_view.play_toss_for_team(center, main_node.cell_size, piece.owner_team, "VIROU DAMA!", "PECA PERDIDA!")
	var landed_promotion: bool = await coin_view.flip_completed

	if landed_promotion:
		piece.is_king = true
	else:
		board.grid[target_pos.y][target_pos.x] = Board.EMPTY

	main_node.is_resolving_card_effect = false
