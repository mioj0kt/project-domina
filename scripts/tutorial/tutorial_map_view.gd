class_name TutorialMapView
extends Control

const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"
const DUEL_SCENE_PATH: String = "res://scenes/main.tscn"
const SHOP_SCENE_PATH: String = "res://scenes/shop_view.tscn"
const BET_SCENE_PATH: String = "res://scenes/bet_view.tscn"

# O mapa do tutorial é uma versão curta do mapa do jogo: mesma casa, mesma
# distância entre camadas, mesmos soquetes/anéis/trilhas, câmera que acompanha
# o peão e peças que SEMPRE andam pulando na diagonal (regra das damas).
const TILE_SIZE: float = MapView.TILE_SIZE
const MAP_SPRITE_SCALE: int = MapView.MAP_SPRITE_SCALE
const NODE_SPRITE_SCALE: int = MapView.NODE_SPRITE_SCALE
const TILES_PER_LAYER: int = MapView.TILES_PER_LAYER
# Valor PRÓPRIO do tutorial (não herdar do mapa real): o tabuleiro do tutorial
# tem largura fixa e as trilhas só fecham se o desvio lateral entre dois nós for
# <= TILES_PER_LAYER. Mudar a largura do mapa da floresta não deve mexer aqui.
const TILES_BETWEEN_NODES: int = 2
const PAWN_SPRITE_PX: float = MapView.PAWN_SPRITE_PX
# Casas extras acima do último nó: a "última fileira" do mapa (onde o Guia
# chega no final e é coroado sem querer).
const LESSON_LABEL_W: float = 460.0
const END_ROWS: int = 2
const BOARD_HALF_COLS: int = 4
const BOARD_BOTTOM_ROWS: int = 2

const HOP_TIME: float = 0.32
const HOP_PAUSE: float = 0.08
const HOP_ARC: float = 26.0

const CLEAR_COLOR: Color = Color(0.05, 0.06, 0.09)

# Soquete de cada passo do roteiro (mesmos sprites do mapa real).
var step_sprites: Dictionary = {
	TutorialManager.Step.INTRO: "nodo_inicio",
	TutorialManager.Step.DUEL_1_BASICS: "nodo_espadas",
	TutorialManager.Step.SHOP: "nodo_loja",
	TutorialManager.Step.DUEL_3_CARDS_AND_LAWS: "nodo_espadas",
	TutorialManager.Step.BET: "nodo_aposta",
}

var guide_view: TutorialGuideView
var guide_map_piece: GuideFaceControl
var status_label: Label
var progress_label: Label
var overlay: Node2D
var lesson_labels: Array[Label] = []
var node_buttons: Array[Button] = []
var node_art: Array = []            # [{base, ind}] na ordem de `steps`
var trails: Array[TutorialTrail] = []
var player_pawn: MapPlayerPawn
var camera: Camera2D
var island_base: IslandBase
var board_node: Node2D
var world_rect: Rect2 = Rect2()
var highlight_pulse: float = 0.0
var top_panel: PanelContainer

var _busy: bool = false
var _hovered: int = -1
# Índice (em `steps`) do nó onde o peão está parado. Só muda quando ele pula.
var _pawn_index: int = 0
var _pawn_resting: bool = true
var _guide_grid: Vector2i = Vector2i.ZERO
var _board_origin: Vector2 = Vector2.ZERO
var _board_rows: int = 0
var _board_cols: int = 0

# Ordem fixa do roteiro — cada item vira um nó clicável no mapa, na ordem.
# A Morte Súbita não é mais um nó separado: o Guia força ela dentro do
# próprio Duelo 1, logo depois da primeira vitória. O nó de Início é só
# visual (marca de onde o jogador "nasce" no mapa) — sempre já visitado,
# não leva a lugar nenhum ao clicar.
var steps: Array[int] = [
	TutorialManager.Step.INTRO,
	TutorialManager.Step.DUEL_1_BASICS,
	TutorialManager.Step.SHOP,
	TutorialManager.Step.DUEL_3_CARDS_AND_LAWS,
	TutorialManager.Step.BET,
]

