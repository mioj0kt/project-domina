class_name DuelTurnController
extends Node

# Fluxo de turno do duelo (coin flip, turno do jogador, turno da IA, fim de
# turno, vitória/derrota, morte súbita) + processamento de clique no tabuleiro,
# extraídos de main.gd — a parte mais entrelaçada do "god object" original.
#
# Segue o mesmo padrão das outras extrações (DebugRuleConsole, ActionCardController):
# o HOST (hoje, main.gd) continua sendo o dono de todo o estado (board, current_duel,
# current_turn, selected_tile, human_team, etc.) — este controller só implementa o
# COMPORTAMENTO, lendo/escrevendo esse estado via `host.<campo>`. Isso evita ter que
# tocar em BoardRenderer/ActionCardController/DebugRuleConsole, que já leem esse
# mesmo estado diretamente do host.
#
# Host precisa expor (tudo já existia em main.gd antes desta extração):
#   board, board_offset, cell_size, current_duel, human_team, ai_team,
#   current_turn, is_ai_thinking, is_starting_match, is_game_over, multi_jump_tile,
#   selected_tile, valid_moves_for_selected, moving_piece_tile, animating_coronation_tile,
#   piece_spawn_scales, extra_turns_by_team, show_enemy_threats, lost_piece_last_enemy_turn,
#   _ai_starting_cards,
#   coin_flip_view, king_animation_view, piece_movement_view, frog_animation_view,
#   sudden_death_mgr, rule_banner_view, game_over_modal, hud_bar,
#   action_cards, update_gold_display()

var _host: Node2D
var ai_deck_mgr: CardDeckManager

func setup(host: Node2D) -> void:
	_host = host

# ==========================================
# INÍCIO DE PARTIDA / COIN FLIP
# ==========================================

func start_match_flow() -> void:
	_host.is_starting_match = true
	_host.is_game_over = false
	_host.multi_jump_tile = Vector2i(-1, -1)
	_host.extra_turns_by_team = {}
	_host.predicted_ai_move = {}
	_host.show_enemy_threats = false
	_host.lost_piece_last_enemy_turn = false
	_host.action_cards.cancel_selection()
	_host.sudden_death_mgr.reset()
	_host.game_over_modal.visible = false
	_host.update_gold_display()
	_host.board.clear_bonus_moves()
	CoinFlipView.rigged_team = 0

	ai_deck_mgr = CardDeckManager.new()
	ai_deck_mgr.setup_duel(_host._ai_starting_cards)
	if _host.enemy_hand_ui != null:
		ai_deck_mgr.hand_updated.connect(func(): _host.enemy_hand_ui.refresh(ai_deck_mgr.hand))
		_host.enemy_hand_ui.refresh(ai_deck_mgr.hand)
	if _host.enemy_hud_bar != null:
		_host.enemy_hud_bar.setup_deck_manager(ai_deck_mgr)

	if _host.board.rule_pipeline != null:
		_host.board.rule_pipeline.emit_event(&"duel_started", {}, _host.board)

	var coin_center = _host.board_offset + Vector2((_host.board.cols * _host.cell_size) / 2.0, (_host.board.rows * _host.cell_size) / 2.0)
	_host.coin_flip_view.play_toss(coin_center, _host.cell_size)

func on_coin_flip_completed(player_won_white: bool) -> void:
	_host.human_team = Board.WHITE if player_won_white else Board.BLACK
	_host.ai_team = Board.BLACK if player_won_white else Board.WHITE

	_host.board.setup_match(_host.human_team, _host.ai_team)
	_apply_tutorial_position()

	_host.current_duel.setup(_host.board, _host.human_team, _host.ai_team, _host.sudden_death_mgr)
	_host.current_duel.apply_board_modifiers()

	# Leis que mexem no tabuleiro inicial (Guarda Real) e a Moeda Fiel —
	# só depois que as cores foram sorteadas e as peças posicionadas.
	if _host.board.rule_pipeline != null:
		_host.board.rule_pipeline.emit_event(&"board_ready", {}, _host.board)
		if _host.board.rule_pipeline.has_rule("faithful_coin"):
			CoinFlipView.rigged_team = _host.human_team

	# Damas que já existem no começo (Realeza, Guarda Real) nunca contam como
	# "Dama nova" — o relógio da Morte Súbita não pode nem piscar por causa delas.
	_host.sudden_death_mgr.snapshot_initial_kings(_host.board)

	if _host.current_duel is DuelBoss:
		var boss_duel = _host.current_duel as DuelBoss
		boss_duel.should_spawn_new_flies = false
		_host.frog_animation_view.spawn_new_flies(boss_duel.hazard_tiles)

	_host.piece_spawn_scales.clear()
	var spawn_tween = create_tween().set_parallel(true)
	var delay = 0.0

	for r in range(_host.board.rows):
		for c in range(_host.board.cols):
			var pos = Vector2i(c, r)
			if _host.board.grid[r][c] != Board.EMPTY:
				_host.piece_spawn_scales[pos] = 0.0
				spawn_tween.tween_method(func(v): _host.piece_spawn_scales[pos] = v, 0.0, 1.0, 0.35)\
					.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				delay += 0.02

	await spawn_tween.finished
	_host.is_tutorial_intro_playing = TutorialManager.is_active
	_host.is_starting_match = false

	_on_battle_started()

func _on_battle_started() -> void:
	if _host.boss_banter != null and is_instance_valid(_host.boss_banter):
		await _host.boss_banter.play_intro()
		_host.boss_banter.react("start", true)
	if RunManager.is_ambush_pending() and not TutorialManager.is_active:
		var ambush_center = _host.board_offset + Vector2(_host.board.cols * _host.cell_size / 2.0, _host.board.rows * _host.cell_size / 2.0)
		if RunManager.ambush_kind == "setup":
			_host.rule_banner_view.pop_rule_trigger(ambush_center, "VOCE ATACA DE SURPRESA!", Color(0.5, 0.9, 0.5))
		else:
			_host.rule_banner_view.pop_rule_trigger(ambush_center, "EMBOSCADA!", Color(0.95, 0.35, 0.3))
		await get_tree().create_timer(1.2).timeout
	await _maybe_show_tutorial_duel_intro()
	_host.is_tutorial_intro_playing = false
	_host.current_turn = Board.WHITE
	if _host.ai_team == Board.WHITE:
		play_ai_turn()

