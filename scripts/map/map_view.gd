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
		if _current_biome() == "cume":
			_assign_cume_terrain(RunManager.map_data)
		if _current_biome() == "caldeira":
			_assign_caldeira_terrain(RunManager.map_data)
		if not RunManager.map_data.is_empty() and not RunManager.map_data[0].is_empty():
			RunManager.current_node = RunManager.map_data[0][0]

	_build_forest(RunManager.map_data)
	_draw_lines(RunManager.map_data)
	_instantiate_node_ui(RunManager.map_data)
	_build_covers(RunManager.map_data)
	_build_storms(RunManager.map_data)
	_build_cume_terrain(RunManager.map_data)
	_build_caldeira_terrain(RunManager.map_data)
	_restore_visited_connections()

	if RunManager.current_node != null:
		player_pawn.set_initial_position(RunManager.current_node.position, TILE_SIZE)
		pawn_rest_node = RunManager.current_node
		player_pawn.visible = false
		_set_current_node(RunManager.current_node, false)

	if DebugFlags.SHORTCUTS:
		_build_debug_hint()
	if RunManager.biome_crossing_pending and RunManager.current_node != null:
		# chefe derrotado: a peça atravessa o céu até a ilha do próximo bioma
		_set_cam_y(_camera_target_y(RunManager.current_node.position.y))
		player_pawn.visible = true
		var crossing := BiomeCrossing.new()
		add_child(crossing)
		crossing.run(self)
		return
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

	# Dica de que o mapa rola (barra lateral, setinhas e, na 1ª vez, "arraste").
	var hint := MapScrollHint.new()
	hint.map_view = self
	add_child(hint)

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

# DEBUG: lembrete das teclas de atalho do mapa (só com DebugFlags.SHORTCUTS).
func _build_debug_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var lbl := Label.new()
	# os chefes de cada lei agora ficam no botão CHEFES (canto inferior direito)
	lbl.text = "DEBUG   B Apostas   E Evento   |   chefes: botão CHEFES"
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
	if _current_biome() == "caldeira":
		forest.reserved_rects = _caldeira_layout(layers, -half + 1, half - 1)
	# Uma coluna a menos de cada lado (antes: só do direito), então a largura
	# fica simétrica em torno do centro; a câmera acompanha o centro do tabuleiro.
	forest.build(layers, TILE_SIZE, MAP_SPRITE_SCALE, -half + 1, half - 1, min_r - 2, max_r + 2)
	if camera != null:
		camera.position.x = roundf(forest.world_rect.get_center().x)
	# Base rochosa: o mapa é uma ilha flutuando no espaço (atrás do tabuleiro).
	island_base = IslandBase.new()
	island_base.name = "IslandBase"
	island_base.biome = _current_biome()
	if island_base.biome == "cume":
		# franja de sincelos da moldura do cume: 5 px nativos (casa de 26 px) + 1 de encaixe
		island_base.top_overlap_px = 6.0 * forest._tile / 26.0
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
	if _current_biome() == "cume":
		fill = Color("#e4f6ff")
		edge = Color("#1c3550")
	if _current_biome() == "caldeira":
		fill = Color("#ffd08a")
		edge = Color("#5a1a10")
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
	# O override de debug só escolhe o bioma INICIAL (RunManager.start_new_run); depois
	# a run segue a ordem normal (antes ele prendia o mapa no bioma forçado para sempre).
	var b: String = RunManager.map_biome
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
					state = "bloqueado" if _edge_blocked(node, child) else "selecionado"
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

# ------------------------------------------- desfiladeiro e glaciar (Cume Congelado) ----
const GLACIER_MAX: int = 2
const GLACIER_CHANCE: float = 0.6
const BRIDGE_BOARD := Vector2i(10, 6)     # ponte: tabuleiro estreito e comprido (linhas, colunas)
var glaciers: Array = []

