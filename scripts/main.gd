extends Node2D

# Cena do duelo. Este script é o HOST: dono de todo o estado do duelo e
# responsável só por MONTAR os módulos e ligar os sinais entre eles. O
# comportamento vive nos módulos, que leem/escrevem este estado via `host.<campo>`:
#   - DuelTurnController  : coin flip, cliques, turno do jogador/IA, fim de duelo
#   - ActionCardController: mão, seleção e execução das Cartas de Ação
#   - BoardRenderer       : desenho do tabuleiro
#   - DebugRuleConsole    : atalhos de debug (só em builds de debug)
#
# Contrato completo de campos/métodos que os módulos esperam deste host:
# ver os cabeçalhos de duel_turn_controller.gd, action_card_controller.gd,
# board_renderer.gd e debug_rule_console.gd, além dos campos lidos por
# duck typing pelas cartas (context["main"]) em cards/catalog/.

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const TUTORIAL_MAP_SCENE_PATH: String = "res://tutorial_map_view.tscn"
const RUN_OVER_SCENE_PATH: String = "res://run_over_view.tscn"
const EMPTY_TILE: Vector2i = Vector2i(-1, -1)

# ---------- Tabuleiro e duelo ----------
var cell_size: float = 64.0
var board_offset: Vector2 = Vector2.ZERO
var board: Board
var current_duel: DuelBase

var human_team: int = Board.WHITE
var ai_team: int = Board.BLACK
var current_turn: int = Board.WHITE

# ---------- Estado de turno ----------
var selected_tile: Vector2i = EMPTY_TILE
var valid_moves_for_selected: Array = []
var multi_jump_tile: Vector2i = EMPTY_TILE
var is_ai_thinking: bool = false
var is_starting_match: bool = true
# Tutorial: verdadeiro da hora que as peças pousam até a introdução do Guia
# (cartão de título + falas) terminar — nesse intervalo nada é jogável.
var is_tutorial_intro_playing: bool = false
var is_game_over: bool = false

# true enquanto uma carta/lei com efeito assíncrono (moeda) está resolvendo —
# bloqueia jogar outra carta ou peça até a animação terminar.
var is_resolving_card_effect: bool = false

# ---------- Estado lido/escrito pelas Cartas de Ação ----------
var extra_turns_by_team: Dictionary = {}
# O que o jogador está jogando "de bônus" agora (e pode ignorar com o botão):
# "" = nada | "step" = passo extra (Segundo Movimento) | "fly" = 2ª jogada da
# Dama Voadora | "turn" = turno extra inteiro. Quem escreve é o DuelTurnController.
var extra_skip_kind: String = ""
var skip_extra_btn: Button
var skip_extra_title: Label
var skip_extra_sub: Label
var _skip_extra_was_shown: bool = false
var _skip_extra_t: float = 0.0
const SKIP_EXTRA_W: float = 330.0
const SKIP_EXTRA_H: float = 84.0
var show_enemy_threats: bool = false
var lost_piece_last_enemy_turn: bool = false
var predicted_ai_move: Dictionary = {}

# ---------- Estado visual (lido pelo BoardRenderer) ----------
var piece_spawn_scales: Dictionary = {}
var animating_coronation_tile: Vector2i = EMPTY_TILE
var moving_piece_tile: Vector2i = EMPTY_TILE
var selection_pulse: float = 1.0
var _pulse_tween: Tween

# ---------- Lado inimigo (definido pela dificuldade do duelo) ----------
var _enemy_rules: Array[RuleCard] = []
var _ai_starting_cards: Array[ActionCard] = []

# ---------- Módulos de comportamento ----------
var turn_controller: DuelTurnController
var action_cards: ActionCardController
var board_renderer: BoardRenderer
var _debug_console: DebugRuleConsole

# ---------- Views de animação ----------
var coin_flip_view: CoinFlipView            # sorteio de início de partida
var card_coin_flip_view: CoinFlipView       # efeitos de carta/lei (separada de propósito)
var multi_coin_flip_view: MultiCoinFlipView # Empate Impossível (3 moedas)
var king_animation_view: KingAnimationView
var piece_movement_view: PieceMovementAnimationView
var frog_animation_view: FrogBossAnimationView
var piece_shatter_view: PieceShatterView
var sudden_death_mgr: SuddenDeathManager
var score_tally_view: ScoreTallyView
var rule_banner_view: RuleTriggerBannerView

# ---------- Interface ----------
var hud_bar: HUDBar
var enemy_hud_bar: EnemyHudBar
var enemy_hand_ui: EnemyHandUI
var ai_card_reveal_view: AICardRevealView
var inventory_ui: InventoryUI
var game_over_modal: GameOverModal
var rule_reward_modal: RuleRewardModal
var action_card_reward_modal: ActionCardRewardModal
var tile_hover_view: BoardTileHoverView
var tutorial_guide_view: TutorialGuideView

# Impede um segundo clique de entrar enquanto o primeiro ainda está
# resolvendo (animações encadeadas dentro de handle_cell_click).
var _click_busy: bool = false

