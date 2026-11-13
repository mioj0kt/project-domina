class_name MapView
extends Node2D

# Configurações do Tabuleiro (casa = 26px nativos × MAP_SPRITE_SCALE)
const MAP_SPRITE_SCALE: int = 3
const TILE_SIZE: float = 26.0 * MAP_SPRITE_SCALE
const CAMERA_ZOOM: float = 1.0
# Nodos/indicadores/peão: ampliação própria (menor que a do cenário). O peão
# usa o sprite 32px na MESMA escala, então encaixa 1:1 no furo do soquete.
const NODE_SPRITE_SCALE: int = MapNodeArt.NODE_SPRITE_SCALE
const PAWN_SPRITE_PX: float = 32.0
const FOREST_MARGIN_COLS: int = 2

const TILES_PER_LAYER: int = 5
const TILES_BETWEEN_NODES: int = 3

@export_group("Linhas")
@export var default_line_color: Color = Color(0.3, 0.35, 0.45, 0.7)
@export var active_line_color: Color = Color(1.0, 0.84, 0.2, 1.0)
@export var active_line_width: float = 6.0

@onready var lines_container = $LinesContainer
@onready var nodes_container = $NodesContainer
@onready var camera: Camera2D = $Camera2D

var generator = MapGenerator.new()
var node_buttons: Dictionary = {}
var node_size_labels: Dictionary = {}
var node_layout_labels: Dictionary = {}
var lines_dictionary: Dictionary = {}

var forest: ForestBackground
var island_base: IslandBase
var player_pawn: MapPlayerPawn
# Altura "real" da câmera (fracionária, para o arrasto/rolagem suaves); a câmera
# em si fica sempre num pixel inteiro. Com a câmera entre dois pixels, a arte
# ampliada sai com pixels de largura desigual (um lado do soquete parecia ter um
# vão escuro e o peão parecia fora do centro).
var _cam_y: float = 0.0
# Nó onde o peão está parado. Parado, o peão NÃO é desenhado à parte: ele já
# vem "assado" no próprio sprite do soquete (ver _socket_with_pawn), então
# o encaixe é exato em qualquer resolução/escala de janela. Só durante o
# salto o peão avulso aparece.
var pawn_rest_node: MapNode = null
var covers: Dictionary = {}          # MapNode -> MapCover (Mina: nodos escondidos)
var caves: Array = []                # MapCover (grutas, sem repetição)
var sky_bg: SpaceBackground = null
var _travel_target: MapNode = null
var _travel_from: MapNode = null
var is_traveling: bool = false

# Rolagem manual do mapa (roda do mouse, setas/W/S, arrastar, touchpad).
const SCROLL_STEP: float = 110.0
const SCROLL_KEY_SPEED: float = 700.0
var _cam_tween: Tween = null
var _drag_scroll: bool = false      # arrastando com botão do meio/direito
var _lmb_down: bool = false         # botão esquerdo pressionado em área arrastável
var _lmb_origin: Vector2 = Vector2.ZERO
var _lmb_dragging: bool = false     # passou do limiar: é arrasto, não clique
var _drag_end_msec: int = 0
const DRAG_THRESHOLD: float = 8.0

var inventory_ui: InventoryUI
var hud_bar: HUDBar

func _ready() -> void:
	randomize()
	z_index = 0
	Music.play(_current_biome() if Music.TRACKS.has(_current_biome()) else "")
	MetaProgress.mark_biome_visited(_current_biome())   # antes do céu: as ilhas dele já aparecem
	var sky := SpaceBackground.new()   # céu estrelado atrás do mapa
	sky.floater_alpha = 0.55           # ilhas/peças discretas (há texto por cima)
	sky.biome = _current_biome()
	add_child(sky)
	sky_bg = sky
	_setup_map_ui()
	_setup_player_pawn()

	if camera != null:
		camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)

	if RunManager.map_data.is_empty():
		generator.biome = _current_biome()
		RunManager.map_data = generator.generate_map()
		_position_nodes(RunManager.map_data)
		if _current_biome() == "mina":
			_assign_covers(RunManager.map_data)
		if _current_biome() == "deserto":
			_assign_storms(RunManager.map_data)
		if not RunManager.map_data.is_empty() and not RunManager.map_data[0].is_empty():
			RunManager.current_node = RunManager.map_data[0][0]

	_build_forest(RunManager.map_data)
	_draw_lines(RunManager.map_data)
	_instantiate_node_ui(RunManager.map_data)
	_build_covers(RunManager.map_data)
	_build_storms(RunManager.map_data)
	_restore_visited_connections()

	if RunManager.current_node != null:
		player_pawn.set_initial_position(RunManager.current_node.position, TILE_SIZE)
		pawn_rest_node = RunManager.current_node
		player_pawn.visible = false
		_set_current_node(RunManager.current_node, false)

	if DebugFlags.SHORTCUTS:
		_build_debug_hint()
	if RunManager.run_intro_pending:
		RunManager.run_intro_pending = false
		_play_run_intro()
	elif RunManager.biome_intro_pending:
		RunManager.biome_intro_pending = false
		_show_biome_title()