# Mostra a fala de introdução deste duelo (se o tutorial estiver ativo e
# esse passo tiver uma) ANTES do primeiro turno começar — assim o jogo já
# "abre" com o Guia falando, em vez de uma conversa solta no mapa antes
# de trocar de cena.
func _maybe_show_tutorial_duel_intro() -> void:
	if not TutorialManager.is_active or _host.tutorial_guide_view == null:
		return
	var guide = _host.tutorial_guide_view
	var lines: Array = []
	match TutorialManager.current_step:
		TutorialManager.Step.DUEL_1_BASICS:
			lines = TutorialManager.get_duel1_intro_lines()
		TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			lines = TutorialManager.get_duel3_intro_lines()
	if lines.is_empty():
		return
	await guide.play_title_card(
		"LIÇÃO %d de %d" % [TutorialManager.get_lesson_number(TutorialManager.current_step), TutorialManager.LESSON_COUNT],
		TutorialManager.get_lesson_title(TutorialManager.current_step),
		TutorialManager.get_lesson_goal(TutorialManager.current_step))
	await guide.play_sequence(lines)
	# Depois da introdução, o Guia passa os objetivos do duelo (aprender fazendo).
	TutorialManager.begin_objectives()

# Tutorial (Duelo 1): troca as peças iniciais pela posição didática — uma
# captura obrigatória logo de cara e uma peça perto da coroação.
func _apply_tutorial_position() -> void:
	if not TutorialManager.is_active or TutorialManager.current_step != TutorialManager.Step.DUEL_1_BASICS:
		return
	var board = _host.board
	board.clear_board()
	for p in TutorialManager.get_duel1_human_pieces():
		board.grid[p.y][p.x] = BoardPiece.new(_host.human_team, false)
	for p in TutorialManager.get_duel1_enemy_pieces():
		board.grid[p.y][p.x] = BoardPiece.new(_host.ai_team, false)

# Tutorial: reseta o tabuleiro pro estado inicial (mesmos times, sem
# sortear de novo) e força a Morte Súbita na hora, em vez de terminar o
# duelo normalmente — usado pelo Guia pra demonstrar a mecânica sem
# precisar de um nó de mapa separado.
func tutorial_force_sudden_death() -> void:
	var host = _host

	if host.tutorial_guide_view != null:
		await host.tutorial_guide_view.play_sequence(TutorialManager.get_sudden_death_forced_lines())

	host.is_starting_match = true
	host.selected_tile = Vector2i(-1, -1)
	host.valid_moves_for_selected = []
	host.action_cards.cancel_selection()

	host.board.setup_match(host.human_team, host.ai_team)
	_apply_tutorial_position()
	host.current_duel.setup(host.board, host.human_team, host.ai_team, host.sudden_death_mgr)
	host.current_duel.apply_board_modifiers()

	host.piece_spawn_scales.clear()
	var spawn_tween = create_tween().set_parallel(true)
	var delay = 0.0
	for r in range(host.board.rows):
		for c in range(host.board.cols):
			var pos = Vector2i(c, r)
			if host.board.grid[r][c] != Board.EMPTY:
				host.piece_spawn_scales[pos] = 0.0
				spawn_tween.tween_method(func(v): host.piece_spawn_scales[pos] = v, 0.0, 1.0, 0.35)\
					.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				delay += 0.02
	await spawn_tween.finished
	host.is_starting_match = false

	host.sudden_death_mgr.reset()
	host.sudden_death_mgr.start_immediately()

	host.current_turn = Board.WHITE
	if host.ai_team == Board.WHITE:
		play_ai_turn()

# ==========================================
# CLIQUE NO TABULEIRO
# ==========================================