# Sorteia o terreno do Cume: UMA fileira do meio do mapa vira o desfiladeiro (todo
# nodo dela fica numa ponte de corda; os duelos são travados em cima da ponte, em
# tabuleiro estreito) e até GLACIER_MAX glaciares de gelo fino cobrem 1 ou 2 duelos
# vizinhos de outras fileiras.
func _assign_cume_terrain(layers: Array[Array]) -> void:
	var n: int = layers.size()
	if n < 5:
		return
	# desfiladeiro: fileira do miolo com pelo menos um duelo (a mais perto do meio)
	var bridge_li: int = -1
	var mid: float = float(n - 1) / 2.0
	# chave sorteada UMA vez por fileira (sortear dentro da comparação quebra a ordenação)
	var keyed: Array = []
	for li0 in range(2, n - 2):
		keyed.append([absf(float(li0) - mid) + randf() * 1.5, li0])
	keyed.sort_custom(func(a, b): return a[0] < b[0])
	var order: Array = keyed.map(func(e): return e[1])
	for li in order:
		if layers[li].any(func(x: MapNode): return _is_duel(x)):
			bridge_li = li
			break
	if bridge_li >= 0:
		for node in layers[bridge_li]:
			node.bridge = true
			if _is_duel(node):
				node.board_size = BRIDGE_BOARD
				node.board_layout = Board.LAYOUT_CLASSIC
	# glaciares
	var made: int = 0
	var last_li: int = -9
	var lis: Array = range(1, n - 1)
	lis.shuffle()
	for li in lis:
		if made >= GLACIER_MAX:
			break
		if absi(li - bridge_li) < 1 or absi(li - last_li) < 2 or randf() > GLACIER_CHANCE:
			continue
		var layer: Array = layers[li]
		var idx: Array = []
		for i in range(layer.size()):
			if _is_duel(layer[i]):
				idx.append(i)
		if idx.is_empty():
			continue
		var i0: int = idx[randi() % idx.size()]
		var group: Array = [layer[i0]]
		for j in [i0 - 1, i0 + 1]:
			if j >= 0 and j < layer.size() and _is_duel(layer[j]) and group.size() < 2 and randf() < 0.5:
				group.append(layer[j])
		for g in group:
			g.glacier = true
			g.glacier_id = made
		last_li = li
		made += 1

func _build_cume_terrain(layers: Array[Array]) -> void:
	glaciers.clear()
	if forest == null:
		return
	var clear_rects: Array = []
	var board_rect: Rect2 = forest._board_rect
	# desfiladeiro
	for layer in layers:
		if layer.is_empty() or not layer[0].bridge:
			continue
		var y: float = layer[0].position.y
		var ch := MapChasm.new()
		add_child(ch)
		move_child(ch, forest.get_index() + 1)
		ch.setup(board_rect, y, layer.map(func(x: MapNode): return x.position.x), layer.map(func(x: MapNode): return _is_duel(x)), int(y) * 31 + 7)
		clear_rects.append(Rect2(board_rect.position.x, y - MapChasm.HEIGHT * 0.5, board_rect.size.x, MapChasm.HEIGHT))
	# glaciares
	var groups: Dictionary = {}
	for layer in layers:
		for node in layer:
			if node.glacier and node.glacier_id >= 0:
				if not groups.has(node.glacier_id):
					groups[node.glacier_id] = []
				groups[node.glacier_id].append(node)
	for gid in groups:
		var members: Array = groups[gid]
		var others: Array = []
		for layer in layers:
			for node in layer:
				if not (node in members) and absf(node.position.y - members[0].position.y) < TILE_SIZE * 4.0:
					others.append(node.position / TILE_SIZE)
		var cells: Array = []
		var c0: Vector2 = members[0].position / TILE_SIZE
		for gy in range(int(c0.y) - 3, int(c0.y) + 4):
			for gx in range(int(round(board_rect.position.x / TILE_SIZE)) - 1, int(round(board_rect.end.x / TILE_SIZE)) + 2):
				var cell := Vector2i(gx, gy)
				var center: Vector2 = Vector2(cell) * TILE_SIZE
				if not board_rect.has_point(center):
					continue
				var inside := false
				for m in members:
					var d: Vector2 = Vector2(cell) - m.position / TILE_SIZE
					var wob: float = float(absi(hash(Vector3i(gx, gy, gid))) % 100) / 100.0 * 0.5
					if Vector2(d.x / 2.9, d.y / 2.2).length() + wob * 0.4 <= 1.0:
						inside = true
				if not inside:
					continue
				var blocked := false
				for o in others:
					if (Vector2(cell) - o).length() < 0.9:
						blocked = true
				if not blocked:
					cells.append(cell)
		var gl := MapGlacier.new()
		add_child(gl)
		move_child(gl, forest.get_index() + 1)
		gl.forest = forest
		gl.setup(cells, members.map(func(x: MapNode): return x.position))
		gl.set_meta("nodes", members)
		for i in range(members.size()):
			gl.set_cracked(i, members[i] == RunManager.current_node or _is_node_completed(members[i]), true)
		glaciers.append(gl)
		for cell in cells:
			clear_rects.append(Rect2(Vector2(cell) * TILE_SIZE - Vector2(TILE_SIZE, TILE_SIZE) * 0.5, Vector2(TILE_SIZE, TILE_SIZE)).grow(-4.0))
	if not clear_rects.is_empty():
		forest.clear_decor_in(clear_rects)

