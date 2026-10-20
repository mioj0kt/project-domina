class_name CardLoadedCoin
extends ActionCard

func _init() -> void:
	id = "loaded_coin"
	icon_path = "res://assets/sprites/cards/icons/loaded_coin.png"
	name = "Moeda Viciada"
	description = "A próxima moeda do duelo cai na cor das suas peças."
	rarity = Rarity.EPIC
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, _context: Dictionary = {}) -> bool:
	# Nao empilha: ja existe uma moeda viciada esperando.
	return CoinFlipView.rigged_team == 0

func execute(_board: Board, _target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	CoinFlipView.rigged_team = human_team
	_pop_banner(context, "MOEDA VICIADA!", Color(1.0, 0.85, 0.3))