func handle_cell_click(pos: Vector2i) -> void:
	var host = _host
	var board = host.board

	# 1. Se uma Carta de Ação estiver aguardando um alvo no tabuleiro
	if host.action_cards.try_play_at_target(pos):
		return

	# 2. Execução de Movimento de Peça Comum ou Captura
	for m in host.valid_moves_for_selected:
		if m["to"] == pos:
			var from_pos: Vector2i = m["from"]
			var moving_piece: BoardPiece = board.grid[from_pos.y][from_pos.x]
			var was_capture: bool = m["is_capture"]
			host.extra_skip_kind = ""   # jogou: a jogada de bônus (se havia) foi usada

			host.moving_piece_tile = from_pos
			host.selected_tile = Vector2i(-1, -1)
			host.valid_moves_for_selected = []

			var from_center = host.board_offset + Vector2(from_pos.x * host.cell_size + host.cell_size / 2.0, from_pos.y * host.cell_size + host.cell_size / 2.0)
			var to_center = host.board_offset + Vector2(pos.x * host.cell_size + host.cell_size / 2.0, pos.y * host.cell_size + host.cell_size / 2.0)

			await host.piece_movement_view.play_move_jump(from_center, to_center, moving_piece, host.cell_size, was_capture)
			host.moving_piece_tile = Vector2i(-1, -1)

			_show_rule_move_banner(moving_piece, from_pos, pos, was_capture, to_center)

			var captured_p: BoardPiece = null
			if was_capture:
				var cap_pos = m["captured"]
				captured_p = board.grid[cap_pos.y][cap_pos.x]

			# make_move() vem ANTES dos pulos de mosca de propósito: assim a
			# grade do tabuleiro já reflete a posição nova enquanto os pulos
			# tocam, evitando que a peça "pisque" de volta pra posição
			# antiga (moving_piece_tile já foi resetado acima, então o
			# desenho normal do tabuleiro volta a mostrá-la — precisa que a
			# grade já esteja atualizada nesse momento).
			var promoted = board.make_move(m)

			# Só conta pro ouro do duelo se a peça realmente morreu (o Escudo
			# pode ter impedido a captura).
			if was_capture and not board.last_capture_prevented and not captured_p.is_tree:
				host.current_duel.on_piece_captured(captured_p)
				TutorialManager.report_event("capture")

			if host.current_duel is DuelBoss and (host.current_duel as DuelBoss).law_id == DuelBoss.LAW_FROG:
				await host.frog_animation_view.hop_fly_at(m["from"])
				await host.frog_animation_view.hop_fly_at(m["to"])

			host.current_duel.on_turn_end(board)

			if was_capture and host.hud_bar != null:
				host.hud_bar.update_gold()

			if promoted:
				host.boss_say("promote_player")
				var promo_piece: BoardPiece = board.grid[pos.y][pos.x]
				if promo_piece != Board.EMPTY:
					var center = host.board_offset + Vector2(pos.x * host.cell_size + host.cell_size / 2.0, pos.y * host.cell_size + host.cell_size / 2.0)
					var board_center = host.board_offset + Vector2(board.cols * host.cell_size / 2.0, board.rows * host.cell_size / 2.0)
					var should_promote = await _maybe_resolve_ascension_law(host, promo_piece, board_center)
					if should_promote:
						_show_rule_promotion_banner(pos, center)
						host.animating_coronation_tile = pos
						await host.king_animation_view.play_coronation(center, host.cell_size, promo_piece)
						host.animating_coronation_tile = Vector2i(-1, -1)
						await host.tutorial_maybe_show_tip("first_promotion")
						TutorialManager.report_event("promotion")

			# Multissalto em cadeia — só CAPTURAS DE VERDADE continuam a
			# cadeia obrigatoriamente; um salto camarada que sobrar na
			# lista não conta (ele não é uma captura de verdade).
			if was_capture and not promoted:
				var follow_up_all = board.get_piece_captures(pos.y, pos.x)
				var follow_up_captures = follow_up_all.filter(func(mv): return mv.get("is_capture", false) and not mv.get("optional", false))
				if not follow_up_captures.is_empty():
					host.multi_jump_tile = pos
					host.selected_tile = pos
					host.valid_moves_for_selected = follow_up_captures
					host.rule_banner_view.pop_rule_trigger(to_center, "+COMBO!", Color(1.0, 0.4, 0.2))
					return

			host.multi_jump_tile = Vector2i(-1, -1)

			# Regra de Segundo Movimento (ou qualquer futura regra que conceda passo extra)
			var used_extra_step = false
			var extra_step_rule_id: String = ""
			if not was_capture and board.rule_pipeline != null:
				for r in board.rule_pipeline.active_rules:
					if r.try_consume_extra_step():
						used_extra_step = true
						extra_step_rule_id = r.id
						break

			# Dama Voadora: a mesma Dama faz uma 2ª jogada neste turno.
			var fly_piece: BoardPiece = board.extra_move_piece
			board.extra_move_piece = null
			if not used_extra_step and fly_piece != null and fly_piece == moving_piece and fly_piece.is_king and board.grid[pos.y][pos.x] == fly_piece:
				var second_moves = board.get_all_valid_moves(host.human_team).filter(func(mv): return mv["from"] == pos)
				if not second_moves.is_empty():
					host.multi_jump_tile = pos
					host.selected_tile = pos
					host.valid_moves_for_selected = second_moves
					host.rule_banner_view.pop_rule_trigger(to_center, "MOVA DE NOVO!", Color(0.5, 0.85, 1.0))
					host.extra_skip_kind = "fly"
					return

			if used_extra_step:
				host.rule_banner_view.pop_rule_trigger(to_center, "PASSO EXTRA!", Color(0.4, 0.9, 0.5), extra_step_rule_id)
				host.extra_skip_kind = "step"
				# Sem essa checagem, se o jogador não tiver NENHUM movimento
				# disponível pro passo extra, o jogo ficaria esperando pra
				# sempre um clique que nunca poderia acontecer (softlock).
				if await check_game_over():
					return
				return

			await _process_boss_turn_events()
			await end_turn()
			return

	if host.multi_jump_tile != Vector2i(-1, -1):
		return

	# 3. Seleção de Peça no Tabuleiro
	var piece: BoardPiece = board.grid[pos.y][pos.x]
	if piece != Board.EMPTY and piece.owner_team == host.human_team:
		host.selected_tile = pos
		host.valid_moves_for_selected = board.get_all_valid_moves(host.human_team).filter(func(m): return m["from"] == pos)
		if not host.valid_moves_for_selected.is_empty():
			TutorialManager.report_event("piece_selected")

# Pergunta a cada RuleCard ativa se ela quer exibir um banner de trigger para
# este movimento simples. A regra decide sozinha (get_move_trigger_banner).
func _show_rule_move_banner(piece: BoardPiece, from_pos: Vector2i, to_pos: Vector2i, was_capture: bool, screen_pos: Vector2) -> void:
	if _host.board.rule_pipeline == null:
		return
	# TODAS as Leis que agiram neste movimento acendem (antes só a primeira da
	# lista: com Movimento Reverso junto, o Salto Camarada nunca brilhava).
	# Os banners empilham para cima, um acima do outro.
	var shown: int = 0
	for r in _host.board.rule_pipeline.active_rules:
		var banner = r.get_move_trigger_banner(piece, from_pos, to_pos, was_capture)
		if not banner.is_empty():
			_host.rule_banner_view.pop_rule_trigger(screen_pos - Vector2(0.0, 34.0 * shown), banner["text"], banner["color"], r.id)
			shown += 1

# Mesma ideia, para o momento de promoção a Dama.
func _show_rule_promotion_banner(to_pos: Vector2i, screen_pos: Vector2) -> void:
	if _host.board.rule_pipeline == null:
		return
	for r in _host.board.rule_pipeline.active_rules:
		var banner = r.get_promotion_trigger_banner(to_pos)
		if not banner.is_empty():
			_host.rule_banner_view.pop_rule_trigger(screen_pos, banner["text"], banner["color"], r.id)
			return