func _ready() -> void:
	var sky := SpaceBackground.new()   # céu estrelado atrás do mapa
	sky.floater_alpha = 0.55           # ilhas/peças discretas (há texto por cima)
	add_child(sky)
	if not TutorialManager.is_active:
		TutorialManager.start_tutorial()

	# Índice de ONDE a peça está parada fisicamente agora — calculado
	# ANTES de qualquer avanço nesta chamada, pra ela nunca "nascer" lá
	# do início do mapa quando essa cena é recarregada depois de um
	# duelo/loja/aposta. Só o clique num nó (ver _on_node_pressed) move
	# a peça de verdade, com animação.
	var entry_index = steps.find(TutorialManager.current_step)
	if entry_index == -1:
		entry_index = 0

	_setup_world(entry_index)
	_setup_ui()
	_refresh_button_states()

	if TutorialManager.current_step == TutorialManager.Step.INTRO:
		await RunIntro.new().run(self, camera, _node_position(entry_index), player_pawn.piece_px)
		await guide_view.play_title_card("BEM-VINDO À", "DOMINA", "Tutorial · %d lições rápidas" % TutorialManager.LESSON_COUNT)
		await guide_view.play_sequence(TutorialManager.get_intro_lines())
		TutorialManager.advance_to(steps[1])
		_refresh_button_states()
		return

	if entry_index >= steps.size() - 1 and TutorialManager.last_duel_won:
		# Depois do cassino, as falas NÃO podem ser puladas (a cutscene do Irmão).
		await guide_view.play_sequence(TutorialManager.get_real_map_lines(), false)
		await guide_view.play_sequence(TutorialManager.get_finished_lines(), false)
		if TutorialManager.FLIP_ENDING:
			_busy = true  # esconde a seta de "próxima lição"
			await guide_view.play_sequence(TutorialManager.get_flip_walk_lines(), false)
			await _guide_walks_ahead()
			await guide_view.play_sequence(TutorialManager.get_flip_lines(), false)
			await _brother_captures_player()
		TutorialManager.advance_to(TutorialManager.Step.FINISHED)
		MetaProgress.mark_tutorial_done()
		TutorialManager.end_tutorial()
		SceneTransition.go(MAIN_MENU_PATH)
		return

	if not TutorialManager.last_duel_won:
		# Perdeu o duelo — fica no mesmo nó pra tentar de novo, em vez
		# de liberar o próximo como se tivesse vencido.
		status_label.text = TutorialManager.get_retry_hint(TutorialManager.current_step)
		top_panel.visible = true
		_refresh_button_states()
		return

	# Venceu/concluiu — libera o PRÓXIMO nó pro clique, mas a peça só
	# vai andar até lá quando o jogador realmente clicar nele.
	TutorialManager.advance_to(steps[entry_index + 1])
	_refresh_button_states()

# ---------------------------------------------------------------------------
# Geometria (mesma grade do mapa real)
# ---------------------------------------------------------------------------

# Casa (coluna, linha) do nó `index`: zigue-zague horizontal, uma camada acima
# da outra, com a MESMA correção de paridade do mapa real (os nós ficam sempre
# nas casas escuras, que são as que a peça alcança pulando na diagonal).
func _node_grid(index: int) -> Vector2i:
	var grid_row = -index * TILES_PER_LAYER
	var grid_col = TILES_BETWEEN_NODES if index % 2 == 1 else -TILES_BETWEEN_NODES
	if index == 0:
		grid_col = 0
	if (grid_row + grid_col) % 2 == 0:
		grid_col += 1
	return Vector2i(grid_col, grid_row)

func _grid_to_world(g: Vector2i) -> Vector2:
	return Vector2(g.x * TILE_SIZE, g.y * TILE_SIZE)

func _node_position(index: int) -> Vector2:
	return _grid_to_world(_node_grid(index))

# Casa da última fileira (acima do último nó, na mesma coluna).
func _end_grid() -> Vector2i:
	var g = _node_grid(steps.size() - 1)
	return Vector2i(g.x, g.y - END_ROWS)

func _end_row_pos() -> Vector2:
	return _grid_to_world(_end_grid())

# O Guia fica numa casa escura ao lado do nó onde o peão está.
func _guide_grid_for(index: int) -> Vector2i:
	var g = _node_grid(index)
	return Vector2i(g.x + 1, g.y - 1)

# ---------------------------------------------------------------------------
# Mundo (tabuleiro + trilhas + nós + peças), desenhado com a câmera
# ---------------------------------------------------------------------------