# ==========================================
# MONTAGEM
# ==========================================

func _ready() -> void:
	var node_type: int = RunManager.current_node_type
	var active_size: Vector2i = RunManager.current_board_size

	if TutorialManager.is_active:
		# Duelos do tutorial nunca dependem do nó/tamanho da run real.
		node_type = MapNode.NodeType.Duelo
		active_size = TutorialManager.get_duel_board_size(TutorialManager.current_step)

	add_child(BiomeBackground.new())
	current_duel = _create_duel(node_type)
	_setup_board(active_size, node_type)
	_setup_enemy_side()
	_rebuild_duel_pipeline()

	_setup_modules(max(active_size.x, active_size.y))
	_setup_ui()
	_setup_controllers()

	if not TutorialManager.is_active:
		RunManager.rules_updated.connect(_on_run_rules_updated)

	_start_selection_pulse_loop()
	turn_controller.start_match_flow()

func _exit_tree() -> void:
	if RunManager.rules_updated.is_connected(_on_run_rules_updated):
		RunManager.rules_updated.disconnect(_on_run_rules_updated)

func _create_duel(node_type: int) -> DuelBase:
	match node_type:
		MapNode.NodeType.Chefe:
			# Cada bioma tem o seu chefe (e o seu conjunto de leis).
			if RunManager.map_biome == "deserto":
				return DuelBossDesert.new()
			return DuelBoss.new()
		MapNode.NodeType.DueloForte:
			return DuelHard.new()
	return DuelStandard.new()

# Convenção do projeto: board_size = Vector2i(linhas, colunas).
func _setup_board(size: Vector2i, node_type: int) -> void:
	var b_rows: int = size.x
	var b_cols: int = size.y
	var max_dim: int = max(b_rows, b_cols)

	if max_dim >= 12:
		cell_size = 64.0
	elif max_dim == 9:
		cell_size = 80.0
	elif max_dim >= 10:
		cell_size = 74.0
	elif max_dim <= 6:
		cell_size = 104.0
	else:
		cell_size = 88.0

	var viewport_size = get_viewport_rect().size
	var total_width = b_cols * cell_size
	var total_height = b_rows * cell_size

	# Centraliza pela área de casinhas. A moldura de madeira (quando existe o
	# sprite) só cresce PRA FORA disso como acabamento visual — reservar
	# espaço pra ela aqui bagunçava o clamp do eixo Y e tudo que depende de
	# board_offset (indicador de captura obrigatória, overlay da carta Visão,
	# centro do sorteio de cor da moeda).
	var center_x = (viewport_size.x - total_width) / 2.0
	# Faixa de cima reservada pra mão do inimigo (cartas de costas penduradas
	# no topo) e faixa de baixo pra mão do jogador recolhida: o tabuleiro fica
	# entre as duas, sem cartas por cima dele.
	# A moldura de madeira cresce ~53 px pra fora das casas; parte dela pode
	# ficar sob a mão, mas as casas nunca.
	var top_reserved: float = EnemyHandUI.RESERVED_HEIGHT + 36.0
	var bottom_reserved: float = 150.0
	var free_h = viewport_size.y - top_reserved - bottom_reserved
	var center_y = top_reserved + maxf(0.0, (free_h - total_height) / 2.0)
	board_offset = Vector2(center_x, center_y)

	board = Board.new(b_rows, b_cols)
	# Disposição sorteada no mapa (só duelos comuns/fortes; tutorial/chefe/emboscada = clássica).
	if not TutorialManager.is_active and (node_type == MapNode.NodeType.Duelo or node_type == MapNode.NodeType.DueloForte) \
			and RunManager.ambush_kind == "" and Board.LAYOUT_IDS.has(RunManager.current_board_layout):
		board.layout_id = RunManager.current_board_layout
	if TutorialManager.is_active:
		board.skin_id = BoardSkin.SKIN_TUTORIAL
	elif RunManager.map_biome == "deserto":
		board.skin_id = BoardSkin.SKIN_DESERT
	else:
		board.skin_id = BoardSkin.SKIN_WOOD
	board.set_theme_for_duel(node_type == MapNode.NodeType.DueloForte or node_type == MapNode.NodeType.Chefe)
	board.piece_destroyed.connect(_on_board_piece_destroyed)
	board.capture_prevented.connect(_on_board_capture_prevented)
	board.rule_fired.connect(_on_rule_fired)

