class_name RuleLastChance
extends RuleCard

# Uma vez por duelo, a primeira Dama do jogador que seria PERDIDA gira uma
# moeda: na cor dele, ela é salva. Vale para toda perda "de verdade":
#  - captura em jogo (DuelTurnController, antes do make_move da IA);
#  - Guilhotina, Duelo de Sorte e Rebaixar (as cartas chamam try_save);
#  - o sapo do Chefe da Floresta (FrogBossAnimationView).
# A Dama salva volta a ser peça comum — a não ser que esteja na fileira de
# coroação: aí ela é coroada de novo e continua Dama.
# Só do jogador: não está em AI_ELIGIBLE_RULE_IDS (a IA nunca a recebe).
var used: bool = false

func _init() -> void:
	id = "last_chance"
	name = "Ultima Chance"
	description = "Uma vez por duelo, quando uma Dama sua for perdida (capturada, Guilhotina, Duelo de Sorte, devorada) ou rebaixada, gire a moeda: na cor das suas pecas ela e salva e volta a ser peca comum. Na fileira de coroacao ela e coroada de novo e continua Dama."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 6

func on_game_event(event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	if event_name == &"duel_started":
		used = false

# Peça que seria salva por um Escudo / Luto não gasta a moeda: o controlador
# pergunta antes de girar (ver DuelTurnController._ai_execute_move_chain).
static func capture_already_covered(board: Board, victim: BoardPiece) -> bool:
	if victim.shield_turns > 0:
		return true
	if board.rule_pipeline != null:
		var sh = board.rule_pipeline.get_rule("shield")
		if sh != null and sh.applies_to_team(victim.owner_team, board.human_team_color) and not sh.shield_used:
			return true
	return false

# Gira a moeda se a Lei estiver ativa e disponível. Devolve true se a Dama foi
# salva. `keep_king`: o perigo é o próprio Rebaixar (salva = continua Dama, sem
# virar peça comum). Se salva e não keep_king, já aplica o rebaixamento/coroação.
static func try_save(host, pos: Vector2i, piece: BoardPiece, keep_king: bool = false) -> bool:
	if host == null or piece == null or piece == Board.EMPTY or piece.is_tree or not piece.is_king:
		return false
	var board: Board = host.board
	if board == null or board.rule_pipeline == null or piece.owner_team != host.human_team:
		return false
	var rule = board.rule_pipeline.get_rule("last_chance")
	if rule == null or rule.used:
		return false
	rule.used = true

	var center: Vector2 = host.board_offset + Vector2(board.cols * host.cell_size / 2.0, board.rows * host.cell_size / 2.0)
	var saved: bool
	if host.card_coin_flip_view == null:
		saved = randi() % 2 == 0
	else:
		host.is_resolving_card_effect = true
		host.card_coin_flip_view.play_toss_for_team(center, host.cell_size, piece.owner_team, "DAMA SALVA!", "DAMA PERDIDA!")
		saved = await host.card_coin_flip_view.flip_completed
		host.is_resolving_card_effect = false
	if not saved:
		return false

	var tile_center: Vector2 = host.board_offset + Vector2(pos.x * host.cell_size + host.cell_size / 2.0, pos.y * host.cell_size + host.cell_size / 2.0)
	if host.rule_banner_view != null:
		host.rule_banner_view.pop_rule_trigger(tile_center, "ULTIMA CHANCE!", Color(1.0, 0.85, 0.3), "last_chance")
	if keep_king:
		return true

	var end_row: int = 0 if piece.owner_team == board.human_team_color else board.rows - 1
	if pos.y == end_row:
		# Na fileira de coroação: coroada de novo, continua Dama.
		piece.temp_king_turns = 0
		host.animating_coronation_tile = pos
		await host.king_animation_view.play_coronation(tile_center, host.cell_size, piece)
		host.animating_coronation_tile = Vector2i(-1, -1)
	else:
		piece.is_king = false
		piece.temp_king_turns = 0
	return true