# Lei da Ascensão: só mira peças INIMIGAS (owner_team diferente do
# human_team_color do tabuleiro) — se a lei estiver ativa e a peça
# promovida for do inimigo, vira uma moeda antes de confirmar a
# promoção. Devolve true se a promoção deve seguir em frente (moeda não
# aplicável, ou a moeda caiu na cor da peça), false se deve ser cancelada (caiu a outra cor —
# a função já reverte piece.is_king nesse caso).
func _maybe_resolve_ascension_law(host: Node2D, piece: BoardPiece, center: Vector2) -> bool:
	var board = host.board
	if board.rule_pipeline == null:
		return true

	var ascension_rule: RuleCard = null
	for r in board.rule_pipeline.active_rules:
		if r.id == "ascension_law":
			ascension_rule = r
			break
	if ascension_rule == null or host.card_coin_flip_view == null:
		return true

	# Invertido de propósito — ver comentário em rule_ascension.gd. Essa
	# Lei é contra quem NÃO a possui, então "aplica" exatamente quando
	# applies_to_team() diz que a peça NÃO é do dono da Lei.
	if ascension_rule.applies_to_team(piece.owner_team, board.human_team_color):
		return true

	host.is_resolving_card_effect = true
	board.rule_fired.emit("ascension_law")

	var coin_view: CoinFlipView = host.card_coin_flip_view
	# Favorável = a moeda cair na cor da peça que está sendo promovida.
	coin_view.play_toss_for_team(center, host.cell_size, piece.owner_team, "PROMOCAO CONFIRMADA!", "PROMOCAO NEGADA!")
	var confirmed: bool = await coin_view.flip_completed

	host.is_resolving_card_effect = false

	if not confirmed:
		piece.is_king = false

	return confirmed

# ==========================================
# TURNO DA IA / FIM DE TURNO
# ==========================================

func play_ai_turn() -> void:
	var host = _host
	if host.is_game_over:
		return

	host.predicted_ai_move = {}

	if host.frog_animation_view and (host.frog_animation_view.is_attacking or host.frog_animation_view.is_spawning_flies):
		await get_tree().create_timer(0.2).timeout
		if host.frog_animation_view.is_attacking:
			await host.frog_animation_view.attack_sequence_finished
		if host.frog_animation_view.is_spawning_flies:
			await host.frog_animation_view.flies_spawn_finished

	host.is_ai_thinking = true
	host.lost_piece_last_enemy_turn = false
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame

	if ai_deck_mgr != null:
		ai_deck_mgr.on_turn_started()
		await _maybe_play_ai_card()
		# Carta da IA que eliminou o último do jogador (ou o dela): fim de duelo já.
		if await check_elimination():
			host.is_ai_thinking = false
			return

	var board = host.board
	var search_depth = 3 if max(board.rows, board.cols) >= 10 else 4
	var ai_move = CheckersAI.get_best_move(board, search_depth, host.ai_team)
	host.current_duel.note_ai_turn(not ai_move.is_empty())

	var last_pos: Vector2i = await _ai_execute_move_chain(ai_move)

	# Lei do Contra-Ataque: peças perdidas viram movimentos extras com OUTRA peça.
	var counter_rule = null
	if board.rule_pipeline != null:
		counter_rule = board.rule_pipeline.get_rule("counter_attack")
	if counter_rule != null and last_pos.x >= 0 and not host.is_game_over:
		var extras: int = counter_rule.consume_charges()
		for i in range(extras):
			var extra_move = CheckersAI.get_best_move(board, search_depth, host.ai_team, last_pos)
			if extra_move.is_empty():
				break
			host.rule_banner_view.pop_rule_trigger(
				host.board_offset + Vector2(board.cols * host.cell_size / 2.0, board.rows * host.cell_size / 2.0),
				"CONTRA-ATAQUE!", Color(0.95, 0.35, 0.3), "counter_attack")
			await get_tree().create_timer(0.45).timeout
			last_pos = await _ai_execute_move_chain(extra_move)

	await _process_boss_turn_events()
	host.is_ai_thinking = false

	await _conclude_turn(host.ai_team)

# Executa UM movimento da IA (com a cadeia de capturas obrigatórias que se
# seguir) e devolve a casa onde a peça terminou — (-1,-1) se não havia movimento.
func _ai_execute_move_chain(ai_move: Dictionary) -> Vector2i:
	var host = _host
	var final_pos := Vector2i(-1, -1)
	var board = host.board
	while ai_move.size() > 0:
		var from_pos = ai_move["from"]
		var target_pos = ai_move["to"]
		final_pos = target_pos
		var moving_piece: BoardPiece = board.grid[from_pos.y][from_pos.x]
		var was_capture: bool = ai_move.get("is_capture", false)
		var cap_was_tree: bool = false
		if was_capture:
			var cp: Vector2i = ai_move["captured"]
			cap_was_tree = board.grid[cp.y][cp.x] != Board.EMPTY and board.grid[cp.y][cp.x].is_tree

		host.moving_piece_tile = from_pos

		var from_center = host.board_offset + Vector2(from_pos.x * host.cell_size + host.cell_size / 2.0, from_pos.y * host.cell_size + host.cell_size / 2.0)
		var to_center = host.board_offset + Vector2(target_pos.x * host.cell_size + host.cell_size / 2.0, target_pos.y * host.cell_size + host.cell_size / 2.0)

		await host.piece_movement_view.play_move_jump(from_center, to_center, moving_piece, host.cell_size, was_capture)
		host.moving_piece_tile = Vector2i(-1, -1)

		# Última Chance: se a vítima é uma Dama do jogador, a moeda gira ANTES do
		# golpe; salva = a captura falha (como no Escudo) e a Dama é rebaixada/coroada.
		if was_capture:
			var vp: Vector2i = ai_move["captured"]
			var victim: BoardPiece = board.grid[vp.y][vp.x]
			if victim != Board.EMPTY and victim.is_king and not victim.is_tree and not RuleLastChance.capture_already_covered(board, victim):
				if await RuleLastChance.try_save(host, vp, victim):
					board.last_chance_piece = victim

		var promoted = board.make_move(ai_move)
		board.last_chance_piece = null

		# Capturas da IA não rendem ouro (DuelBase.on_piece_captured é só do
		# jogador); só marcam que o jogador perdeu uma peça (Retaliação) — e
		# só se ela realmente morreu, não se o Escudo a salvou.
		if was_capture and not board.last_capture_prevented and not cap_was_tree:
			host.lost_piece_last_enemy_turn = true

		if host.current_duel is DuelBoss and (host.current_duel as DuelBoss).law_id == DuelBoss.LAW_FROG:
			await host.frog_animation_view.hop_fly_at(ai_move["from"])
			await host.frog_animation_view.hop_fly_at(ai_move["to"])

		host.current_duel.on_turn_end(board)

		if promoted:
			host.boss_say("promote_boss")
			var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
			if piece != Board.EMPTY:
				var center = host.board_offset + Vector2(target_pos.x * host.cell_size + host.cell_size / 2.0, target_pos.y * host.cell_size + host.cell_size / 2.0)
				var board_center = host.board_offset + Vector2(board.cols * host.cell_size / 2.0, board.rows * host.cell_size / 2.0)
				var should_promote = await _maybe_resolve_ascension_law(host, piece, board_center)
				if should_promote:
					host.animating_coronation_tile = target_pos
					await host.king_animation_view.play_coronation(center, host.cell_size, piece)
					host.animating_coronation_tile = Vector2i(-1, -1)

		if was_capture and not promoted:
			var follow_ups_all = board.get_piece_captures(target_pos.y, target_pos.x)
			var follow_ups = follow_ups_all.filter(func(m): return m.get("is_capture", false) and not m.get("optional", false))
			if not follow_ups.is_empty():
				await get_tree().create_timer(0.25).timeout
				ai_move = follow_ups[0]
				continue

		break
	return final_pos