# Leis e baralho da IA, conforme a dificuldade do duelo (ver DuelBase.get_enemy_*).
# No tutorial o inimigo não recebe nada — só o que o roteiro pede.
func _setup_enemy_side() -> void:
	_enemy_rules.clear()
	_ai_starting_cards.clear()
	if TutorialManager.is_active:
		return

	_enemy_rules.append_array(current_duel.get_enemy_fixed_rules())

	var random_count = current_duel.get_enemy_random_rule_count()
	if random_count > 0:
		# Pede mais do que precisa e filtra: a IA não deve sortear uma Lei
		# que o jogador já tem nem repetir uma das fixas (ids duplicados
		# confundem has_rule/remove_rule).
		var taken_ids: Array[String] = []
		for r in RunManager.active_rules:
			taken_ids.append(r.id)
		for r in _enemy_rules:
			taken_ids.append(r.id)
		for candidate in LootTables.get_random_ai_rules(LootTables.AI_ELIGIBLE_RULE_IDS.size()):
			if random_count <= 0:
				break
			if taken_ids.has(candidate.id):
				continue
			_enemy_rules.append(candidate)
			random_count -= 1

	var card_count: int = current_duel.get_enemy_card_count()
	# Emboscada: quem foi pego de surpresa enfrenta um inimigo mais preparado;
	# quem armou a emboscada, um mais desprevenido.
	if RunManager.ambush_kind == "ambushed":
		card_count += 1
	elif RunManager.ambush_kind == "setup":
		card_count = maxi(1, card_count - 1)
	_ai_starting_cards = LootTables.get_ai_starting_deck(card_count, _enemy_card_depth())

# Profundidade do duelo na run (camada do nó; +1 em Duelo Forte; chefe = 7).
func _enemy_card_depth() -> int:
	if TutorialManager.is_active or RunManager.current_node == null:
		return 0
	var depth: int = RunManager.current_node.id.y
	if current_duel is DuelBoss:
		return 7
	if current_duel is DuelHard:
		depth += 1
	return clampi(depth, 1, 7)

# Monta o RulePipeline "ao vivo" do duelo. A fonte da verdade das Leis do
# jogador é o RunManager (ver comentário lá): este método é chamado de novo
# sempre que `rules_updated` dispara, em vez de manter uma lista paralela.
func _rebuild_duel_pipeline() -> void:
	var pipeline = RulePipeline.new()

	if TutorialManager.is_active:
		# Lição 1: sem Leis. Lição 3: as Leis COMPRADAS na Loja (RunManager),
		# com o kit do roteiro como reserva se a lista estiver vazia.
		if TutorialManager.current_step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			var rules: Array = RunManager.active_rules.duplicate()
			if rules.is_empty():
				for rule in LootTables.get_all_rules():
					if TutorialManager.SHOP_LAW_IDS.has(rule.id):
						rules.append(rule)
			for rule in rules:
				pipeline.add_rule(rule)
	else:
		for rule in RunManager.active_rules:
			pipeline.add_rule(rule)

	for rule in _enemy_rules:
		pipeline.add_rule_unchecked(rule)

	board.set_rule_pipeline(pipeline)

func _on_run_rules_updated() -> void:
	_rebuild_duel_pipeline()
	clear_board_selection()

func _setup_modules(max_dim: int) -> void:
	# O renderer vem primeiro: nós irmãos desenham na ordem da árvore, e as
	# views de animação precisam ficar POR CIMA do tabuleiro.
	board_renderer = BoardRenderer.new()
	add_child(board_renderer)
	board_renderer.setup(self)

	coin_flip_view = CoinFlipView.new()
	add_child(coin_flip_view)
	# Tutorial: a Lição 1 é sempre com as BRANCAS (posição didática pronta).
	if TutorialManager.is_active and TutorialManager.current_step == TutorialManager.Step.DUEL_1_BASICS:
		coin_flip_view.forced_result = 1

	card_coin_flip_view = CoinFlipView.new()
	add_child(card_coin_flip_view)

	multi_coin_flip_view = MultiCoinFlipView.new()
	add_child(multi_coin_flip_view)

	king_animation_view = KingAnimationView.new()
	add_child(king_animation_view)

	piece_movement_view = PieceMovementAnimationView.new()
	add_child(piece_movement_view)
	piece_movement_view.landed.connect(_on_piece_landed)

	frog_animation_view = FrogBossAnimationView.new()
	add_child(frog_animation_view)
	frog_animation_view.configure(board_offset, cell_size)

	piece_shatter_view = PieceShatterView.new()
	add_child(piece_shatter_view)

	sudden_death_mgr = SuddenDeathManager.new()
	add_child(sudden_death_mgr)
	sudden_death_mgr.configure(max_dim)
	score_tally_view = ScoreTallyView.new()
	add_child(score_tally_view)
	sudden_death_mgr.tally_view = score_tally_view
	sudden_death_mgr.tally_board_offset = board_offset
	sudden_death_mgr.tally_cell_size = cell_size

	rule_banner_view = RuleTriggerBannerView.new()
	add_child(rule_banner_view)
	rule_banner_view.rule_fired.connect(_on_rule_fired)

