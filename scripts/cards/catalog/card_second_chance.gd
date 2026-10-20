class_name CardSecondChance
extends ActionCard

func _init() -> void:
	id = "second_chance"
	icon_path = "res://assets/sprites/cards/icons/second_chance.png"
	name = "Segunda Chance"
	description = "Gire a moeda: se cair na cor das suas peças, voce ganha um turno extra. Senão, quem ganha é o inimigo."
	rarity = Rarity.COMMON
	target_type = TargetType.NONE

func execute(board: Board, _target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("extra_turns_by_team" in main_node):
		return

	var opponent_team = Board.WHITE + Board.BLACK - human_team

	if not ("card_coin_flip_view" in main_node) or main_node.card_coin_flip_view == null:
		var instant_team = human_team if randi() % 2 == 0 else opponent_team
		main_node.extra_turns_by_team[instant_team] = main_node.extra_turns_by_team.get(instant_team, 0) + 1
		return

	main_node.is_resolving_card_effect = true

	var coin_view: CoinFlipView = main_node.card_coin_flip_view

	var center = main_node.board_offset + Vector2(
		board.cols * main_node.cell_size / 2.0,
		board.rows * main_node.cell_size / 2.0
	)
	# A moeda é peça branca x peça preta: favorável = cair na cor de quem jogou.
	coin_view.play_toss_for_team(center, main_node.cell_size, human_team, "TURNO EXTRA PRA VOCE!", "TURNO EXTRA PRO OPONENTE!")
	var acting_team_wins: bool = await coin_view.flip_completed

	var team_to_grant = human_team if acting_team_wins else opponent_team
	main_node.extra_turns_by_team[team_to_grant] = main_node.extra_turns_by_team.get(team_to_grant, 0) + 1

	main_node.is_resolving_card_effect = false