# As rachaduras se espalham quando a peça chega num duelo do glaciar.
func _update_glaciers() -> void:
	for gl in glaciers:
		if gl == null or not is_instance_valid(gl):
			continue
		var nodes: Array = gl.get_meta("nodes")
		for i in range(nodes.size()):
			if nodes[i] == pawn_rest_node and nodes[i] == RunManager.current_node:
				gl.set_cracked(i, true)

# ------------------------------------------- erupção e maré de lava (Caldeira) ----
# Erupção: a cada ERUPTION_EVERY fileiras, as bombas caem quando a peça chega na
# fileira `li` e cortam trilhas que saem dela (cada nodo mantém ao menos uma) e
# chamuscam 1 ou 2 duelos da fileira seguinte. Um passo antes, tudo fica marcado.
# Maré: uma fileira do miolo (3+ nodos); a lava entra TIDE_LEAD passos antes e engole
# um nodo por passo. Duelo engolido fica numa ilha (tabuleiro menor, ouro em dobro);
# loja/evento/altar/aposta afundam, a não ser que isso deixe algum pai sem saída.
const ERUPTION_EVERY: int = 3
const ERUPTION_FIRST: int = 2
const ERUPTION_BLOCK_CHANCE: float = 0.45
const TIDE_LEAD: int = 3
var eruption_fx: MapEruption = null
var tide_fx: MapTide = null
var _cald_geo: Dictionary = {}