# ==========================================
# CARTAS DE AÇÃO DA IA (heurística simples — não integrada ao minimax)
# ==========================================
# A IA não "pensa fundo" sobre cartas: no máximo 1 por turno, escolhida por
# uma regra de bolso simples pra cada tipo (ver _find_ai_card_target). Isso
# é intencional — ver a conversa sobre o custo de integrar cartas na busca
# do CheckersAI de verdade.

func _maybe_play_ai_card() -> void:
	var host = _host
	if ai_deck_mgr == null or ai_deck_mgr.hand.is_empty():
		return

	var board = host.board
	var context = {"main": host, "deck_mgr": ai_deck_mgr}

	for i in range(ai_deck_mgr.hand.size()):
		var card: ActionCard = ai_deck_mgr.hand[i]
		if not card.can_play(board, host.ai_team, context):
			continue

		var target = _find_ai_card_target(card, board, host)
		if target == null:
			continue

		# Primeiro a carta aparece/é lançada, SÓ DEPOIS o efeito resolve (assim
		# cara ou coroa, animações etc. acontecem depois de mostrar a carta).
		ai_deck_mgr.play_card_at(i)
		if host.ai_card_reveal_view != null:
			var from_pos = Vector2(get_viewport().get_visible_rect().size.x / 2.0, 75.0)
			var to_pos = from_pos
			if host.enemy_hud_bar != null:
				to_pos = host.enemy_hud_bar.get_discard_pile_global_position()
			host.ai_card_reveal_view.show_card(card, from_pos, to_pos)
			# Espera o sinal de conclusão (não um tempo fixo) — clicar pra
			# pular a animação também libera o turno na hora, em vez de só
			# acelerar visualmente enquanto o código continua esperando o
			# tempo cheio por baixo dos panos.
			await host.ai_card_reveal_view.sequence_finished
		@warning_ignore("redundant_await")
		await card.execute(board, target, host.ai_team, context)
		return

# Devolve a posição-alvo (Vector2i) escolhida pra essa carta, ou null se a
# IA não encontrar um alvo que valha a pena agora.
func _find_ai_card_target(card: ActionCard, board: Board, host: Node2D) -> Variant:
	match card.id:
		"fortify":
			return _ai_find_fortify_target(board, host)
		"grand_reinforcement":
			return _ai_find_empty_row_target(board, host.ai_team)
		"corrupt":
			return _ai_find_isolated_enemy_target(board, host.ai_team)
		"recruit", "rebuild":
			return _ai_find_deployment_target(card, board, host.ai_team)
		"extra_turn":
			@warning_ignore("incompatible_ternary")
			return Vector2i.ZERO if _ai_should_play_extra_turn(board, host) else null
		"retreat":
			return _ai_find_retreat_target(board, host)
		"heroic_advance":
			return _ai_find_heroic_advance_target(board, host.ai_team)
		"coin_of_destiny":
			return _ai_find_any_own_common_piece(board, host.ai_team)
		"lucky_duel":
			return _ai_find_isolated_enemy_target(board, host.ai_team)
		"second_chance":
			return Vector2i.ZERO
		"rebellion":
			return _ai_find_isolated_enemy_target(board, host.ai_team)
		"demote", "guillotine":
			return _ai_find_enemy_king_target(card, board, host)
		"heir":
			return _ai_find_any_own_common_piece(board, host.ai_team)
		"ambush":
			return _ai_find_ambush_target(card, board, host)
	return null

# Rebaixar/Guilhotina: uma Dama inimiga (do jogador), qualquer uma.
func _ai_find_enemy_king_target(card: ActionCard, board: Board, host: Node2D) -> Variant:
	for r in range(board.rows):
		for c in range(board.cols):
			if card.is_valid_target(board, Vector2i(c, r), host.ai_team, {}):
				return Vector2i(c, r)
	return null

# Emboscada: imobiliza uma peça do jogador que teria uma captura agora.
func _ai_find_ambush_target(card: ActionCard, board: Board, host: Node2D) -> Variant:
	for m in board.get_all_valid_moves(host.human_team):
		if m.get("is_capture", false) and card.is_valid_target(board, m["from"], host.ai_team, {}):
			return m["from"]
	return null

# Fortificar: bloqueia uma casa que o jogador poderia usar no próximo turno.
func _ai_find_fortify_target(board: Board, host: Node2D) -> Variant:
	var human_moves = board.get_all_valid_moves(host.human_team)
	for m in human_moves:
		var pos: Vector2i = m["to"]
		if board.grid[pos.y][pos.x] == Board.EMPTY and (pos.y + pos.x) % 2 == 1 and not board.scorched_tiles.has(pos):
			return pos
	return null

