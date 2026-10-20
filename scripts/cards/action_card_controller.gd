class_name ActionCardController
extends Node

# Sub-sistema de Cartas de Ação (mão, deck, seleção e execução no tabuleiro),
# extraído de main.gd.
#
# Ainda depende do "host" (hoje, main.gd) para:
#   - ler estado de turno/tabuleiro: board, human_team, current_turn, is_ai_thinking,
#     board_offset, cell_size
#   - montar o "context" que as ActionCards recebem em can_play/is_valid_target/execute —
#     algumas cartas (Segundo Turno, Visão, Recuar) leem e escrevem campos que hoje
#     vivem em main.gd (extra_turns_by_team, show_enemy_threats),
#     então o "main" dentro do context precisa continuar sendo o host, não este controller.
#   - limpar a seleção de peça no tabuleiro (clear_board_selection) e pedir redraw
#
# Host precisa expor: board, human_team, current_turn, is_ai_thinking, board_offset,
# cell_size, clear_board_selection(), update_gold_display(), queue_redraw().

var card_deck_mgr: CardDeckManager
var card_hand_ui: CardHandUI

var selected_action_card: ActionCard = null
var selected_action_card_idx: int = -1

var _host: Node2D
var _hud_bar: HUDBar

func setup(host: Node2D, hud_bar: HUDBar) -> void:
	_host = host
	_hud_bar = hud_bar

	card_deck_mgr = CardDeckManager.new()

	var starting_deck: Array[ActionCard] = []
	if RunManager != null:
		starting_deck = RunManager.player_deck
	# Tutorial: o baralho é o que o jogador COMPROU na lição da Loja. Se por
	# algum motivo estiver vazio, cai no kit padrão para a lição não quebrar.
	if TutorialManager.is_active and starting_deck.is_empty() \
			and TutorialManager.current_step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		for card_id in TutorialManager.SHOP_CARD_IDS:
			for card in LootTables.get_all_action_cards():
				if card.id == card_id:
					starting_deck.append(card)
					break

	card_deck_mgr.setup_duel(starting_deck)

	if _hud_bar != null:
		_hud_bar.setup_deck_manager(card_deck_mgr)

	card_hand_ui = CardHandUI.new()
	add_child(card_hand_ui)
	card_hand_ui.setup(card_deck_mgr, _hud_bar)

	card_hand_ui.card_clicked_for_target.connect(_on_card_selected_from_hand)
	card_hand_ui.card_drag_started.connect(_on_card_drag_started)
	card_hand_ui.card_drag_released.connect(_on_card_drag_released)
	card_hand_ui.card_selection_cancelled.connect(cancel_selection)

func _build_context() -> Dictionary:
	return {"main": _host, "deck_mgr": card_deck_mgr}

# Lei do Eco: a primeira carta de cada duelo (qualquer raridade) volta pra mão.
func _maybe_apply_echo(card: ActionCard) -> void:
	var board: Board = _host.board
	if board == null or board.rule_pipeline == null or card_deck_mgr == null:
		return
	var echo = board.rule_pipeline.get_rule("echo")
	if echo == null or not echo.try_consume_echo():
		return
	if card_deck_mgr.hand.size() >= CardDeckManager.MAX_HAND_SIZE:
		return
	card_deck_mgr.discard_pile.erase(card)
	card_deck_mgr.hand.append(card)
	card_deck_mgr.hand_updated.emit()
	if _host.rule_banner_view != null:
		_host.rule_banner_view.pop_rule_trigger(
			_host.board_offset + Vector2(board.cols * _host.cell_size / 2.0, board.rows * _host.cell_size / 2.0),
			"ECO!", Color(0.6, 0.8, 1.0), "echo")

func has_selected_card() -> bool:
	return selected_action_card != null

func is_target_valid(pos: Vector2i) -> bool:
	if selected_action_card == null:
		return false
	return selected_action_card.is_valid_target(_host.board, pos, _host.human_team, _build_context())

# Chamado pelo handle_cell_click do host. Retorna true se havia uma carta
# selecionada (nesse caso o clique já foi "consumido" pelo sistema de cartas,
# independentemente de o alvo ser válido) — replica o comportamento original.
func try_play_at_target(pos: Vector2i) -> bool:
	if selected_action_card == null:
		return false
	if selected_action_card.is_valid_target(_host.board, pos, _host.human_team, _build_context()):
		_execute_selected_card(pos)
	return true