func _assign_caldeira_terrain(layers: Array[Array]) -> void:
	var n: int = layers.size()
	var plan: Dictionary = {"eruptions": [], "tide": {}, "fired": [], "tide_shown": -1}
	# maré: a fileira com mais nodos no miolo (sem começo/chefe)
	var best: int = -1
	var best_score: float = -INF
	for li in range(TIDE_LEAD + 1, n - 2):
		var cnt: int = layers[li].size()
		if cnt < 3:
			continue
		if layers[li].any(func(x: MapNode): return x.type == MapNode.NodeType.Chefe or x.type == MapNode.NodeType.Começo):
			continue
		var score: float = float(cnt) + randf() * 1.5 - absf(float(li) - float(n) * 0.5) * 0.25
		if score > best_score:
			best_score = score
			best = li
	if best >= 0:
		var dir: int = 1 if randf() < 0.5 else -1
		var row: Array = layers[best].duplicate()
		row.sort_custom(func(a: MapNode, b: MapNode): return a.position.x < b.position.x if dir > 0 else a.position.x > b.position.x)
		# só os nodos engolidos ANTES da peça escolher (os TIDE_LEAD-1 primeiros) podem prender alguém
		var sunk_early: Array = []
		var safe: Array = []
		for i in range(mini(TIDE_LEAD - 1, row.size())):
			var nd: MapNode = row[i]
			if _is_duel(nd):
				continue
			var strands := false
			for p in nd.parents:
				var open := false
				for c in p.children:
					if c != nd and not (c in sunk_early):
						open = true
				if not open:
					strands = true
			if strands:
				safe.append(nd)
			else:
				sunk_early.append(nd)
		for nd in row:
			nd.tide = true
		plan["tide"] = {"li": best, "dir": dir, "order": row, "safe": safe}
	# erupções
	# (nunca na fileira logo antes da maré: as trilhas que entram nela já são da lava)
	var li: int = ERUPTION_FIRST
	while li <= n - 3:
		if best >= 0 and li == best - 1:
			li += 1
			continue
		# primeiro os duelos chamuscados (fileira seguinte); as trilhas que levam até eles
		# NUNCA são cortadas (a bola de fogo não pode trancar o próprio duelo que ela marcou)
		var duels: Array = layers[li + 1].filter(func(x: MapNode): return _is_duel(x) and not x.tide)
		duels.shuffle()
		var hits: Array = duels.slice(0, 2 if randf() < 0.4 else 1)
		for h in hits:
			h.scorched = true
		var edges: Array = []
		var candidates: Array = []
		for p in layers[li]:
			var kids: Array = p.children.filter(func(c: MapNode): return not (c in hits))
			if kids.size() < 1 or p.children.size() < 2:
				continue
			kids.shuffle()
			candidates.append([p, kids[0]])
			var blocked: int = 0
			for c in kids:
				if blocked >= p.children.size() - 1:
					break
				if randf() < ERUPTION_BLOCK_CHANCE:
					edges.append(_get_connection_key(p, c))
					blocked += 1
		if edges.is_empty() and not candidates.is_empty():
			var pc: Array = candidates[randi() % candidates.size()]
			edges.append(_get_connection_key(pc[0], pc[1]))
		if not edges.is_empty() or not hits.is_empty():
			plan["eruptions"].append({"li": li, "edges": edges, "nodes": hits})
		li += ERUPTION_EVERY
	RunManager.caldeira_plan = plan

func _cald_plan() -> Dictionary:
	return RunManager.caldeira_plan if _current_biome() == "caldeira" else {}

func _edge_blocked(parent: MapNode, child: MapNode) -> bool:
	if child.sunk:
		return true
	var plan: Dictionary = _cald_plan()
	if plan.is_empty():
		return false
	var key: String = _get_connection_key(parent, child)
	for e in plan.get("eruptions", []):
		if plan["fired"].has(int(e["li"])) and (e["edges"] as Array).has(key):
			return true
	return false

func _node_by_key(key: String, layers: Array[Array]) -> Array:
	for layer in layers:
		for node in layer:
			for child in node.children:
				if _get_connection_key(node, child) == key:
					return [node, child]
	return []

# Ponto (mundo) do meio da trilha de uma aresta: onde cai a bomba / fica a cratera.
func _edge_mid(parent: MapNode, child: MapNode) -> Vector2:
	var pts: Array = ForestTrail.cell_points(parent.position, child.position, MAP_SPRITE_SCALE)
	if pts.size() <= 2:
		return (parent.position + child.position) * 0.5
	return pts[pts.size() >> 1]