# Grande Reforço: joga se alguma fileira da IA estiver totalmente vazia dela.
func _ai_find_empty_row_target(board: Board, _ai_team: int) -> Variant:
	# A IA sempre joga do lado oposto ao human_team_color, então as
	# fileiras de trás dela são sempre as primeiras (0 até
	# BACK_ROWS-1) — mesma restrição que a própria carta já aplica em
	# is_valid_target (valor direto aqui, não referenciado da classe da
	# carta, pra não depender de uma referência entre arquivos frágil).
	const BACK_ROWS = 3
	for row in range(BACK_ROWS):
		# Mesma regra da carta: a fileira precisa estar TOTALMENTE vazia.
		var empty_of_team = true
		for c in range(board.cols):
			if board.grid[row][c] != Board.EMPTY:
				empty_of_team = false
				break
		if empty_of_team:
			for c in range(board.cols):
				if (row + c) % 2 == 1 and board.grid[row][c] == Board.EMPTY and not board.scorched_tiles.has(Vector2i(c, row)):
					return Vector2i(c, row)
	return null

# Corromper: procura uma peça comum inimiga (do jogador) isolada.
func _ai_find_isolated_enemy_target(board: Board, ai_team: int) -> Variant:
	var dirs = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team != ai_team and not p.is_king and not p.is_tree:
				var isolated = true
				for d in dirs:
					var nr = r + d.y
					var nc = c + d.x
					if board.is_valid_pos(nr, nc):
						var np: BoardPiece = board.grid[nr][nc]
						if np != Board.EMPTY and np.owner_team == p.owner_team:
							isolated = false
							break
				if isolated:
					return Vector2i(c, r)
	return null

# Moeda do Destino: qualquer peça comum própria serve — prioriza uma peça
# já avançada (mais perto da promoção), já que arriscar uma peça atrasada
# desperdiça o potencial ganho de virar Dama.
func _ai_find_any_own_common_piece(board: Board, ai_team: int) -> Variant:
	var best_pos: Variant = null
	var best_progress = -1
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == ai_team and not p.is_king:
				var progress = (board.rows - 1 - r) if ai_team == board.human_team_color else r
				if progress > best_progress:
					best_progress = progress
					best_pos = Vector2i(c, r)
	return best_pos

# Recrutamento/Reconstrução: usa a própria validação da carta (já simétrica
# por time) pra achar uma casa de implantação válida.
func _ai_find_deployment_target(card: ActionCard, board: Board, ai_team: int) -> Variant:
	var rows_to_check = [0] if card.id == "rebuild" else [0, 1]
	for row in rows_to_check:
		for c in range(board.cols):
			var pos = Vector2i(c, row)
			if card.is_valid_target(board, pos, ai_team, {}):
				return pos
	return null

# Segundo Turno: só vale a pena se a IA já tem uma captura disponível agora.
func _ai_should_play_extra_turn(board: Board, host: Node2D) -> bool:
	for m in board.get_all_valid_moves(host.ai_team):
		if m.get("is_capture", false):
			return true
	return false

# Recuar: salva uma peça comum da IA que o jogador poderia capturar agora.
func _ai_find_retreat_target(board: Board, host: Node2D) -> Variant:
	for m in board.get_all_valid_moves(host.human_team):
		if m.get("is_capture", false):
			var cap_pos: Vector2i = m["captured"]
			var p: BoardPiece = board.grid[cap_pos.y][cap_pos.x]
			if p != Board.EMPTY and p.owner_team == host.ai_team and not p.is_king:
				return cap_pos
	return null

# Investida Heroica: qualquer peça comum da IA serve como alvo simples.
func _ai_find_heroic_advance_target(board: Board, ai_team: int) -> Variant:
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == ai_team and not p.is_king:
				return Vector2i(c, r)
	return null

func _process_boss_turn_events() -> void:
	var host = _host
	if not (host.current_duel is DuelBoss):
		return

	var boss_duel = host.current_duel as DuelBoss
	await _process_boss_law_events(boss_duel)
	if boss_duel.should_trigger_devour:
		boss_duel.should_trigger_devour = false
		# Pequena pausa antes do ataque — sem ela, a língua disparava
		# imediatamente colada no movimento anterior, sem nenhum respiro
		# pro jogador perceber o que está acontecendo.
		await get_tree().create_timer(0.4).timeout
		await host.frog_animation_view.play_tongue_attack(host.board, boss_duel.pending_devour_tiles)

		if boss_duel.should_spawn_new_flies:
			boss_duel.should_spawn_new_flies = false
			boss_duel.roll_next_hazard_tiles()
			await host.frog_animation_view.spawn_new_flies(boss_duel.hazard_tiles)
	elif boss_duel.should_spawn_new_flies:
		boss_duel.should_spawn_new_flies = false
		boss_duel.roll_next_hazard_tiles()
		await host.frog_animation_view.spawn_new_flies(boss_duel.hazard_tiles)