# Início da run: tela preta, a peça volta aos pedaços e se encaixa no nodo
# inicial com impacto; então o mapa surge com ela já no lugar (RunIntro).
func _play_run_intro() -> void:
	if RunManager.current_node == null or camera == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_set_cam_y(_camera_target_y(RunManager.current_node.position.y))
	await RunIntro.new().run(self, camera, RunManager.current_node.position, player_pawn.piece_px)
	if RunManager.biome_intro_pending:
		RunManager.biome_intro_pending = false
		_show_biome_title()

func _setup_player_pawn() -> void:
	player_pawn = MapPlayerPawn.new()
	player_pawn.piece_px = PAWN_SPRITE_PX * NODE_SPRITE_SCALE
	add_child(player_pawn)

func _setup_map_ui() -> void:
	# Instancia a barra lateral padronizada
	hud_bar = HUDBar.new()
	add_child(hud_bar)
	hud_bar.open_laws_requested.connect(toggle_inventory)
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	# Grimório de Leis (inventário)
	var canvas = CanvasLayer.new()
	canvas.name = "MapInventoryLayer"
	canvas.layer = 110
	add_child(canvas)

	inventory_ui = InventoryUI.new()
	canvas.add_child(inventory_ui)
	inventory_ui.setup()

	hud_bar.refresh_cards_inventory_count()

func toggle_inventory() -> void:
	if inventory_ui:
		inventory_ui.toggle_visibility()

func _input(event: InputEvent) -> void:
	if is_traveling:
		return
	if _handle_scroll_input(event):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_I:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
				get_viewport().set_input_as_handled()
		elif DebugFlags.SHORTCUTS and event.keycode == KEY_B:
			# DEBUG: acesso direto à mesa de apostas, sem precisar achar o
			# nó no mapa — só pra facilitar teste, não é um atalho pro
			# jogo normal.
			is_traveling = true
			SceneTransition.go("res://scenes/bet_view.tscn")
			get_viewport().set_input_as_handled()
		elif DebugFlags.SHORTCUTS and event.keycode == KEY_E:
			# DEBUG: acesso direto a um evento "?" (mesma ideia da tecla B).
			is_traveling = true
			SceneTransition.go("res://scenes/event_view.tscn")
			get_viewport().set_input_as_handled()
		elif DebugFlags.SHORTCUTS and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			# DEBUG: abre um duelo de CHEFE direto, com a lei escolhida
			# (1 Sapo, 2 Coruja, 3 Floresta, 4 Cipós, 5 Vaga-lumes, 6 Raízes).
			var law_idx: int = event.keycode - KEY_1
			var desert: bool = _current_biome() == "deserto"
			var mine: bool = _current_biome() == "mina"
			var law_count: int = DuelBossDesert.DESERT_LAWS.size() if desert else (DuelBossMine.MINE_LAWS.size() if mine else DuelBoss.LAWS.size())
			if law_idx < law_count:
				# No deserto: 1 Sol, 2 Tempestade, 3 Areia Movediça, 4 Ampulheta, 5 Sarcófagos, 6 Cactos.
				# Na mina: 1 Lampião, 2 Ricochete, 3 Desabamento, 4 Trilhos, 5 Garimpo.
				if desert:
					RunManager.map_biome = "deserto"
					RunManager.desert_boss_law_id = DuelBossDesert.DESERT_LAWS[law_idx]
				elif mine:
					RunManager.map_biome = "mina"
					RunManager.mine_boss_law_id = DuelBossMine.MINE_LAWS[law_idx]
				else:
					RunManager.forest_boss_law_id = DuelBoss.LAWS[law_idx]
				RunManager.current_node_type = MapNode.NodeType.Chefe
				RunManager.current_board_size = Vector2i(10, 10)
				RunManager.current_board_layout = Board.LAYOUT_CLASSIC
				is_traveling = true
				SceneTransition.go("res://scenes/main.tscn")
				get_viewport().set_input_as_handled()

# DEBUG: lembrete das teclas de atalho do mapa (só com DebugFlags.SHORTCUTS).
func _build_debug_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var lbl := Label.new()
	var laws: String
	match _current_biome():
		"deserto":
			laws = "1 Sol  2 Tempestade  3 Areia Movediça  4 Ampulheta  5 Sarcófagos  6 Cactos"
		"mina":
			laws = "1 Lampião  2 Ricochete  3 Desabamento  4 Trilhos  5 Garimpo"
		_:
			laws = "1 Sapo  2 Coruja  3 Floresta  4 Cipós  5 Vaga-lumes  6 Raízes"
	lbl.text = "DEBUG  CHEFE: " + laws + "   |   B Apostas   E Evento"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(16, 8)
	layer.add_child(lbl)