# Antes do fundo ser montado: o vale da maré e o lugar de cada vulcão (o fundo não
# põe lagos nem marcos ali). Devolve as áreas reservadas.
func _caldeira_layout(layers: Array[Array], min_col: int, max_col: int) -> Array:
	_cald_geo = {"min_col": min_col, "max_col": max_col, "volcanoes": []}
	var plan: Dictionary = RunManager.caldeira_plan
	var reserved: Array = []
	var tide: Dictionary = plan.get("tide", {})
	if not tide.is_empty():
		var row: int = int(round(layers[int(tide["li"])][0].position.y / TILE_SIZE))
		_cald_geo["tide_row"] = row
		reserved.append(MapTide.band_rect(row, min_col, max_col, TILE_SIZE))
	# casas de trilha e nodos (o vulcão foge deles)
	var trail_pts: Array = []
	var node_pts: Array = []
	for layer in layers:
		for node in layer:
			node_pts.append(node.position)
			for child in node.children:
				trail_pts.append_array(ForestTrail.cell_points(node.position, child.position, MAP_SPRITE_SCALE))
	var vsz: Vector2 = MapEruption.VOLCANO_SIZE * float(MAP_SPRITE_SCALE)
	if not plan.has("vol_side"):
		plan["vol_side"] = -1 if randf() < 0.5 else 1
	var side: int = int(plan["vol_side"])
	for e in plan.get("eruptions", []):
		var y_li: float = layers[int(e["li"])][0].position.y
		var best_spot: Vector2 = Vector2.ZERO
		var best_cost: float = INF
		for sd in [side, -side]:
			var cx: float = float(min_col + 1 if sd < 0 else max_col - 1) * TILE_SIZE
			for k in range(-1, TILES_PER_LAYER + 1):
				var base := Vector2(cx, y_li - (float(k) - 0.5) * TILE_SIZE)
				var rect := Rect2(Vector2(base.x - vsz.x * 0.5, base.y - vsz.y), vsz)
				var cost: float = absf(float(k) - 2.0) * 0.3 + (0.0 if sd == side else 0.6)
				for tp in trail_pts:
					if rect.grow(TILE_SIZE * 0.25).has_point(tp):
						cost += 6.0
				for np in node_pts:
					if rect.grow(TILE_SIZE * 0.6).has_point(np):
						cost += 20.0
				for rr in reserved:
					if (rr as Rect2).intersects(rect):
						cost += 50.0
				if cost < best_cost:
					best_cost = cost
					best_spot = base
		_cald_geo["volcanoes"].append(best_spot)
		reserved.append(Rect2(Vector2(best_spot.x - vsz.x * 0.5, best_spot.y - vsz.y), vsz))
		side = -side
	return reserved

func _build_caldeira_terrain(layers: Array[Array]) -> void:
	eruption_fx = null
	tide_fx = null
	var plan: Dictionary = _cald_plan()
	if plan.is_empty() or forest == null or _cald_geo.is_empty():
		return
	var clear: Array = []
	# erupções
	var data: Array = []
	var vols: Array = _cald_geo.get("volcanoes", [])
	var eruptions: Array = plan.get("eruptions", [])
	for i in range(eruptions.size()):
		var e: Dictionary = eruptions[i]
		var edge_pts: Array = []
		for key in e["edges"]:
			var pc: Array = _node_by_key(key, layers)
			if not pc.is_empty():
				edge_pts.append(_edge_mid(pc[0], pc[1]))
		var npts: Array = []
		for nd in e["nodes"]:
			npts.append(nd.position)
		var vbase: Vector2 = vols[i] if i < vols.size() else Vector2.ZERO
		data.append({"li": e["li"], "volcano": vbase, "edge_pts": edge_pts, "node_pts": npts})
		var vsz: Vector2 = MapEruption.VOLCANO_SIZE * float(MAP_SPRITE_SCALE)
		clear.append(Rect2(Vector2(vbase.x - vsz.x * 0.5, vbase.y - vsz.y), vsz).grow(TILE_SIZE * 0.2))
	if not data.is_empty():
		var under := Node2D.new()
		under.name = "EruptionVolcanoes"
		add_child(under)
		move_child(under, forest.get_index() + 1)
		eruption_fx = MapEruption.new()
		eruption_fx.name = "Eruption"
		eruption_fx.under = under
		add_child(eruption_fx)
		move_child(eruption_fx, lines_container.get_index() + 1)
		eruption_fx.setup(data, plan["fired"], float(MAP_SPRITE_SCALE))
	# maré
	var tide: Dictionary = plan.get("tide", {})
	if not tide.is_empty():
		var over := Node2D.new()
		over.name = "TideOver"
		add_child(over)
		move_child(over, lines_container.get_index() + 1)
		tide_fx = MapTide.new()
		tide_fx.name = "Tide"
		tide_fx.over = over
		add_child(tide_fx)
		move_child(tide_fx, forest.get_index() + 1)
		var pts: Array = (tide["order"] as Array).map(func(x: MapNode): return x.position)
		var row: int = int(_cald_geo.get("tide_row", 0))
		tide_fx.setup(forest, row, int(tide["dir"]), pts, int(_cald_geo["min_col"]), int(_cald_geo["max_col"]), TILE_SIZE, float(MAP_SPRITE_SCALE), (tide["order"] as Array).map(func(x: MapNode): return _is_duel(x)))
		var crossing: Array = []
		for layer in layers:
			for nd in layer:
				for ch in nd.children:
					if nd.tide or ch.tide:
						crossing.append(ForestTrail.cell_points(nd.position, ch.position, MAP_SPRITE_SCALE))
		tide_fx.set_trails(crossing)
		var order_nodes: Array = tide["order"]
		tide_fx.node_sinking.connect(func(idx: int):
			var nb: Button = node_buttons.get(order_nodes[idx])
			if nb != null:
				nb.visible = false)
		clear.append(MapTide.band_rect(row, int(_cald_geo["min_col"]), int(_cald_geo["max_col"]), TILE_SIZE).grow(-TILE_SIZE * 0.1))
		var shown: int = int(plan.get("tide_shown", -1))
		if shown >= 0:
			tide_fx.set_progress(shown, _tide_states(shown))
	if not clear.is_empty():
		forest.clear_decor_in(clear)
	_caldeira_refresh()