func _setup_world(entry_index: int) -> void:
	# Tabuleiro: a fileira de cima é a última fileira. A paridade da casa de
	# canto precisa bater com a global, senão as casas escuras (dos nós)
	# virariam claras.
	var end_g = _end_grid()
	var min_col = -BOARD_HALF_COLS
	var min_row = end_g.y
	if (min_row + min_col) % 2 != 0:
		min_col -= 1
	var max_row = BOARD_BOTTOM_ROWS
	_board_cols = -min_col * 2 + 1
	_board_rows = max_row - min_row + 1
	_board_origin = Vector2(min_col * TILE_SIZE - TILE_SIZE / 2.0, min_row * TILE_SIZE - TILE_SIZE / 2.0)
	var frame_px = BoardSkin.get_frame_px(TILE_SIZE, BoardSkin.SKIN_TUTORIAL)
	world_rect = Rect2(_board_origin, Vector2(_board_cols * TILE_SIZE, _board_rows * TILE_SIZE)).grow(frame_px)

	# Base rochosa (o mapa é uma ilha no espaço); a câmera é ligada depois.
	island_base = IslandBase.new()
	island_base.name = "IslandBase"
	island_base.biome = "tutorial"
	add_child(island_base)
	island_base.build(world_rect, MapView.MAP_SPRITE_SCALE, null)

	board_node = Node2D.new()
	board_node.name = "TutorialBoard"
	board_node.draw.connect(_draw_board)
	add_child(board_node)

	# Trilhas (estilo plástico, casa a casa) ligando os nós em ordem.
	var lines = Node2D.new()
	add_child(lines)
	for i in range(steps.size() - 1):
		var trail = TutorialTrail.new()
		trail.setup(_node_grid(i), _node_grid(i + 1), TILE_SIZE)
		lines.add_child(trail)
		trails.append(trail)

	# Legendas de cada nó, fora do tabuleiro (esquerda/direita, na altura do nó).
	for i in range(steps.size()):
		var lstep = steps[i]
		var lbox = Label.new()
		lbox.custom_minimum_size = Vector2(LESSON_LABEL_W, 0)
		lbox.size = Vector2(LESSON_LABEL_W, 0)
		lbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbox.add_theme_font_size_override("font_size", 28)
		lbox.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
		lbox.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
		lbox.add_theme_constant_override("outline_size", 6)
		if lstep == TutorialManager.Step.INTRO:
			lbox.text = "O Guia te espera aqui"
		else:
			lbox.text = "LIÇÃO %d · %s\n%s" % [TutorialManager.get_lesson_number(lstep), TutorialManager.get_lesson_title(lstep).to_upper(), TutorialManager.get_lesson_goal(lstep)]
		var npos = _node_position(i)
		var on_right: bool = _node_grid(i).x >= 0
		if on_right:
			lbox.position = Vector2(world_rect.end.x + 18.0, npos.y - 26.0)
			lbox.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			lbox.position = Vector2(world_rect.position.x - 18.0 - LESSON_LABEL_W, npos.y - 26.0)
			lbox.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(lbox)
		lesson_labels.append(lbox)

	var nodes_container = Node2D.new()
	add_child(nodes_container)
	for i in range(steps.size()):
		var sprite_key: String = step_sprites.get(steps[i], "nodo_batalha")
		var base_tex = MapNodeArt.sprite(sprite_key)
		var node_px: Vector2 = base_tex.get_size() if base_tex != null else Vector2(64, 64)
		# Botão invisível só pra receber o clique/hover; o visual são os
		# sprites por cima (ignoram o mouse) — igual ao mapa real.
		var btn = Button.new()
		btn.text = ""
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.custom_minimum_size = node_px
		btn.size = node_px
		btn.position = _node_position(i) - node_px / 2.0
		btn.pressed.connect(_on_node_pressed.bind(steps[i]))
		btn.mouse_entered.connect(_on_node_hover.bind(i, true))
		btn.mouse_exited.connect(_on_node_hover.bind(i, false))
		nodes_container.add_child(btn)
		node_buttons.append(btn)
		var base = MapNodeArt.make_rect(base_tex)
		base.size = node_px
		btn.add_child(base)
		var ind = MapNodeArt.make_rect(MapNodeArt.sprite("ind_selecionado"))
		btn.add_child(ind)
		node_art.append({"base": base, "ind": ind})

	# Seta "PRÓXIMA LIÇÃO" (ajuda do tutorial; o jogo normal não tem).
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	# Peão do jogador — a MESMA peça (Dama branca) do mapa real — e a peça do
	# Guia, criados DEPOIS dos nós de propósito, pra desenharem por cima.
	player_pawn = MapPlayerPawn.new()
	player_pawn.piece_px = PAWN_SPRITE_PX * NODE_SPRITE_SCALE
	add_child(player_pawn)

	guide_map_piece = GuideFaceControl.new()
	guide_map_piece.setup(PAWN_SPRITE_PX * NODE_SPRITE_SCALE)
	guide_map_piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_map_piece.z_index = 31
	add_child(guide_map_piece)

	camera = Camera2D.new()
	camera.position = Vector2(0.0, roundf(_camera_target_y(_node_position(entry_index).y)))
	_cam_y = camera.position.y
	add_child(camera)
	camera.make_current()
	island_base.set_camera(camera)

	_pawn_index = entry_index
	_pawn_resting = true
	player_pawn.set_initial_position(_node_position(entry_index), TILE_SIZE)
	player_pawn.visible = false
	_place_guide(_guide_grid_for(entry_index))

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	# Cabeçalho fixo, num painel escuro pra continuar legível sobre o tabuleiro.
	top_panel = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_panel.position = Vector2(0, 0)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.82)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	top_panel.add_theme_stylebox_override("panel", sb)
	canvas.add_child(top_panel)
	top_panel.offset_top = 10.0
	# Cabeçalho (título/progresso/dica) removido: só reaparece com a dica de
	# "tentar de novo" depois de perder um duelo do tutorial.
	top_panel.visible = false

	var top_box = VBoxContainer.new()
	top_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_box.add_theme_constant_override("separation", 2)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(top_box)

	var title = Label.new()
	title.text = "TUTORIAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top_box.add_child(title)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
	top_box.add_child(progress_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	status_label.text = "Siga a trilha de baixo para cima. O nó com a seta é a sua próxima lição."
	top_box.add_child(status_label)

	var exit_btn = Button.new()
	exit_btn.text = "SAIR"
	exit_btn.custom_minimum_size = Vector2(180, 60)
	exit_btn.position = Vector2(24, 24)
	exit_btn.add_theme_font_size_override("font_size", 24)
	PixelUI.skin_button(exit_btn, Color(0.8, 0.3, 0.35), "", "icone_voltar")
	exit_btn.pressed.connect(_on_exit_pressed)
	canvas.add_child(exit_btn)

	guide_view = TutorialGuideView.new()
	add_child(guide_view)

func _process(delta: float) -> void:
	highlight_pulse += delta * 2.5
	if overlay:
		overlay.queue_redraw()

# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw_board() -> void:
	# Fora do tabuleiro: fundo escuro liso.
	BoardSkin.draw_frame(board_node, _board_origin, _board_rows, _board_cols, TILE_SIZE, Color.WHITE, BoardSkin.SKIN_TUTORIAL)
	BoardSkin.draw_tiles(board_node, _board_origin, _board_rows, _board_cols, TILE_SIZE, Color.WHITE, Color.WHITE, BoardSkin.SKIN_TUTORIAL)
	_draw_end_row()

# Última fileira: faixa dourada com coroas nas casas escuras.
func _draw_end_row() -> void:
	var gold = Color(1.0, 0.82, 0.25)
	var eg = _end_grid()
	var min_col = int(round((_board_origin.x + TILE_SIZE / 2.0) / TILE_SIZE))
	for k in range(_board_cols):
		var c = min_col + k
		var ctr = _grid_to_world(Vector2i(c, eg.y))
		var r = Rect2(ctr - Vector2(TILE_SIZE, TILE_SIZE) / 2.0, Vector2(TILE_SIZE, TILE_SIZE))
		var valid: bool = ((c + eg.y) % 2 + 2) % 2 == 1
		board_node.draw_rect(r, Color(gold.r, gold.g, gold.b, 0.22 if valid else 0.10))
		if valid:
			_draw_crown_icon(ctr, Color(gold.r, gold.g, gold.b, 0.5))
	var left = _board_origin.x
	var right = _board_origin.x + _board_cols * TILE_SIZE
	var top = _board_origin.y
	board_node.draw_line(Vector2(left, top), Vector2(right, top), Color(gold.r, gold.g, gold.b, 0.85), 3.0)
	board_node.draw_line(Vector2(left, top + TILE_SIZE), Vector2(right, top + TILE_SIZE), Color(gold.r, gold.g, gold.b, 0.85), 3.0)

func _draw_crown_icon(p: Vector2, col: Color) -> void:
	var s = TILE_SIZE / 64.0
	var pts = PackedVector2Array([p + Vector2(-14, 9) * s, p + Vector2(-14, -7) * s, p + Vector2(-7, 0) * s, p + Vector2(0, -11) * s, p + Vector2(7, 0) * s, p + Vector2(14, -7) * s, p + Vector2(14, 9) * s])
	board_node.draw_colored_polygon(pts, col)

func _draw_overlay() -> void:
	var current_index = steps.find(TutorialManager.current_step)
	if current_index < 1 or current_index >= steps.size() or _busy \
			or TutorialManager.current_step == TutorialManager.Step.FINISHED:
		return
	var font = ThemeDB.fallback_font
	var top = _node_position(current_index) + Vector2(0, -56)
	var bob = sin(highlight_pulse * 1.6) * 7.0
	var tip = top + Vector2(0, bob)
	overlay.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, -22), tip + Vector2(16, -22)]), Color(1.0, 0.85, 0.3))
	var txt = "PRÓXIMA LIÇÃO"
	var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	overlay.draw_string_outline(font, tip + Vector2(-w / 2.0, -32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, Color(0.04, 0.05, 0.08))
	overlay.draw_string(font, tip + Vector2(-w / 2.0, -32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.9, 0.5))

# ---------------------------------------------------------------------------
# Estado visual (mesmas regras de arte do mapa real)
# ---------------------------------------------------------------------------

func _on_node_hover(index: int, entered: bool) -> void:
	_hovered = index if entered else (-1 if _hovered == index else _hovered)
	_refresh_button_states()

func _refresh_button_states() -> void:
	var current_index = steps.find(TutorialManager.current_step)
	if progress_label != null:
		var done_lessons: int = clampi(current_index - 1, 0, TutorialManager.LESSON_COUNT)
		progress_label.text = "LIÇÕES CONCLUÍDAS  %d / %d" % [done_lessons, TutorialManager.LESSON_COUNT]
	for i in range(node_buttons.size()):
		var btn: Button = node_buttons[i]
		var art: Dictionary = node_art[i]
		var sprite_key: String = step_sprites.get(steps[i], "nodo_batalha")
		var sprite_name: String = sprite_key
		var ind_name := ""
		var overlay_name := ""
		var base_mod := Color.WHITE
		var label_col := Color.WHITE
		# Só o nó atual é clicável: perder um duelo permite tentar o mesmo nó de
		# novo, mas lições já concluídas (ex.: Loja) não podem ser repetidas.
		var clickable: bool = i > 0 and i == current_index and not _busy
		var with_pawn: bool = i == _pawn_index and _pawn_resting

		if i == _pawn_index:
			ind_name = "ind_atual"
		elif i == current_index:
			ind_name = "ind_selecionado" if i == _hovered else ""
		elif i < _pawn_index or (i == 0 and _pawn_index > 0):
			overlay_name = "ind_concluido"
			base_mod = Color(0.7, 0.66, 0.62)
			label_col = Color(0.75, 0.72, 0.7)
		elif i < current_index:
			# Visitado, mas o peão já saiu de lá (rever a lição).
			ind_name = "ind_selecionado" if i == _hovered else ""
		else:
			base_mod = Color(0.62, 0.6, 0.62)
			label_col = Color(0.6, 0.6, 0.65)

		if overlay_name != "":
			ind_name = overlay_name
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		(art["base"] as TextureRect).modulate = base_mod
		MapNodeArt.apply(btn, art["base"], art["ind"], sprite_key, sprite_name, ind_name, overlay_name, "", with_pawn)
		if i < lesson_labels.size():
			lesson_labels[i].add_theme_color_override("font_color", label_col if i > current_index else Color(0.9, 0.92, 0.98))
			lesson_labels[i].modulate = Color(1, 1, 1, 0.6) if i > current_index else Color.WHITE
	# Trilhas: percorrida / selecionada (saindo do nó atual) / normal.
	for i in range(trails.size()):
		if i + 1 <= current_index:
			trails[i].set_state("percorrido")
		elif i == current_index:
			trails[i].set_state("selecionado")
		else:
			trails[i].set_state("normal")

# ---------------------------------------------------------------------------
# Câmera
# ---------------------------------------------------------------------------

func _camera_target_y(target_y: float) -> float:
	var half_h = get_viewport_rect().size.y / 2.0
	var r: Rect2 = world_rect
	if island_base != null:
		r.size.y += island_base.extra_height()   # deixa a base rochosa à vista
	if r.size.y <= half_h * 2.0:
		return r.get_center().y
	return clampf(target_y, r.position.y + half_h, r.end.y - half_h)

# Câmera sempre em pixel inteiro (ver MapView._set_cam_y).
var _cam_y: float = 0.0
func _set_cam_y(v: float) -> void:
	_cam_y = v
	if camera != null:
		camera.position.y = roundf(v)

func _move_camera_to(world_y: float, duration: float = 0.85) -> void:
	if camera == null:
		return
	var tween = create_tween()
	tween.tween_method(_set_cam_y, _cam_y, _camera_target_y(world_y), duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# Peças: tudo anda pulando na diagonal
# ---------------------------------------------------------------------------

func _guide_world_pos(g: Vector2i) -> Vector2:
	return _grid_to_world(g) - guide_map_piece.custom_minimum_size / 2.0

func _place_guide(g: Vector2i) -> void:
	_guide_grid = g
	guide_map_piece.position = _guide_world_pos(g)

# O Guia pula casa por casa, na diagonal, até `target` (mesmo salto do peão).
func _guide_hops_to(target: Vector2i) -> void:
	if guide_map_piece == null:
		return
	var path: Array[Vector2i] = MapPlayerPawn.calculate_diagonal_path(_guide_grid, target)
	for next_tile in path:
		var from: Vector2 = guide_map_piece.position
		var to: Vector2 = _guide_world_pos(next_tile)
		var tw = create_tween()
		tw.tween_method(func(t: float):
			guide_map_piece.position = from.lerp(to, t) + Vector2(0.0, -sin(t * PI) * HOP_ARC), 0.0, 1.0, HOP_TIME)
		await tw.finished
		guide_map_piece.position = to
		_guide_grid = next_tile
		await get_tree().create_timer(HOP_PAUSE).timeout

# Final acidental: a peça do Guia segue sozinha pra frente, pulando na diagonal
# até a última fileira do mapa (é lá que ele vai ser coroado sem querer).
func _guide_walks_ahead() -> void:
	top_panel.visible = false  # libera a vista da última fileira
	_move_camera_to(_end_row_pos().y, 1.4)
	await _guide_hops_to(_end_grid())
	await get_tree().create_timer(0.3).timeout

# Cutscene final: o Irmão desce até a peça do jogador e PULA POR CIMA dela, como
# uma captura de damas. A peça se estilhaça (mesmo efeito da captura nos duelos).
func _brother_captures_player() -> void:
	if guide_map_piece == null or player_pawn == null:
		return
	guide_map_piece.set_who("evil")
	overlay.visible = false   # some a seta "PRÓXIMA LIÇÃO"
	guide_map_piece.pivot_offset = guide_map_piece.custom_minimum_size / 2.0
	var g: Vector2i = _node_grid(_pawn_index)
	var pawn_pos: Vector2 = _node_position(_pawn_index)
	# a peça do jogador sai do soquete e fica à vista
	_pawn_resting = false
	_refresh_button_states()
	player_pawn.set_initial_position(pawn_pos, TILE_SIZE)
	player_pawn.position = pawn_pos
	player_pawn.visible = true
	_move_camera_to(pawn_pos.y, 1.0)
	await get_tree().create_timer(1.1).timeout
	# desce até a casa diagonal logo acima da peça
	await _guide_hops_to(Vector2i(g.x + 1, g.y - 1))
	# pausa ameaçadora: treme, o mundo prende a respiração
	var tremor_t := 0.0
	var base_pos: Vector2 = guide_map_piece.position
	while tremor_t < 0.9:
		await get_tree().process_frame
		tremor_t += get_process_delta_time()
		guide_map_piece.position = base_pos + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.0 + 4.0 * tremor_t)
	guide_map_piece.position = base_pos
	# o salto por cima: sobe alto, passa sobre a peça (captura) e pousa do outro lado
	var land := Vector2i(g.x - 1, g.y + 1)
	var from: Vector2 = guide_map_piece.position
	var to: Vector2 = _guide_world_pos(land)
	var shattered: Array = [false]
	Sfx.play("salto")
	var tw := create_tween()
	tw.tween_method(func(t: float):
		guide_map_piece.position = from.lerp(to, t) + Vector2(0.0, -sin(t * PI) * HOP_ARC * 4.0)
		var sc: float = 1.0 + 0.55 * sin(t * PI)
		guide_map_piece.scale = Vector2(sc, sc)
		if t >= 0.5 and not shattered[0]:
			shattered[0] = true
			_shatter_player_piece(pawn_pos), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	await tw.finished
	guide_map_piece.position = to
	guide_map_piece.scale = Vector2.ONE
	_guide_grid = land
	Sfx.play("irmao_impacto")
	_shake_camera(10.0, 0.4)
	await get_tree().create_timer(1.8).timeout

func _shatter_player_piece(world_pos: Vector2) -> void:
	player_pawn.visible = false
	var shatter := PieceShatterView.new()
	add_child(shatter)
	shatter.shatter_piece(world_pos, player_pawn.dummy_piece, player_pawn.piece_px / 0.85)
	Sfx.play("captura")
	_shake_camera(18.0, 0.55)

func _shake_camera(amp: float, dur: float) -> void:
	if camera == null:
		return
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(camera):
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp * (1.0 - k), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(camera):
			camera.offset = Vector2.ZERO)

func _move_pawn_to_current_step(animate: bool) -> void:
	var current_index = steps.find(TutorialManager.current_step)
	if current_index == -1 or player_pawn == null:
		return
	var target = _node_position(current_index)
	if not animate:
		player_pawn.set_initial_position(target, TILE_SIZE)
		player_pawn.visible = false
		_pawn_index = current_index
		_pawn_resting = true
		_place_guide(_guide_grid_for(current_index))
		_refresh_button_states()
		return
	# O peão sai do soquete e pula (como no mapa real); o Guia vai junto.
	player_pawn.position = _node_position(_pawn_index)
	player_pawn.set_initial_position(_node_position(_pawn_index), TILE_SIZE)
	player_pawn.visible = true
	_pawn_resting = false
	_refresh_button_states()
	_move_camera_to(target.y)
	_guide_hops_to(_guide_grid_for(current_index))
	# Ao tocar o nodo, já mostra a peça encaixada no soquete (sem quadro avulso).
	player_pawn.landed.connect(func():
		player_pawn.visible = false
		_pawn_index = current_index
		_pawn_resting = true
		_refresh_button_states(), CONNECT_ONE_SHOT)
	await player_pawn.jump_to_node(target, TILE_SIZE)
	player_pawn.visible = false
	_pawn_index = current_index
	_pawn_resting = true
	_refresh_button_states()

func _on_node_pressed(step: int) -> void:
	_busy = true
	for btn in node_buttons:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	TutorialManager.advance_to(step)

	var target_index = steps.find(step)
	if target_index != -1:
		await _move_pawn_to_current_step(true)

	match step:
		TutorialManager.Step.DUEL_1_BASICS, TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			# A fala de introdução desse duelo acontece DENTRO da
			# batalha agora (ver main.gd), não mais aqui no mapa —
			# assim o jogo já "começa" com o Guia falando, em vez de
			# uma conversa solta antes de trocar de cena.
			SceneTransition.go(DUEL_SCENE_PATH)
		TutorialManager.Step.SHOP:
			TutorialManager.last_duel_won = true
			await guide_view.play_sequence(TutorialManager.get_shop_intro_lines())
			SceneTransition.go(SHOP_SCENE_PATH)
		TutorialManager.Step.BET:
			TutorialManager.last_duel_won = true
			SceneTransition.go(BET_SCENE_PATH)

func _on_exit_pressed() -> void:
	TutorialManager.end_tutorial()
	SceneTransition.go(MAIN_MENU_PATH)