func _setup_ui() -> void:
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "MainUILayer"
	add_child(ui_layer)

	hud_bar = HUDBar.new()
	ui_layer.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(toggle_inventory)
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	enemy_hud_bar = EnemyHudBar.new()
	ui_layer.add_child(enemy_hud_bar)
	enemy_hud_bar.refresh(_enemy_rules)
	enemy_hud_bar.align_board_with(hud_bar.law_board)

	enemy_hand_ui = EnemyHandUI.new()
	ui_layer.add_child(enemy_hand_ui)

	ai_card_reveal_view = AICardRevealView.new()
	ui_layer.add_child(ai_card_reveal_view)

	inventory_ui = InventoryUI.new()
	ui_layer.add_child(inventory_ui)
	inventory_ui.setup()

	tile_hover_view = BoardTileHoverView.new()
	ui_layer.add_child(tile_hover_view)
	tile_hover_view.setup(self)

	game_over_modal = GameOverModal.new()
	game_over_modal.action_confirmed.connect(_on_game_over_action)
	ui_layer.add_child(game_over_modal)

	rule_reward_modal = RuleRewardModal.new()
	rule_reward_modal.reward_completed.connect(_leave_duel)
	ui_layer.add_child(rule_reward_modal)

	action_card_reward_modal = ActionCardRewardModal.new()
	action_card_reward_modal.card_chosen.connect(func(_c): _leave_duel())
	action_card_reward_modal.skipped.connect(_leave_duel)
	ui_layer.add_child(action_card_reward_modal)

	# Botão "IGNORAR ... EXTRA": aparece no canto de baixo do tabuleiro (lado do
	# painel de Leis inimigas, sem cobrir moldura nem mão) enquanto o jogador tem
	# uma jogada/turno de bônus, para poder abrir mão dela.
	skip_extra_btn = Button.new()
	skip_extra_btn.custom_minimum_size = Vector2(SKIP_EXTRA_W, SKIP_EXTRA_H)
	skip_extra_btn.focus_mode = Control.FOCUS_NONE
	skip_extra_btn.visible = false
	PixelUI.skin_button(skip_extra_btn, Color(0.85, 0.64, 0.25))
	skip_extra_btn.pressed.connect(func(): turn_controller.skip_extra())
	var skip_box := VBoxContainer.new()
	skip_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_box.add_theme_constant_override("separation", 2)
	skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_extra_btn.add_child(skip_box)
	skip_extra_title = Label.new()
	skip_extra_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_extra_title.add_theme_font_size_override("font_size", 26)
	skip_extra_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	skip_extra_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	skip_extra_title.add_theme_constant_override("shadow_offset_x", 2)
	skip_extra_title.add_theme_constant_override("shadow_offset_y", 2)
	skip_extra_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_box.add_child(skip_extra_title)
	skip_extra_sub = Label.new()
	skip_extra_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_extra_sub.add_theme_font_size_override("font_size", 18)
	skip_extra_sub.add_theme_color_override("font_color", Color(0.86, 0.74, 0.52, 0.9))
	skip_extra_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_box.add_child(skip_extra_sub)
	ui_layer.add_child(skip_extra_btn)

	if TutorialManager.is_active:
		tutorial_guide_view = TutorialGuideView.new()
		tutorial_guide_view.spot_resolver = _tutorial_spot_rect
		add_child(tutorial_guide_view)
		TutorialManager.objective_done.connect(_on_tutorial_objective_done)
		TutorialManager.law_first_applied.connect(_on_tutorial_law_first_applied)

func _setup_controllers() -> void:
	action_cards = ActionCardController.new()
	add_child(action_cards)
	action_cards.setup(self, hud_bar)

	turn_controller = DuelTurnController.new()
	add_child(turn_controller)
	turn_controller.setup(self)

	coin_flip_view.flip_completed.connect(turn_controller.on_coin_flip_completed)
	sudden_death_mgr.match_finished_by_points.connect(turn_controller.on_sudden_death_ended)

	_debug_console = DebugRuleConsole.new(self)

# ==========================================
# API PARA OS MÓDULOS (contrato do host)
# ==========================================

func update_gold_display() -> void:
	if hud_bar != null:
		hud_bar.update_gold()

# Limpa a peça selecionada no tabuleiro. No meio de um combo (multissalto) a
# seleção é obrigatória — limpá-la travaria o jogo, então nesse caso não faz nada.
func clear_board_selection() -> void:
	if multi_jump_tile != EMPTY_TILE:
		return
	selected_tile = EMPTY_TILE
	valid_moves_for_selected = []

func handle_cell_click(pos: Vector2i) -> void:
	await turn_controller.handle_cell_click(pos)

func toggle_inventory() -> void:
	if inventory_ui:
		inventory_ui.toggle_visibility()

const TUTORIAL_IDLE_SECONDS: float = 20.0
var _tutorial_idle_time: float = 0.0

# Dica do tutorial disparada por evento de jogo — uma vez por duelo, sem
# bloquear o turno (a dica some sozinha).
func tutorial_maybe_show_tip(tip_id: String) -> void:
	if not TutorialManager.is_active or tutorial_guide_view == null:
		return
	if TutorialManager.has_shown_tip(tip_id):
		return
	# Nada de dica solta antes/durante a introdução do Guia.
	if not TutorialManager.objectives_begun or tutorial_guide_view.is_showing_sequence:
		return
	var text = TutorialManager.get_in_duel_tip(TutorialManager.current_step, tip_id)
	if text == "":
		return
	TutorialManager.mark_tip_shown(tip_id)
	tutorial_guide_view.show_tip(text)
	_tutorial_pulse_for(tip_id)