# Com uma erupção marcada logo à frente, a câmera sobe um pouco para mostrar as trilhas
# que vão ser cortadas (ficam uma fileira e meia acima da peça).
func _caldeira_camera_bias(node: MapNode) -> float:
	var plan: Dictionary = _cald_plan()
	if plan.is_empty():
		return 0.0
	for e in plan.get("eruptions", []):
		var li: int = int(e["li"])
		if node.id.x == li - 1 and not (plan["fired"] as Array).has(li):
			return -TILE_SIZE * 5.0
	return 0.0

func _cur_layer() -> int:
	return RunManager.current_node.id.x if RunManager.current_node != null else 0

func _tide_k_for(layer: int) -> int:
	var tide: Dictionary = _cald_plan().get("tide", {})
	if tide.is_empty():
		return -1
	var stage: int = layer - (int(tide["li"]) - TIDE_LEAD)
	if stage < 0:
		return -1
	return mini(stage, (tide["order"] as Array).size())

# Estado visual de cada nodo da maré com k nodos engolidos (aplica island/sunk).
func _tide_states(k: int) -> Array:
	var tide: Dictionary = _cald_plan().get("tide", {})
	var out: Array = []
	if tide.is_empty():
		return out
	var order: Array = tide["order"]
	for i in range(order.size()):
		var nd: MapNode = order[i]
		if i >= k:
			out.append("")
			continue
		if not nd.island and not nd.sunk:
			if _is_duel(nd) or (tide["safe"] as Array).has(nd) or nd == RunManager.current_node:
				nd.island = true
				if _is_duel(nd):
					nd.board_size = Vector2i(maxi(6, nd.board_size.x - 2), maxi(6, nd.board_size.y - 2))
					nd.board_layout = Board.LAYOUT_CLASSIC
					_refresh_node_labels(nd)
			else:
				nd.sunk = true
		out.append("ilha" if nd.island else "afundando")
	return out

func _refresh_node_labels(nd: MapNode) -> void:
	var sl: Label = node_size_labels.get(nd)
	if sl != null:
		sl.text = nd.get_size_text()
	var ll: Label = node_layout_labels.get(nd)
	if ll != null:
		ll.visible = nd.has_special_layout()

# Marcas e vulcões seguem a fileira da peça.
func _caldeira_refresh() -> void:
	var cur: int = _cur_layer()
	if eruption_fx != null:
		eruption_fx.set_layer(cur)
	if tide_fx != null:
		var k: int = int(_cald_plan().get("tide_shown", -1))
		var tide: Dictionary = _cald_plan().get("tide", {})
		tide_fx.set_next(k if k >= 0 and cur < int(tide.get("li", 0)) else -1)