func _position_nodes(layers: Array[Array]) -> void:
	# O sorteio de deslocamento horizontal pode deixar dois nós ligados longe
	# demais pra a trilha (só 5 casas de altura, diagonais de 1 casa) chegar:
	# ela terminava no vazio. Sorteia de novo até todas as ligações alcançarem;
	# se falhar (raro), usa o layout sem deslocamento.
	for attempt in range(40):
		_place_nodes(layers, attempt < 39)
		if _all_trails_reach(layers):
			return
	_place_nodes(layers, false)

func _place_nodes(layers: Array[Array], random_shift: bool) -> void:
	for layer_index in range(layers.size()):
		var layer = layers[layer_index]
		var total_nodes = layer.size()
		var grid_row = -layer_index * TILES_PER_LAYER
		var start_col = -int((total_nodes - 1) * TILES_BETWEEN_NODES / 2.0)
		# Espalha melhor: camadas mais estreitas que o máximo deslizam 1 casa
		# para a esquerda/direita (começo e chefe ficam no centro), então o mapa
		# não vira uma coluna simétrica.
		if random_shift and total_nodes > 1 and total_nodes < 4:
			start_col += [-1, 0, 1].pick_random()

		for node_index in range(total_nodes):
			var node: MapNode = layer[node_index]
			var grid_col = start_col + (node_index * TILES_BETWEEN_NODES)

			if (grid_row + grid_col) % 2 == 0:
				grid_col += 1

			node.position = Vector2(grid_col * TILE_SIZE, grid_row * TILE_SIZE)

# A trilha sobe TILES_PER_LAYER casas e anda no máximo 1 coluna por casa.
func _all_trails_reach(layers: Array[Array]) -> bool:
	for layer in layers:
		for node in layer:
			for child in node.children:
				var dx: int = absi(int(round((child.position.x - node.position.x) / TILE_SIZE)))
				if dx > TILES_PER_LAYER:
					return false
	return true

func _build_forest(layers: Array[Array]) -> void:
	var min_c := 0
	var max_c := 0
	var min_r := 0
	var max_r := 0
	for layer in layers:
		for node in layer:
			var c = int(round(node.position.x / TILE_SIZE))
			var r = int(round(node.position.y / TILE_SIZE))
			min_c = mini(min_c, c)
			max_c = maxi(max_c, c)
			min_r = mini(min_r, r)
			max_r = maxi(max_r, r)
	var half = maxi(4, maxi(-min_c, max_c) + FOREST_MARGIN_COLS)
	forest = ForestBackground.new()
	forest.biome = _current_biome()
	forest.name = "ForestBackground"
	add_child(forest)
	move_child(forest, 0)
	# Uma coluna a menos de cada lado (antes: só do direito), então a largura
	# fica simétrica em torno do centro; a câmera acompanha o centro do tabuleiro.
	forest.build(layers, TILE_SIZE, MAP_SPRITE_SCALE, -half + 1, half - 1, min_r - 2, max_r + 2)
	if camera != null:
		camera.position.x = roundf(forest.world_rect.get_center().x)
	# Base rochosa: o mapa é uma ilha flutuando no espaço (atrás do tabuleiro).
	island_base = IslandBase.new()
	island_base.name = "IslandBase"
	island_base.biome = _current_biome()
	add_child(island_base)
	move_child(island_base, 0)
	island_base.build(forest.world_rect, MAP_SPRITE_SCALE, camera)