func cancel_selection() -> void:
	selected_action_card = null
	selected_action_card_idx = -1
	if card_hand_ui and card_hand_ui.selected_card_idx != -1:
		card_hand_ui.cancel_selection(false)
	_host.queue_redraw()

func on_turn_started() -> void:
	if card_deck_mgr != null:
		card_deck_mgr.on_turn_started()

func _on_card_drag_started(card: ActionCard, idx: int) -> void:
	if _host.current_turn != _host.human_team or _host.is_ai_thinking or _host.is_resolving_card_effect or _host.is_tutorial_intro_playing or (_host.tutorial_guide_view and _host.tutorial_guide_view.is_showing_sequence):
		card_hand_ui.cancel_selection(false)
		return

	if not card.can_play(_host.board, _host.human_team, _build_context()):
		card_hand_ui.cancel_selection(false)
		return

	selected_action_card = card
	selected_action_card_idx = idx
	TutorialManager.report_event("card_selected")
	_host.clear_board_selection()
	_host.queue_redraw()

func _on_card_drag_released(card: ActionCard, _idx: int, screen_pos: Vector2) -> void:
	if selected_action_card == null:
		return

	var grid_pos = Vector2i((screen_pos - _host.board_offset) / _host.cell_size)

	if _host.board.is_valid_pos(grid_pos.y, grid_pos.x) and card.is_valid_target(_host.board, grid_pos, _host.human_team, _build_context()):
		_execute_selected_card(grid_pos)
	else:
		cancel_selection()

func _on_card_selected_from_hand(card: ActionCard, idx: int) -> void:
	if _host.current_turn != _host.human_team or _host.is_ai_thinking or _host.is_resolving_card_effect or _host.is_tutorial_intro_playing or (_host.tutorial_guide_view and _host.tutorial_guide_view.is_showing_sequence):
		card_hand_ui.cancel_selection(false)
		return

	if not card.can_play(_host.board, _host.human_team, _build_context()):
		card_hand_ui.cancel_selection(false)
		return

	selected_action_card = card
	selected_action_card_idx = idx
	# O clique (não só o arrastar) também conta como "selecionar uma Carta"
	# pro objetivo do tutorial — antes só o arrastar reportava, e o objetivo
	# nunca concluía quando o jogador clicava.
	TutorialManager.report_event("card_selected")
	_host.clear_board_selection()
	_host.queue_redraw()

	if card.target_type == ActionCard.TargetType.NONE:
		_execute_selected_card(Vector2i.ZERO)

func _execute_selected_card(pos: Vector2i) -> void:
	if selected_action_card == null:
		return

	# Precisa ser aguardado: cartas com efeito de moeda (moeda branca x preta)
	# só aplicam a consequência no tabuleiro DEPOIS da moeda visualmente
	# cair — sem esperar aqui, a carta seria descartada e a mão
	# atualizada antes da animação sequer começar.
	var played_card: ActionCard = selected_action_card
	Juice.sparkle(_host, _host.get_global_mouse_position(), 18)   # juice: fagulhas ao jogar
	@warning_ignore("redundant_await")
	await selected_action_card.execute(_host.board, pos, _host.human_team, _build_context())
	TutorialManager.report_event("card_used")

	# Cartas que mexem na mão (Reabastecer, Reciclar) mudam os índices: acha a
	# carta jogada pela identidade em vez de confiar no índice de antes.
	if card_deck_mgr != null:
		var real_idx = card_deck_mgr.hand.find(played_card)
		if real_idx >= 0:
			selected_action_card_idx = real_idx

	# Descarta a carta da mão e a envia permanentemente para o descarte deste duelo
	if card_deck_mgr != null and selected_action_card_idx >= 0:
		card_deck_mgr.play_card_at(selected_action_card_idx)
		_maybe_apply_echo(played_card)

	cancel_selection()
	_host.update_gold_display()
	_host.queue_redraw()

	# Carta que tirou a última peça de um lado (Duelo de Sorte, Cara ou Coroa
	# Triplo, Moeda do Destino...): encerra o duelo agora em vez de travar.
	await _host.turn_controller.check_elimination()