# A peça chegou num nodo: dispara a erupção da fileira e faz a maré andar.
func _caldeira_on_arrival(node: MapNode) -> void:
	var plan: Dictionary = _cald_plan()
	if plan.is_empty():
		return
	var cur: int = node.id.x
	if eruption_fx != null:
		# erupção marcada para o próximo passo: o vulcão começa a roncar
		var nxt: int = eruption_fx.index_for_layer(cur + 1)
		if nxt >= 0 and not (plan["fired"] as Array).has(cur + 1) and eruption_fx.volcano_visible(nxt):
			Sfx.play("vulcao_ronco")
		var i: int = eruption_fx.index_for_layer(cur)
		if i >= 0 and not (plan["fired"] as Array).has(cur):
			(plan["fired"] as Array).append(cur)
			await eruption_fx.fire(i)
			_update_nodes_visual_state()
	if tide_fx != null:
		var k: int = _tide_k_for(cur)
		var shown: int = int(plan.get("tide_shown", -1))
		if k > shown:
			plan["tide_shown"] = k
			await tide_fx.advance(k, _tide_states(k))
			_update_nodes_visual_state()
	_caldeira_refresh()

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
		elif RunManager.current_node and node in RunManager.current_node.children and not _edge_blocked(RunManager.current_node, node):
			ind_name = "ind_selecionado" if node == _hovered_node else ""
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
		elif RunManager.current_node and node in RunManager.current_node.children:
			# Caldeira: trilha cortada pela erupção / nodo afundado na maré
			sprite_name += "_escura"
			overlay_name = "ind_bloqueado"
			base_mod = Color(0.62, 0.62, 0.66)
			label_col = Color(0.5, 0.45, 0.42)
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		btn.visible = not node.sunk
		MapNodeArt.apply(btn, base, ind, _node_sprite_name(node.type), sprite_name, ind_name, overlay_name, boss_suffix, node == pawn_rest_node)
		if size_label:
			size_label.add_theme_color_override("font_color", label_col)
		var layout_label: Label = node_layout_labels.get(node)
		if layout_label:
			layout_label.add_theme_color_override("font_color", label_col.lerp(Color(0.75, 0.9, 1.0), 0.6))
	_refresh_lines()
	_caldeira_refresh()
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

	# Caldeira: a erupção desta fileira e o avanço da maré acontecem quando a peça chega
	await _caldeira_on_arrival(node)

	RunManager.current_board_size = node.board_size
	RunManager.current_board_layout = node.board_layout
	RunManager.current_node_type = node.type
	RunManager.current_node_storm = node.storm and (node.type == MapNode.NodeType.Duelo or node.type == MapNode.NodeType.DueloForte)
	RunManager.current_node_glacier = node.glacier and _is_duel(node)
	RunManager.current_node_bridge = node.bridge and _is_duel(node)
	RunManager.current_node_scorched = node.scorched and _is_duel(node)
	RunManager.current_node_island = node.island and _is_duel(node)
	
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
	_manual_scroll_msec = Time.get_ticks_msec()
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_set_cam_y(_camera_target_y(_cam_y + dy))

var _manual_scroll_msec: int = -100000

# Para a MapScrollHint: onde a câmera está, os limites dela e se o mapa rola.
func get_scroll_info() -> Dictionary:
	if camera == null or forest == null:
		return {}
	var half_h: float = get_viewport_rect().size.y / (2.0 * CAMERA_ZOOM)
	var r: Rect2 = forest.world_rect
	if island_base != null:
		r.size.y += island_base.extra_height()
	var lo: float = r.position.y + half_h
	var hi: float = r.end.y - half_h
	var info := {
		"scrollable": r.size.y > half_h * 2.0 + 4.0,
		"y": _cam_y, "min": lo, "max": hi, "half": half_h,
		"world_top": r.position.y, "world_h": r.size.y,
		"manual": Time.get_ticks_msec() - _manual_scroll_msec < 250,
		"busy": is_traveling or _modal_open(),
	}
	if RunManager.current_node != null:
		info["pawn_y"] = RunManager.current_node.position.y
	return info

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
	_update_glaciers()
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
	tween.tween_method(_set_cam_y, _cam_y, _camera_target_y(target_node.position.y + _caldeira_camera_bias(target_node)), 0.85)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