# Título do bioma ao entrar nele: surge, fica um instante e some.
func _show_biome_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 130
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	layer.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 150)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var title := Label.new()
	title.text = String(RunManager.BIOME_TITLES.get(_current_biome(), ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	# Cores por bioma: texto claro + contorno grosso escuro da mesma família.
	var desert: bool = _current_biome() == "deserto"
	var mine: bool = _current_biome() == "mina"
	var fill: Color = Color("#f6d98a") if desert else Color("#b9e28a")
	var edge: Color = Color("#5a2a10") if desert else Color("#10301a")
	if mine:
		fill = Color("#d9c9ff")
		edge = Color("#2a1a4a")
	title.add_theme_color_override("font_color", fill)
	title.add_theme_color_override("font_outline_color", edge)
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.7)
	tw.tween_interval(1.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.9)
	tw.tween_callback(layer.queue_free)

func _current_biome() -> String:
	var b: String = DebugFlags.MAP_BIOME_OVERRIDE if DebugFlags.MAP_BIOME_OVERRIDE != "" else RunManager.map_biome
	return b if ForestBackground.THEMES.has(b) else "floresta"

func _draw_lines(layers: Array[Array]) -> void:
	for layer in layers:
		for node in layer:
			for child in node.children:
				var trail = ForestTrail.new()
				trail.biome = _current_biome()
				trail.setup(node.position, child.position, MAP_SPRITE_SCALE)
				lines_container.add_child(trail)
				lines_dictionary[_get_connection_key(node, child)] = trail
	_refresh_lines()

# Estado visual de cada caminho: percorrido / selecionado (saindo do nó
# atual) / bloqueado (ramo que ficou pra trás sem ser percorrido) / normal.
func _refresh_lines() -> void:
	var current: MapNode = RunManager.current_node
	var selected_lines: Array[ForestTrail] = []
	var visited_lines: Array[ForestTrail] = []
	for layer in RunManager.map_data:
		for node in layer:
			for child in node.children:
				var key = _get_connection_key(node, child)
				var line: ForestTrail = lines_dictionary.get(key)
				if line == null:
					continue
				var state = "normal"
				if RunManager.visited_connections.has(key):
					state = "percorrido"
				elif current != null and node == current:
					state = "selecionado"
				elif current != null and node.id.x <= current.id.x:
					state = "bloqueado"
				line.set_state(state)
				# Trilhas que se sobrepõem: disponível/percorrida desenha por cima
				# da bloqueada/normal (ordem dentro do LinesContainer, que fica
				# sempre abaixo dos nodos — nada de z_index).
				if state == "selecionado":
					selected_lines.append(line)
				elif state == "percorrido":
					visited_lines.append(line)
	for l in visited_lines:
		lines_container.move_child(l, -1)
	for l in selected_lines:
		lines_container.move_child(l, -1)

func _restore_visited_connections() -> void:
	_refresh_lines()

func _get_connection_key(parent: MapNode, child: MapNode) -> String:
	return str(parent.id) + "->" + str(child.id)

const _NODE_SPRITES: Dictionary = {
	MapNode.NodeType.Começo: "nodo_inicio",
	MapNode.NodeType.Duelo: "nodo_espadas",
	MapNode.NodeType.DueloForte: "nodo_elite",
	MapNode.NodeType.Chefe: "nodo_boss",
	MapNode.NodeType.Loja: "nodo_loja",
	MapNode.NodeType.Evento: "nodo_evento",
	MapNode.NodeType.Aposta: "nodo_aposta",
	MapNode.NodeType.Altar: "nodo_lei",
	MapNode.NodeType.Arcano: "nodo_carta",   # sem a arte ainda, cai no "nodo_lei"
}

# Nome do sprite do soquete do nó; se o arquivo ainda não existe, usa o do Altar.
func _node_sprite_name(type: int) -> String:
	var n: String = _NODE_SPRITES.get(type, "nodo_batalha")
	if not ResourceLoader.exists(MapNodeArt.MAP_SPRITE_DIR + n + ".png"):
		return "nodo_lei"
	return n

var node_art: Dictionary = {}        # MapNode -> {"base": TextureRect, "ind": TextureRect}
var _hovered_node: MapNode = null

func _map_sprite(file: String) -> Texture2D:
	return MapNodeArt.sprite(file)

func _make_map_rect(tex: Texture2D) -> TextureRect:
	return MapNodeArt.make_rect(tex)

func _instantiate_node_ui(layers: Array[Array]) -> void:
	for layer in layers:
		for node in layer:
			var is_boss = node.type == MapNode.NodeType.Chefe
			var base_tex = _map_sprite(_node_sprite_name(node.type))
			var node_px: Vector2 = base_tex.get_size() if base_tex != null else Vector2(64, 64)

			# Botão invisível só pra receber o clique/hover; o visual são
			# os sprites por cima (ignoram o mouse).
			var btn = Button.new()
			btn.text = ""
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			btn.custom_minimum_size = node_px
			btn.size = node_px
			btn.position = node.position - (btn.size / 2.0)
			btn.pressed.connect(_on_node_clicked.bind(node))
			Juice.hover_pop(btn, 1.12, 0.92)   # só nós clicáveis recebem mouse
			btn.mouse_entered.connect(_on_node_hover.bind(node, true))
			btn.mouse_exited.connect(_on_node_hover.bind(node, false))
			nodes_container.add_child(btn)
			node_buttons[node] = btn

			var base = _make_map_rect(base_tex)
			base.size = node_px
			btn.add_child(base)

			# Indicador (anel/cadeado/check) centralizado no nó.
			var ind = _make_map_rect(_map_sprite("ind_selecionado_boss" if is_boss else "ind_selecionado"))
			btn.add_child(ind)

			node_art[node] = {"base": base, "ind": ind}

			# Só duelos mostram o tamanho do tabuleiro, logo abaixo do nó.
			if node.type in [MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte, MapNode.NodeType.Chefe]:
				var size_label = Label.new()
				size_label.text = node.get_size_text()
				size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				size_label.add_theme_font_size_override("font_size", 32)
				size_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
				size_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
				size_label.add_theme_constant_override("outline_size", 7)
				size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				size_label.size = Vector2(node_px.x, 40)
				size_label.position = Vector2(0, node_px.y + 6)
				btn.add_child(size_label)
				node_size_labels[node] = size_label
				# Disposição especial: nome pequeno logo abaixo do tamanho.
				if node.has_special_layout():
					var layout_label = Label.new()
					layout_label.text = node.get_layout_text()
					layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					layout_label.add_theme_font_size_override("font_size", 24)
					layout_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
					layout_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
					layout_label.add_theme_constant_override("outline_size", 6)
					layout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
					layout_label.size = Vector2(node_px.x, 30)
					layout_label.position = Vector2(0, 36)
					size_label.add_child(layout_label)
					node_layout_labels[node] = layout_label

# Mina dos Cristais: sorteia grutas (no máximo 3 por mapa). Cada gruta cobre um
# nodo e, às vezes, também um filho dele (ligados por um túnel); nodos que ficam
# debaixo do teto entram na gruta também ("de carona"). Nunca o começo nem o chefe.
const COVER_CHANCE: float = 0.5
const COVER_MAX: int = 3
const COVER_TWO_CHANCE: float = 0.5
func _assign_covers(layers: Array[Array]) -> void:
	var caves_made: int = 0
	var next_id: int = 0
	var used_pts: Array = []          # centros das grutas já feitas (para não encostarem)
	for li in range(1, layers.size() - 1):
		if caves_made >= COVER_MAX:
			return
		var layer: Array = layers[li]
		if layer.size() < 2 or randf() > COVER_CHANCE:
			continue
		var a: MapNode = layer.pick_random()
		if a.cave_id >= 0:
			continue
		var group: Array[MapNode] = [a]
		var edge: bool = false
		if li + 1 <= layers.size() - 2 and randf() < COVER_TWO_CHANCE:
			var kids: Array = a.children.filter(func(k: MapNode): return k.cave_id < 0)
			if not kids.is_empty():
				group.append(kids.pick_random())
				edge = true
		# Nodos debaixo do teto entram de carona; o começo/chefe ou excesso cancelam.
		var pts: Array = []
		for g in group:
			pts.append(g.position)
		var ok: bool = true
		for lj in range(layers.size()):
			for other in layers[lj]:
				if other in group:
					continue
				if MapCover.mask_value(other.position, pts, edge) <= 1.05:
					if lj == 0 or lj == layers.size() - 1 or other.cave_id >= 0:
						ok = false
					else:
						group.append(other)
		for up in used_pts:
			for q in pts:
				if MapCover.mask_value(q, [up], false) <= 2.6:
					ok = false
		if not ok or group.size() > MapCover.MAX_MEMBERS:
			continue
		for i in range(group.size()):
			group[i].covered = true
			group[i].cave_id = next_id
			group[i].cave_order = i
			group[i].cave_edge = edge
		used_pts.append(group[0].position)
		next_id += 1
		caves_made += 1

# ---------------------------------------------------- tempestades de areia (Deserto) ----
const STORM_CHANCE: float = 0.55      # chance por fileira de nascer uma tempestade
const STORM_MAX: int = 2
var storms: Array = []

func _is_duel(n: MapNode) -> bool:
	return n.type == MapNode.NodeType.Duelo or n.type == MapNode.NodeType.DueloForte

# Sorteia as tempestades: cada uma é uma RAJADA que atravessa uma fileira inteira do mapa.
# Todos os duelos da fileira ficam dentro dela; os outros nodos da fileira ficam de fora
# (a areia se abre em volta deles). Fileiras vizinhas nunca têm rajada as duas.
func _assign_storms(layers: Array[Array]) -> void:
	var made: int = 0
	var last_li: int = -9
	for li in range(1, layers.size() - 1):
		if made >= STORM_MAX:
			return
		if li - last_li < 2 or randf() > STORM_CHANCE:
			continue
		var duels: Array = layers[li].filter(func(n: MapNode): return _is_duel(n))
		if duels.is_empty():
			continue
		for g in duels:
			g.storm = true
			g.storm_id = made
		last_li = li
		made += 1

func _build_storms(layers: Array[Array]) -> void:
	var cx: float = forest._board_rect.get_center().x if forest != null else 0.0
	for layer in layers:
		var duels: Array = layer.filter(func(n: MapNode): return n.storm and n.storm_id >= 0)
		if duels.is_empty():
			continue
		var others: Array = layer.filter(func(n: MapNode): return not n.storm)
		var gid: int = duels[0].storm_id
		var st := MapStorm.new()
		add_child(st)
		st.setup(duels.map(func(n: MapNode): return n.position), others.map(func(n: MapNode): return n.position), cx, 1.0 if gid % 2 == 0 else -1.0, gid * 977 + 13)
		st.set_meta("nodes", duels)
		storms.append(st)

func _update_storms() -> void:
	for st in storms:
		if st == null or not is_instance_valid(st):
			continue
		var nodes: Array = st.get_meta("nodes")
		st.set_focus(RunManager.current_node in nodes or _travel_target in nodes)

func _build_covers(layers: Array[Array]) -> void:
	var groups: Dictionary = {}
	for layer in layers:
		for node in layer:
			if node.covered and node.cave_id >= 0:
				if not groups.has(node.cave_id):
					groups[node.cave_id] = []
				groups[node.cave_id].append(node)
	for gid in groups:
		var nodes: Array = groups[gid]
		nodes.sort_custom(func(x: MapNode, y: MapNode): return x.cave_order < y.cave_order)
		var pts: Array = []
		var done: Array = []
		for n in nodes:
			pts.append(n.position)
			done.append(n.revealed)
		var cv := MapCover.new()
		add_child(cv)
		if forest != null:
			cv.board_rect = forest._board_rect
		for gid2 in groups:
			if gid2 != gid:
				var ns: Array = groups[gid2].duplicate()
				ns.sort_custom(func(x: MapNode, y: MapNode): return x.cave_order < y.cave_order)
				var npts: Array = []
				for n3 in ns:
					npts.append(n3.position)
				cv.neighbors.append({"pts": npts, "edge": ns[0].cave_edge, "seed": int(gid2) * 131 + 5 + int(ns[0].id.x) * 17})
		var others: Array = []
		var paths: Array = []
		for l2 in layers:
			for n2 in l2:
				if not (n2 in nodes):
					others.append(n2.position)
				for ch in n2.children:
					var fg := Vector2i((n2.position / TILE_SIZE).round())
					var tg := Vector2i((ch.position / TILE_SIZE).round())
					var cells: Array = [fg]
					var gcur: Vector2i = fg
					for st in ForestTrail.build_steps(fg, tg):
						gcur += st
						cells.append(gcur)
					paths.append(cells)
		# Caminho que a PEÇA faz (sempre em diagonal) ao entrar e sair: as bocas ficam nele.
		var all_cave_nodes: Array = []
		for gid3 in groups:
			all_cave_nodes.append_array(groups[gid3])
		for n4 in all_cave_nodes:
			var ng := Vector2i((n4.position / TILE_SIZE).round())
			for l3 in layers:
				for n5 in l3:
					if n4 in n5.children:
						var pg := Vector2i((n5.position / TILE_SIZE).round())
						var pc: Array = [pg]
						pc.append_array(MapPlayerPawn.calculate_diagonal_path(pg, ng))
						cv.pawn_paths.append(pc)
			for ch2 in n4.children:
				var cg := Vector2i((ch2.position / TILE_SIZE).round())
				var pc2: Array = [ng]
				pc2.append_array(MapPlayerPawn.calculate_diagonal_path(ng, cg))
				cv.pawn_paths.append(pc2)
		cv.setup(pts, nodes[0].cave_edge, done, int(gid) * 131 + 5 + int(nodes[0].id.x) * 17, others, paths)
		cv.set_meta("nodes", nodes)
		cv.hovered.connect(func(i: int, on: bool): _on_node_hover(nodes[i], on))
		cv.clicked.connect(func(i: int): _on_node_clicked(nodes[i]))
		caves.append(cv)
		for n in nodes:
			covers[n] = cv
		for ri in range(nodes.size()):
			cv.set_reachable(ri, RunManager.current_node != null and (nodes[ri] in RunManager.current_node.children or nodes[ri] == RunManager.current_node))

func _cave_index(cv, node: MapNode) -> int:
	var nodes: Array = cv.get_meta("nodes")
	return nodes.find(node)

func _update_covers() -> void:
	if caves.is_empty() or player_pawn == null:
		return
	var glow: float = 0.0
	var ext_r: float = 0.0
	var ext_wp := Vector2.ZERO
	for cv in caves:
		if cv == null or not is_instance_valid(cv):
			continue
		var nodes: Array = cv.get_meta("nodes")
		var cur: MapNode = RunManager.current_node
		var active: bool = false
		for n in nodes:
			if n == _travel_target or n == _travel_from or (n == cur and n.revealed):
				active = true
		var wp: Vector2 = player_pawn.position
		if not player_pawn.visible:
			wp = cur.position if cur != null else nodes[0].position
		cv.update_spot(wp, active)
		if active and cv.spot_r > ext_r:
			ext_r = cv.spot_r
			ext_wp = wp
		# Caminhos que saem da gruta ficam iluminados (o exterior escurece).
		var exits: Array = []
		if active and cur != null and cur in nodes:
			for k in cur.children:
				if not (k in nodes):
					exits.append([cur.position, k.position])
		cv.set_exits(exits)
		glow = maxf(glow, cv.lit)
	# O foco de uma gruta também abre o teto das vizinhas coladas nela.
	if ext_r > 0.0:
		for cv2 in caves:
			if cv2 != null and is_instance_valid(cv2) and cv2.spot_r <= 0.0:
				cv2.ext_spot(ext_wp, ext_r)
	if sky_bg != null and is_instance_valid(sky_bg):
		sky_bg.cave_glow = glow

func _on_node_hover(node: MapNode, entered: bool) -> void:
	if covers.has(node) and is_instance_valid(covers[node]):
		var cv = covers[node]
		cv.set_hover(entered and RunManager.current_node != null and node in RunManager.current_node.children, _cave_index(cv, node))
	_hovered_node = node if entered else (null if _hovered_node == node else _hovered_node)
	_update_nodes_visual_state()

func _is_node_completed(node: MapNode) -> bool:
	if node == RunManager.current_node:
		return false
	for layer in RunManager.map_data:
		for other in layer:
			for child in other.children:
				if (other == node or child == node) and RunManager.visited_connections.has(_get_connection_key(other, child)):
					return true
	return false

func _set_current_node(node: MapNode, animate_line: bool = true) -> void:
	if RunManager.current_node and RunManager.current_node != node:
		var key = _get_connection_key(RunManager.current_node, node)
		if not RunManager.visited_connections.has(key):
			RunManager.visited_connections.append(key)
		if animate_line:
			_highlight_connection(RunManager.current_node, node)

	RunManager.current_node = node
	_update_nodes_visual_state()
	_move_camera_to_node(node)

func _update_nodes_visual_state() -> void:
	for node in node_buttons:
		var btn: Button = node_buttons[node]
		var art: Dictionary = node_art[node]
		var base: TextureRect = art["base"]
		var ind: TextureRect = art["ind"]
		var size_label: Label = node_size_labels.get(node)
		var boss_suffix = "_boss" if node.type == MapNode.NodeType.Chefe else ""
		var sprite_name: String = _node_sprite_name(node.type)
		var ind_name = ""
		var base_mod = Color.WHITE
		var label_col = Color(1.0, 0.92, 0.7)

		# Nodos "de encaixe": o peão do jogador assenta no soquete do nó atual.
		# Concluído = soquete com o símbolo apagado + check; caminho que ficou
		# pra trás = soquete vazio, sem cor, com cadeado; os demais seguem
		# com o símbolo escurecido até ficarem alcançáveis.
		var overlay_name = ""
		if node == RunManager.current_node:
			ind_name = "ind_atual"
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif RunManager.current_node and node in RunManager.current_node.children:
			ind_name = "ind_selecionado" if node == _hovered_node else ""
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
		elif _is_node_completed(node):
			overlay_name = "ind_concluido"
			base_mod = Color(0.7, 0.66, 0.62)
			label_col = Color(0.6, 0.55, 0.5)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif RunManager.current_node and node.id.x <= RunManager.current_node.id.x:
			sprite_name += "_escura"
			overlay_name = "ind_bloqueado"
			base_mod = Color(0.62, 0.62, 0.66)
			label_col = Color(0.5, 0.45, 0.42)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			base_mod = Color(0.62, 0.6, 0.62)
			label_col = Color(0.6, 0.55, 0.5)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if overlay_name != "":
			ind_name = overlay_name

		base.modulate = base_mod
		MapNodeArt.apply(btn, base, ind, _node_sprite_name(node.type), sprite_name, ind_name, overlay_name, boss_suffix, node == pawn_rest_node)
		if size_label:
			size_label.add_theme_color_override("font_color", label_col)
		var layout_label: Label = node_layout_labels.get(node)
		if layout_label:
			layout_label.add_theme_color_override("font_color", label_col.lerp(Color(0.75, 0.9, 1.0), 0.6))
	_refresh_lines()
	for cnode in covers:
		var ccv = covers[cnode]
		if ccv != null and is_instance_valid(ccv):
			ccv.set_clickable(_cave_index(ccv, cnode), RunManager.current_node != null and cnode in RunManager.current_node.children and not is_traveling)
			ccv.set_reachable(_cave_index(ccv, cnode), RunManager.current_node != null and (cnode in RunManager.current_node.children or cnode == RunManager.current_node))

func _on_node_clicked(node: MapNode) -> void:
	if Time.get_ticks_msec() - _drag_end_msec < 150:
		return   # soltou um arrasto em cima de um nó: não é clique
	if is_traveling:
		return

	if inventory_ui and inventory_ui.visible:
		inventory_ui.visible = false

	is_traveling = true
	if node_buttons.has(node):
		var nb: Button = node_buttons[node]
		Juice.sparkle(self, nb.global_position + nb.size * 0.5, 14)
	# O peão sai do soquete: passa a ser desenhado avulso durante o salto.
	player_pawn.position = RunManager.current_node.position if RunManager.current_node != null else node.position
	pawn_rest_node = null
	player_pawn.visible = true
	_travel_from = RunManager.current_node
	_set_current_node(node, true)
	
	_travel_target = node
	# No quadro em que a peça toca o nodo ela já vira a imagem encaixada (a peça
	# avulsa deixava ver a borda escura do soquete por um instante).
	player_pawn.landed.connect(func():
		pawn_rest_node = node
		player_pawn.visible = false
		_update_nodes_visual_state(), CONNECT_ONE_SHOT)
	await player_pawn.jump_to_node(node.position, TILE_SIZE)

	# Chegou: o peão volta a ficar "encaixado" no sprite do soquete.
	pawn_rest_node = node
	player_pawn.visible = false
	_update_nodes_visual_state()

	# Nodo coberto: o foco já mostrou o interior; segura um instante, abre uma
	# janela no teto e, se todos os nodos da gruta já foram vistos, desfaz a rocha.
	if node.covered and not node.revealed:
		node.revealed = true
		var cv = covers.get(node)
		if cv != null and is_instance_valid(cv):
			cv.update_spot(node.position, true)
			Juice.sparkle(self, node_buttons[node].global_position + node_buttons[node].size * 0.5, 18)
			await get_tree().create_timer(0.9).timeout
			await cv.reveal_node(_cave_index(cv, node), 0.45)
	_travel_target = null
	_travel_from = null
	
	RunManager.current_board_size = node.board_size
	RunManager.current_board_layout = node.board_layout
	RunManager.current_node_type = node.type
	RunManager.current_node_storm = node.storm and (node.type == MapNode.NodeType.Duelo or node.type == MapNode.NodeType.DueloForte)
	
	match node.type:
		MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte, MapNode.NodeType.Chefe:
			SceneTransition.go("res://scenes/main.tscn")
		MapNode.NodeType.Loja:
			SceneTransition.go("res://scenes/shop_view.tscn")
		MapNode.NodeType.Aposta:
			SceneTransition.go("res://scenes/bet_view.tscn")
		MapNode.NodeType.Evento:
			SceneTransition.go("res://scenes/event_view.tscn")
		MapNode.NodeType.Altar:
			SceneTransition.go("res://scenes/altar_view.tscn")
		MapNode.NodeType.Arcano:
			SceneTransition.go("res://scenes/arcano_view.tscn")
		_:
			is_traveling = false

func _highlight_connection(_parent: MapNode, _child: MapNode) -> void:
	# O estado (percorrido/selecionado/bloqueado) vem de _refresh_lines().
	_refresh_lines()

func _camera_target_y(target_y: float) -> float:
	if forest == null:
		return target_y
	var half_h = get_viewport_rect().size.y / (2.0 * CAMERA_ZOOM)
	var r = forest.world_rect
	if island_base != null:
		r.size.y += island_base.extra_height()   # deixa a base rochosa à vista
	if r.size.y <= half_h * 2.0:
		return r.get_center().y
	return clampf(target_y, r.position.y + half_h, r.end.y - half_h)

# Rolar o mapa para ver trechos acima/abaixo do nó atual. Qualquer rolagem
# cancela o deslize automático da câmera e respeita os limites do mapa.
func _scroll_camera(dy: float) -> void:
	if camera == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_set_cam_y(_camera_target_y(_cam_y + dy))

func _set_cam_y(v: float) -> void:
	_cam_y = v
	if camera != null:
		camera.position.y = roundf(v)

func _modal_open() -> bool:
	return inventory_ui != null and inventory_ui.visible

func _handle_scroll_input(event: InputEvent) -> bool:
	if _modal_open():
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_camera(-SCROLL_STEP)
			return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_camera(SCROLL_STEP)
			return true
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag_scroll = mb.pressed
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Só começa a arrastar sobre o mapa (fundo ou nós), nunca sobre a HUD.
				var hov: Control = get_viewport().gui_get_hovered_control()
				_lmb_down = hov == null or node_buttons.values().has(hov)
				_lmb_origin = mb.position
				_lmb_dragging = false
			else:
				var was_drag := _lmb_dragging
				_lmb_down = false
				_lmb_dragging = false
				if was_drag:
					_drag_end_msec = Time.get_ticks_msec()
					# Não consome o evento (o botão precisa soltar); o clique que
					# terminou o arrasto é ignorado em _on_node_clicked.
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_scroll:
			_scroll_camera(-mm.relative.y / CAMERA_ZOOM)
			return true
		if _lmb_down:
			if not _lmb_dragging and mm.position.distance_to(_lmb_origin) >= DRAG_THRESHOLD:
				_lmb_dragging = true
			if _lmb_dragging:
				_scroll_camera(-mm.relative.y / CAMERA_ZOOM)
				return true
	elif event is InputEventPanGesture:
		_scroll_camera((event as InputEventPanGesture).delta.y * 40.0)
		return true
	return false

func _process(delta: float) -> void:
	_update_covers()
	_update_storms()
	# A peça fica POR CIMA da rocha até entrar pela boca; lá dentro, por baixo do teto.
	if player_pawn != null and player_pawn.visible:
		var under: bool = false
		var vis: float = 1.0
		var in_mouth: bool = false
		for cvz in caves:
			if cvz == null or not is_instance_valid(cvz):
				continue
			var ms: Array = cvz.mouth_state(player_pawn.position)
			if not ms.is_empty():
				# atravessando a boca: escurece e encolhe para dentro do vão, reaparece do outro lado
				in_mouth = true
				vis = ms[0]
				under = ms[1]
				break
			if cvz.roof_at(player_pawn.position):
				under = true
		player_pawn.z_index = 10 if under else 30
		var dk: float = 0.25 + 0.75 * vis
		player_pawn.modulate = Color(dk, dk, dk, vis) if in_mouth else Color.WHITE
		player_pawn.scale = Vector2.ONE * (0.72 + 0.28 * vis) if in_mouth else Vector2.ONE
	if is_traveling or _modal_open():
		return
	var dir := 0.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir += 1.0
	if dir != 0.0:
		_scroll_camera(dir * SCROLL_KEY_SPEED * delta)

func _move_camera_to_node(target_node: MapNode) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	var tween = create_tween()
	_cam_tween = tween
	tween.tween_method(_set_cam_y, _cam_y, _camera_target_y(target_node.position.y), 0.85)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