# Eventos das Leis do chefe que não são do Sapo (Noite da Coruja / Floresta
# Fecha): a lógica vive em DuelBoss.advance_turn(); aqui só se mostra.
func _process_boss_law_events(boss_duel: DuelBoss) -> void:
	var host = _host
	var center = host.board_offset + Vector2(host.board.cols * host.cell_size / 2.0, host.board.rows * host.cell_size / 2.0)
	for ev in boss_duel.advance_turn():
		if ev["type"] != "fireflies":
			host.boss_say("law_" + str(ev["type"]))
		match ev["type"]:
			"night":
				host.rule_banner_view.pop_rule_trigger(center, "A NOITE CAI!", Color(0.65, 0.55, 1.0), "owl_night")
				await get_tree().create_timer(0.7).timeout
			"dawn":
				host.rule_banner_view.pop_rule_trigger(center, "AMANHECE!", Color(1.0, 0.85, 0.35), "owl_night")
				await get_tree().create_timer(0.7).timeout
			"vines":
				host.rule_banner_view.pop_rule_trigger(center, "OS CIPÓS SE MOVEM!", Color(0.45, 0.9, 0.4), "vines")
				await get_tree().create_timer(0.5).timeout
			"fireflies":
				# Sem banner (acontece toda rodada): o renderer desliza as luzes.
				host.board.rule_fired.emit("fireflies")
			"sun":
				host.rule_banner_view.pop_rule_trigger(center, "O SOL ESCALDA!", Color(1.0, 0.6, 0.2), "scorching_sun")
				await get_tree().create_timer(0.7).timeout
			"storm":
				host.rule_banner_view.pop_rule_trigger(center, "TEMPESTADE DE AREIA!", Color(0.9, 0.75, 0.45), "sandstorm")
				await get_tree().create_timer(0.7).timeout
			"quicksand":
				host.rule_banner_view.pop_rule_trigger(center, "A AREIA SE MOVE!", Color(0.85, 0.65, 0.35), "quicksand")
				await get_tree().create_timer(0.5).timeout
			"hourglass":
				host.rule_banner_view.pop_rule_trigger(center, "A AREIA FECHA!", Color(0.9, 0.75, 0.45), "hourglass")
				await get_tree().create_timer(0.7).timeout
			"cactus":
				host.rule_banner_view.pop_rule_trigger(center, "UM CACTO BROTA!", Color(0.5, 0.85, 0.4), "cacti")
				var tw3 = create_tween().set_parallel(true)
				for pos in ev["tiles"]:
					host.piece_spawn_scales[pos] = 0.0
					tw3.tween_method(func(v): host.piece_spawn_scales[pos] = v, 0.0, 1.0, 0.45)\
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				await tw3.finished
			"sarcophagus", "mummy":
				var is_mummy: bool = ev["type"] == "mummy"
				host.rule_banner_view.pop_rule_trigger(center, "A MÚMIA DESPERTA!" if is_mummy else "UM SARCÓFAGO SURGE!", Color(0.8, 0.7, 0.4), "sarcophagi")
				var tw2 = create_tween().set_parallel(true)
				for pos in ev["tiles"]:
					host.piece_spawn_scales[pos] = 0.0
					tw2.tween_method(func(v): host.piece_spawn_scales[pos] = v, 0.0, 1.0, 0.45)\
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				await tw2.finished
			"trees":
				host.rule_banner_view.pop_rule_trigger(center, "A FLORESTA SE FECHA!", Color(0.45, 0.9, 0.4), "closing_forest")
				var tw = create_tween().set_parallel(true)
				for pos in ev["tiles"]:
					host.piece_spawn_scales[pos] = 0.0
					tw.tween_method(func(v): host.piece_spawn_scales[pos] = v, 0.0, 1.0, 0.45)\
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				await tw.finished

func end_turn() -> void:
	await _conclude_turn(_host.human_team)

# Botão "IGNORAR ... EXTRA": o jogador abre mão do passo extra, da 2ª jogada da
# Dama Voadora ou do turno extra e passa a vez. O turno (e os eventos do chefe)
# contam normalmente, como se ele tivesse jogado. Se sobrar outro turno extra
# acumulado, _conclude_turn o concede em seguida.
func skip_extra() -> void:
	var host = _host
	if host.extra_skip_kind == "" or host.is_game_over or host.is_ai_thinking \
			or host.current_turn != host.human_team or host.is_resolving_card_effect:
		return
	var kind: String = host.extra_skip_kind
	host.extra_skip_kind = ""
	host.multi_jump_tile = Vector2i(-1, -1)
	host.selected_tile = Vector2i(-1, -1)
	host.valid_moves_for_selected = []
	host.action_cards.cancel_selection()
	await _process_boss_turn_events()
	if kind == "turn":
		await _conclude_turn(host.human_team)
	else:
		await end_turn()

# Ponto único de conclusão de turno — usado tanto depois do jogador mover
# (end_turn) quanto depois da IA mover (fim de play_ai_turn). Generalizado
# por time: "Segundo Turno" agora funciona pra quem quer que tenha jogado a
# carta, jogador ou IA, em vez de só existir pro caminho do jogador.
func _conclude_turn(team_that_moved: int) -> void:
	var host = _host
	host.board.extra_move_piece = null
	host.extra_skip_kind = ""

	# Efeitos temporários das peças de quem acabou de jogar (Emboscada, Herdeiro).
	for ev in host.board.tick_piece_effects(team_that_moved):
		if ev["type"] == "heir_expired" and host.rule_banner_view != null:
			var hp: Vector2i = ev["pos"]
			host.rule_banner_view.pop_rule_trigger(
				host.board_offset + Vector2(hp.x * host.cell_size + host.cell_size / 2.0, hp.y * host.cell_size + host.cell_size / 2.0),
				"COROA PERDIDA", Color(0.8, 0.7, 0.9))

	# Raízes Famintas (lei de chefe): quem capturou fica enraizado no próximo turno.
	var root_spots: Array = host.board.apply_hungry_roots(team_that_moved)
	if not root_spots.is_empty() and host.rule_banner_view != null:
		var rp: Vector2i = root_spots[0]
		host.rule_banner_view.pop_rule_trigger(
			host.board_offset + Vector2(rp.x * host.cell_size + host.cell_size / 2.0, rp.y * host.cell_size + host.cell_size / 2.0),
			"ENRAIZADA!", Color(0.45, 0.85, 0.35), "hungry_roots")

	await _process_card_hazards()

	if await check_game_over():
		return

	var extra = host.extra_turns_by_team.get(team_that_moved, 0)
	if extra > 0:
		host.extra_turns_by_team[team_that_moved] = extra - 1
		host.rule_banner_view.pop_rule_trigger(
			host.board_offset + Vector2(host.board.cols * host.cell_size / 2.0, host.board.rows * host.cell_size / 2.0),
			"TURNO EXTRA!",
			Color(1.0, 0.85, 0.2)
		)
		if team_that_moved == host.human_team:
			host.action_cards.on_turn_started()
			host.extra_skip_kind = "turn"
		else:
			play_ai_turn()
		return

	if team_that_moved == host.human_team:
		host.current_turn = host.ai_team
		play_ai_turn()
	else:
		host.current_turn = host.human_team
		host.action_cards.on_turn_started()
		host.show_enemy_threats = false
		host.board.tick_scorched_tiles()
		if host.board.rule_pipeline != null:
			host.board.rule_pipeline.emit_event(&"turn_started", {}, host.board)