# Primeira vez que uma Lei age: o Guia interrompe e explica (depois do
# letreiro da Lei terminar de aparecer).
func _on_tutorial_law_first_applied() -> void:
	if tutorial_guide_view == null:
		return
	await get_tree().create_timer(1.0).timeout
	# Se o duelo acabou, ou o jogador já está vendo outra fala, não interrompe.
	if is_game_over or tutorial_guide_view.is_showing_sequence:
		return
	await tutorial_guide_view.play_sequence(TutorialManager.get_law_applied_lines())

# Objetivo cumprido: destaca a parte da interface relacionada, se houver.
func _on_tutorial_objective_done(event_id: String) -> void:
	if tutorial_guide_view == null:
		return
	_tutorial_pulse_for(event_id)

# Pulsa o trecho da interface ligado a uma dica/objetivo. A moldura SEGUE o
# trecho (pulse_spot), então cresce junto com a mão de cartas ao passar o mouse.
func _tutorial_pulse_for(tip_id: String) -> void:
	var spot := ""
	match tip_id:
		"card_available", "card_selected", "card_used":
			spot = "hand"
		"law_triggered":
			spot = "law_board"
	if spot != "" and _tutorial_spot_rect(spot).size != Vector2.ZERO:
		tutorial_guide_view.pulse_spot(spot)

# Tip/objetivo → trecho da interface (moldura pulsante do Guia).
func _tutorial_highlight_rect_for(tip_id: String) -> Rect2:
	match tip_id:
		"card_available", "card_selected", "card_used":
			return _tutorial_spot_rect("hand")
		"law_triggered":
			return _tutorial_spot_rect("law_board")
	return Rect2()

# Resolve ids de "spot" do roteiro em retângulos de tela.
func _tutorial_spot_rect(id: String) -> Rect2:
	var vp = get_viewport().get_visible_rect().size
	var cs: float = cell_size
	if id == "board":
		return Rect2(board_offset, Vector2(board.cols * cs, board.rows * cs))
	if id.begins_with("cell:"):
		var xy = id.substr(5).split(",")
		return Rect2(board_offset + Vector2(int(xy[0]) * cs, int(xy[1]) * cs), Vector2(cs, cs))
	if id.begins_with("row:"):
		var rr: int = int(id.substr(4))
		return Rect2(board_offset + Vector2(0, rr * cs), Vector2(board.cols * cs, cs))
	match id:
		"sd_clock":
			return Rect2(20.0, 20.0, 340.0, 50.0)
		"hand":
			if action_cards != null and action_cards.card_hand_ui != null:
				var hr: Rect2 = action_cards.card_hand_ui.get_hand_rect()
				if hr.size != Vector2.ZERO:
					return hr
			var n: int = 1
			if action_cards != null and action_cards.card_deck_mgr != null:
				n = maxi(1, action_cards.card_deck_mgr.hand.size())
			var w: float = 120.0 + n * 56.0
			return Rect2(vp.x * 0.5 - w * 0.5, vp.y - 175.0, w, 165.0)
		"law_board":
			if hud_bar != null and hud_bar.law_board != null:
				return Rect2(hud_bar.law_board.global_position, hud_bar.law_board.size * hud_bar.law_board.get_global_transform().get_scale())
		"enemy_law_board":
			if enemy_hud_bar != null and enemy_hud_bar.law_board != null:
				return Rect2(enemy_hud_bar.law_board.global_position, enemy_hud_bar.law_board.size * enemy_hud_bar.law_board.get_global_transform().get_scale())
	return Rect2()

# Chamado (e aguardado) pelo DuelTurnController quando a Morte Súbita
# acaba de começar. NÃO é ligado ao sinal sudden_death_triggered de propósito:
# sinais não fazem quem emite esperar, e a IA jogaria em cima das moedas.
func _on_sudden_death_triggered() -> void:
	if TutorialManager.is_active and tutorial_guide_view != null \
			and TutorialManager.current_step == TutorialManager.Step.DUEL_1_BASICS \
			and not TutorialManager.duel1_sudden_death_done:
		TutorialManager.duel1_sudden_death_done = true
		await tutorial_guide_view.play_sequence(TutorialManager.get_sudden_death_started_lines())
	if sudden_death_mgr.triggered_by_stall:
		await _show_impasse_banner()
	await _resolve_impossible_tie()