# Efeitos de CARTAS que atuam depois das jogadas: múmias de sarcófagos de carta
# nascendo e a língua da Isca do Sapo. Chamado a cada fim de jogada, antes de
# checar o fim do duelo (a língua pode devorar a última peça de alguém).
func _process_card_hazards() -> void:
	var host = _host
	var board: Board = host.board

	# 1) Múmias dos sarcófagos de carta: nascem para quem jogou a carta.
	var born: Array = []
	for pos in board.released_mummies.duplicate():
		if not board.released_mummy_owner.has(pos):
			continue
		var team: int = board.released_mummy_owner[pos]
		board.released_mummy_owner.erase(pos)
		board.released_mummies.erase(pos)
		if board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos):
			var mummy := BoardPiece.new(team, false)
			mummy.is_mummy = true
			board.grid[pos.y][pos.x] = mummy
			born.append(pos)
	if not born.is_empty():
		var c0: Vector2i = born[0]
		host.rule_banner_view.pop_rule_trigger(
			host.board_offset + Vector2(c0.x * host.cell_size + host.cell_size / 2.0, c0.y * host.cell_size + host.cell_size / 2.0),
			"A MÚMIA DESPERTA!", Color(0.8, 0.7, 0.4), "sarcophagi")
		var tw = create_tween().set_parallel(true)
		for bp in born:
			host.piece_spawn_scales[bp] = 0.0
			tw.tween_method(func(v): host.piece_spawn_scales[bp] = v, 0.0, 1.0, 0.45)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished

	# 2) Isca do Sapo: conta as jogadas; quando zera, a língua desce.
	if board.bait_flies.is_empty():
		return
	var due: Array = []
	for b in board.bait_flies:
		b["turns"] = int(b["turns"]) - 1
		if int(b["turns"]) <= 0:
			due.append(b["pos"])
	var pending: Array = []
	for b in board.bait_flies:
		if int(b["turns"]) > 0:
			pending.append(b["pos"])
	if host.frog_animation_view != null:
		host.frog_animation_view.ensure_static_flies(pending + due)
	if due.is_empty():
		return
	board.bait_flies = board.bait_flies.filter(func(b): return int(b["turns"]) > 0)
	await get_tree().create_timer(0.3).timeout
	await host.frog_animation_view.play_tongue_attack(board, due)
	host.frog_animation_view.ensure_static_flies(pending)
	host.queue_redraw()

# ==========================================
# FIM DE DUELO
# ==========================================

func trigger_game_over(won: bool, rewards: Dictionary = {}, custom_title: String = "", defeat_message: String = "") -> void:
	var host = _host
	host.is_game_over = true
	CoinFlipView.rigged_team = 0
	host.selected_tile = Vector2i(-1, -1)
	host.valid_moves_for_selected = []
	host.action_cards.cancel_selection()
	host.update_gold_display()
	if won:
		TutorialManager.report_event("duel_won")
	# Meta-progressão: conta a vitória (as Coroas são pagas no fim da run).
	if not TutorialManager.is_active and won:
		MetaProgress.register_duel_win(RunManager.current_node_type)
	host.boss_say("win" if won else "lose")
	host.game_over_modal.show_game_over(won, rewards, custom_title, defeat_message)

# Cartas (e outros efeitos fora de jogada) podem tirar a ÚLTIMA peça de um lado.
# Sem checar na hora, o duelo ficava parado com o tabuleiro vazio até o próximo
# fim de turno que nunca vinha. Só age se algum lado ficou sem peças.
func check_elimination() -> bool:
	var host = _host
	if host.is_game_over:
		return true
	if host.board.count_pieces(host.human_team) > 0 and host.board.count_pieces(host.ai_team) > 0:
		return false
	return await check_game_over()

func check_game_over() -> bool:
	var host = _host
	var custom_res = host.current_duel.check_custom_victory()
	if custom_res.ended:
		var reward = host.current_duel.calculate_reward_gold() if custom_res.won else {}
		trigger_game_over(custom_res.won, reward, custom_res.title)
		return true

	if host.current_duel.uses_sudden_death():
		var match_ended_by_points = await host.sudden_death_mgr.process_turn_end(host.board, host.human_team, host.ai_team)

		# A Morte Súbita acabou de ser ativada NESTA chamada — aguarda de
		# verdade a resolução de qualquer Lei associada (ex: Empate
		# Impossível, que gira 3 moedas) antes de deixar o resto do turno
		# continuar. Sem isso, a IA podia jogar em cima da animação ainda
		# rodando, já que sinais não fazem quem emite esperar handlers
		# assíncronos terminarem.
		if host.sudden_death_mgr.just_triggered:
			host.sudden_death_mgr.just_triggered = false
			await host._on_sudden_death_triggered()

		if match_ended_by_points:
			return true

	if host.board.get_all_valid_moves(host.ai_team).is_empty() and not host.current_duel.requires_full_elimination():
		# Tutorial: na primeira vitória do Duelo 1, o Guia interrompe o
		# fim de jogo normal e força uma demonstração de Morte Súbita
		# ali mesmo, em vez de ir direto pra recompensa.
		if TutorialManager.is_active and TutorialManager.current_step == TutorialManager.Step.DUEL_1_BASICS and not TutorialManager.duel1_sudden_death_done:
			TutorialManager.duel1_sudden_death_done = true
			await tutorial_force_sudden_death()
			return false
		var reward = host.current_duel.calculate_reward_gold()
		trigger_game_over(true, reward, "VITORIA NO DUELO!")
		return true
	elif host.board.get_all_valid_moves(host.human_team).is_empty():
		trigger_game_over(false, {}, "", "Seu exercito ficou sem movimentos possiveis — bloqueio total do inimigo!")
		return true

	return false

func on_sudden_death_ended(won: bool, _base_msg: String) -> void:
	if won:
		var reward = _host.current_duel.calculate_reward_gold()
		trigger_game_over(true, reward, "VITORIA NO DUELO!")
	else:
		trigger_game_over(false, {}, "", "A morte subita chegou ao fim e o inimigo somou mais pontos no tabuleiro.")