# Aviso exclusivo da Morte Súbita por IMPASSE: a palavra gigante pulsando no
# centro da tela por alguns segundos (a jogada espera acabar).
const IMPASSE_SHOW_TIME: float = 2.6
func _show_impasse_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.25, 0.0, 0.03, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques enquanto o aviso está na tela
	layer.add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var word := Label.new()
	word.text = "IMPASSE"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 200)
	word.add_theme_color_override("font_color", Color(1.0, 0.32, 0.34))
	word.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.04))
	word.add_theme_constant_override("outline_size", 24)
	box.add_child(word)

	var sub := Label.new()
	sub.text = "MORTE SÚBITA"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Color(0.94, 0.9, 0.81))
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.04))
	sub.add_theme_constant_override("outline_size", 8)
	box.add_child(sub)

	box.modulate.a = 0.0
	await get_tree().process_frame
	box.pivot_offset = box.size / 2.0
	box.scale = Vector2(1.6, 1.6)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(tint, "color:a", 0.38, 0.3)
	tw.tween_property(box, "modulate:a", 1.0, 0.25)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Pulsa até o fim do tempo.
	var pulse := create_tween().set_loops()
	pulse.tween_property(box, "scale", Vector2(1.1, 1.1), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(box, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(IMPASSE_SHOW_TIME).timeout
	pulse.kill()

	var out := create_tween().set_parallel(true)
	out.tween_property(tint, "color:a", 0.0, 0.4)
	out.tween_property(box, "modulate:a", 0.0, 0.4)
	out.tween_property(box, "scale", Vector2(1.25, 1.25), 0.4)
	await out.finished
	layer.queue_free()

# Lei Empate Impossível: ao começar a Morte Súbita, cada time ao qual a Lei
# se aplica joga 3 moedas; cada moeda que cair na cor do time promove uma peça comum aleatória sua.
func _resolve_impossible_tie() -> void:
	if board.rule_pipeline == null:
		return

	var affected_teams: Array[int] = []
	for rule in board.rule_pipeline.active_rules:
		if rule.id != "impossible_tie_law":
			continue
		for team in [human_team, ai_team]:
			if rule.applies_to_team(team, board.human_team_color) and not affected_teams.has(team):
				affected_teams.append(team)

	for team in affected_teams:
		await _play_impossible_tie_for_team(team)

func _play_impossible_tie_for_team(team: int) -> void:
	if _get_common_piece_positions(team).is_empty():
		return
	board.rule_fired.emit("impossible_tie_law")

	is_resolving_card_effect = true

	var is_white = team == Board.WHITE
	multi_coin_flip_view.white_sprite_path = BoardPiece.TEXTURE_WHITE_PATH
	multi_coin_flip_view.black_sprite_path = BoardPiece.TEXTURE_BLACK_PATH
	multi_coin_flip_view.favorable_is_white = is_white
	multi_coin_flip_view.win_text = "%s! PROMOVIDA!" % CoinFlipView.color_word(is_white)
	multi_coin_flip_view.lose_text = "%s..." % CoinFlipView.color_word(not is_white)

	var center = board_offset + Vector2(board.cols * cell_size / 2.0, board.rows * cell_size / 2.0)
	var results: Array = await multi_coin_flip_view.play_sequence(center, 3, cell_size)
	multi_coin_flip_view.clear()

	for favorable in results:
		if not favorable:
			continue
		var candidates = _get_common_piece_positions(team)
		if candidates.is_empty():
			break
		var pos: Vector2i = candidates[randi() % candidates.size()]
		var piece: BoardPiece = board.grid[pos.y][pos.x]
		piece.is_king = true

		var piece_center = board_offset + Vector2(pos.x * cell_size + cell_size / 2.0, pos.y * cell_size + cell_size / 2.0)
		animating_coronation_tile = pos
		await king_animation_view.play_coronation(piece_center, cell_size, piece)
		animating_coronation_tile = EMPTY_TILE

	is_resolving_card_effect = false

func _get_common_piece_positions(team: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == team and not p.is_king:
				positions.append(Vector2i(c, r))
	return positions

func _on_board_piece_destroyed(grid_pos: Vector2i, destroyed_piece: BoardPiece) -> void:
	var piece_center = board_offset + Vector2(grid_pos.x * cell_size + cell_size / 2.0, grid_pos.y * cell_size + cell_size / 2.0)
	piece_shatter_view.shatter_piece(piece_center, destroyed_piece, cell_size)

func _on_board_capture_prevented(grid_pos: Vector2i, _piece: BoardPiece) -> void:
	var tile_center = board_offset + Vector2(grid_pos.x * cell_size + cell_size / 2.0, grid_pos.y * cell_size + cell_size / 2.0)
	var preventer_id: String = board.rule_pipeline.last_preventer_id if board.rule_pipeline != null else ""
	rule_banner_view.pop_rule_trigger(tile_center, "CAPTURA BLOQUEADA!", Color(0.45, 0.75, 1.0), preventer_id)

# Game juice: a Lei agiu -> o slot dela (no quadro do jogador ou do inimigo) treme e brilha.
func _on_rule_fired(rule_id: String) -> void:
	if rule_id == "":
		return
	if hud_bar != null and hud_bar.flash_rule(rule_id):
		return
	if enemy_hud_bar != null:
		enemy_hud_bar.flash_rule(rule_id)

# ==========================================
# FIM DE DUELO → PRÓXIMA CENA
# ==========================================

func _on_game_over_action(won: bool) -> void:
	game_over_modal.visible = false

	if TutorialManager.is_active:
		TutorialManager.last_duel_won = won
		# Só a primeira vitória do tutorial mostra o sorteio de Carta (ilustrativo:
		# a carta nunca entra no inventário real — ver ActionCardRewardModal).
		if won and tutorial_guide_view != null and not TutorialManager.all_objectives_done():
			await tutorial_guide_view.play_sequence(TutorialManager.get_missed_objectives_lines())
		if won and TutorialManager.current_step == TutorialManager.Step.DUEL_1_BASICS:
			if tutorial_guide_view != null:
				await tutorial_guide_view.play_sequence(TutorialManager.get_card_reward_explanation_lines())
			action_card_reward_modal.prompt_reward()
			return
		_leave_duel()
		return

	# Fim de run (derrota ou Chefe derrotado): paga os Coroas e abre a tela de resumo.
	if not won:
		MetaProgress.settle_run(false)
		RunManager.start_new_run()
		_go_run_over()
		return

	if RunManager.current_node_type == MapNode.NodeType.Chefe and RunManager.has_next_biome():
		# Chefe do bioma derrotado e ainda há outro mapa (floresta -> deserto): a run
		# continua com tudo que ganhou; escolhe uma Lei de recompensa e segue pro novo mapa.
		RunManager.advance_to_next_biome()
		rule_reward_modal.open_reward_draft()
		return

	if RunManager.current_node_type == MapNode.NodeType.Chefe:
		MetaProgress.settle_run(true)
		RunManager.start_new_run()
		_go_run_over()
		return

	if RunManager.current_node_type == MapNode.NodeType.DueloForte:
		rule_reward_modal.open_reward_draft()
	else:
		action_card_reward_modal.prompt_reward()

func _go_run_over() -> void:
	SceneTransition.go(RUN_OVER_SCENE_PATH)

func _leave_duel() -> void:
	var target = TUTORIAL_MAP_SCENE_PATH if TutorialManager.is_active else MAP_SCENE_PATH
	SceneTransition.go(target)

# ==========================================
# INPUT
# ==========================================

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_tutorial_idle_time = 0.0
	if event is InputEventKey and event.pressed and not event.echo:
		if _can_use_debug_keys() and _debug_console.handle_key(event.keycode):
			return
		if event.keycode == KEY_TAB:
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE:
			if action_cards.has_selected_card():
				action_cards.cancel_selection()
				get_viewport().set_input_as_handled()
				return
			if inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
				get_viewport().set_input_as_handled()
				return

	var is_left_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if action_cards.has_selected_card():
			action_cards.cancel_selection()
			return

	# Clique pula a animação de moeda que estiver girando.
	if is_left_click:
		if is_starting_match and coin_flip_view.is_animating:
			coin_flip_view.skip_spin()
			return
		if multi_coin_flip_view.is_active():
			multi_coin_flip_view.skip_current()
			return
		if is_resolving_card_effect and card_coin_flip_view.is_animating:
			card_coin_flip_view.skip_spin()
			return

	if is_game_over or is_starting_match or (inventory_ui and inventory_ui.visible):
		return

	if _is_board_input_blocked():
		return

	if is_left_click:
		var grid_pos = Vector2i((event.position - board_offset) / cell_size)
		if board.is_valid_pos(grid_pos.y, grid_pos.x):
			_click_busy = true
			await turn_controller.handle_cell_click(grid_pos)
			_click_busy = false

func _is_board_input_blocked() -> bool:
	return is_ai_thinking \
		or is_tutorial_intro_playing \
		or is_resolving_card_effect \
		or _click_busy \
		or current_turn != human_team \
		or (tutorial_guide_view != null and tutorial_guide_view.is_showing_sequence) \
		or king_animation_view.is_animating \
		or (score_tally_view != null and score_tally_view.is_animating) \
		or frog_animation_view.is_attacking \
		or piece_movement_view.is_animating

# Atalhos de debug só existem em builds de debug e nunca no tutorial.
func _can_use_debug_keys() -> bool:
	return DebugFlags.SHORTCUTS and OS.is_debug_build() and not TutorialManager.is_active and not is_starting_match and not is_game_over

func _process(delta: float) -> void:
	_update_skip_extra_button(delta)
	_poll_tutorial_tips(delta)

func _update_skip_extra_button(delta: float = 0.0) -> void:
	if skip_extra_btn == null:
		return
	var show: bool = extra_skip_kind != "" and not is_game_over and not is_starting_match \
		and current_turn == human_team and not _is_board_input_blocked()
	skip_extra_btn.visible = show
	if not show:
		_skip_extra_was_shown = false
		return
	var texts: Dictionary = {
		"step": ["IGNORAR PASSO EXTRA", "Abre mão do passo e passa a vez"],
		"fly": ["IGNORAR 2ª JOGADA", "Abre mão da jogada e passa a vez"],
		"turn": ["IGNORAR TURNO EXTRA", "Abre mão do bônus e passa a vez"],
	}
	var tx: Array = texts.get(extra_skip_kind, ["IGNORAR EXTRA", "Passa a vez"])
	skip_extra_title.text = "» " + String(tx[0])
	skip_extra_sub.text = String(tx[1])
	skip_extra_btn.size = Vector2(SKIP_EXTRA_W, SKIP_EXTRA_H)
	# Canto de baixo do tabuleiro, à direita da moldura; nunca sobe a ponto de
	# cobrir o painel de Leis inimigas (ele termina por volta de y = 800).
	var vp: Vector2 = get_viewport_rect().size
	var frame_right: float = board_offset.x + board.cols * cell_size + 56.0
	var bx: float = minf(frame_right + 16.0, vp.x - SKIP_EXTRA_W - 24.0)
	var by: float = maxf(board_offset.y + board.rows * cell_size - SKIP_EXTRA_H, 820.0)
	if not _skip_extra_was_shown:
		_skip_extra_was_shown = true
		_skip_extra_t = 0.0
	_skip_extra_t += delta
	# Entra deslizando da direita e depois pulsa de leve, chamando o olhar.
	var slide: float = (1.0 - ease_out_cubic(clampf(_skip_extra_t / 0.25, 0.0, 1.0))) * 40.0
	skip_extra_btn.position = Vector2(bx + slide, by)
	skip_extra_btn.modulate.a = clampf(_skip_extra_t / 0.2, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_skip_extra_t * 3.2)
	skip_extra_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62).lerp(Color(1.0, 1.0, 0.85), pulse * 0.6))

static func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

# Dicas do tutorial que dependem de um estado do tabuleiro (não de um evento
# pontual). Só roda enquanto o tutorial está ativo e a dica ainda não saiu.
func _poll_tutorial_tips(delta: float) -> void:
	if not TutorialManager.is_active or tutorial_guide_view == null:
		return
	if is_game_over or is_starting_match or is_ai_thinking or current_turn != human_team:
		return
	if tutorial_guide_view.is_showing_sequence:
		return

	# Jogador parado há um bom tempo na própria vez: o Guia dá uma ajuda.
	_tutorial_idle_time += delta
	if _tutorial_idle_time >= TUTORIAL_IDLE_SECONDS:
		_tutorial_idle_time = 0.0
		tutorial_maybe_show_tip("idle_hint")

	match TutorialManager.current_step:
		TutorialManager.Step.DUEL_1_BASICS:
			pass # Lição 1 é guiada por objetivos; sem dicas extras.
		TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			if not action_cards.card_deck_mgr.hand.is_empty():
				tutorial_maybe_show_tip("card_available")

func _start_selection_pulse_loop() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "selection_pulse", 1.2, 0.4).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "selection_pulse", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

# ==========================================
# DEBUG (API chamada pelo DebugRuleConsole)
# ==========================================

func debug_force_win() -> void:
	var reward = current_duel.calculate_reward_gold()
	turn_controller.trigger_game_over(true, reward, "VITORIA NO DUELO!")

func debug_force_loss() -> void:
	turn_controller.trigger_game_over(false)

func debug_force_sudden_death() -> void:
	if current_duel.uses_sudden_death():
		sudden_death_mgr.start_immediately()

func debug_restart_run() -> void:
	RunManager.start_new_run()
	SceneTransition.go(MAP_SCENE_PATH)

# Liga/desliga uma Lei da run. Quem reage é o RunManager.rules_updated →
# _on_run_rules_updated (reconstrói o pipeline do duelo).
func debug_toggle_rule(rule_id: String, make_rule: Callable) -> void:
	if RunManager.rule_pipeline.has_rule(rule_id):
		RunManager.remove_rule(rule_id)
	else:
		RunManager.add_rule(make_rule.call())

# Juice do duelo. Movimento: poeira + pequena onda no pouso. Captura: clarão na
# casa, onda grande, faíscas quentes em leque e um tremor curto e discreto.
func _on_piece_landed(center: Vector2, is_capture: bool) -> void:
	var g: Vector2 = to_global(center)
	Juice.dust(self, g, cell_size)
	if not is_capture:
		Juice.ring(self, g, cell_size * 0.5, Color(0.85, 0.63, 0.25, 0.9), 3.0, 0.22)
		return
	Juice.flash_square(self, g, cell_size, Color(1.0, 0.93, 0.75, 0.85), 0.18)
	Juice.ring(self, g, cell_size * 0.85, Color(1.0, 0.78, 0.35), 5.0, 0.3)
	Juice.ring(self, g, cell_size * 0.55, Color(1.0, 0.95, 0.85), 3.0, 0.22)
	Juice.burst(self, g, Color(0.96, 0.55, 0.18), 24, cell_size * 4.6, 0.55, maxf(5.0, cell_size / 9.0), 520.0, 360.0)
	Juice.burst(self, g, Color(1.0, 0.92, 0.6), 14, cell_size * 3.2, 0.45, maxf(4.0, cell_size / 12.0), 420.0, 360.0)
	Juice.shake(self, 2.5, 0.14)
	Juice.hit_stop(get_tree(), 0.045)
