extends CanvasLayer
# Autoload SceneTransition (registrado em Project Settings > Autoload): transições pixel art entre cenas (em vez de corte
# seco), lentas e suaves (sem piscar). O padrão e as cores dependem de para
# onde se vai e do bioma:
#   "fade"    : escurece suave (menus, Grimório, fim de run)
# Todas as demais são FORMAS DE DAMAS que surgem na grade da tela e a cobrem:
#   "checker" : casas em duas fases, claras e depois escuras (duelos)
#   "squares" : casas que crescem do centro para fora (mapa, duelos)
#   "discs"   : peças (discos com anel) em onda diagonal (mapa, loja, eventos)
#   "discs_c" : peças crescendo do centro para fora (mapa, duelos)
#   "chain"   : Chefe: captura em cadeia, peças vermelhas saltam fileira a
#               fileira (alternando o sentido) e "pousam" com tranco
#   "chain_sq": a mesma captura em cadeia, com casas quadradas (Chefe)
# Uso: SceneTransition.go("res://map_view.tscn")  (estilo escolhido sozinho)
#      SceneTransition.go(path, "checker")        (estilo forçado)
# Cores por bioma: chaves trans_* em BiomeBackground.BIOMES (dados, não código).

const MAP_SCENES := ["res://map_view.tscn", "res://tutorial_map_view.tscn"]
const MENU_SCENES := ["res://main_menu.tscn", "res://meta_view.tscn", "res://run_over_view.tscn"]
# estilo -> [tempo cobrindo, tempo revelando, pausa com a tela coberta]
const TIMINGS := {
	"fade": [0.45, 0.45, 0.0],
	"checker": [0.8, 0.8, 0.05],
	"squares": [0.8, 0.8, 0.05],
	"discs": [0.8, 0.8, 0.05],
	"discs_c": [0.8, 0.8, 0.05],
	"chain": [1.0, 0.9, 0.25],
	"chain_sq": [1.0, 0.9, 0.25],
}
# Sorteio por contexto (nunca repete o estilo da transição anterior).
const POOL_MAP := ["discs", "discs_c", "squares"]
const POOL_DUEL := ["checker", "squares", "discs_c"]
const POOL_BOSS := ["chain", "chain_sq"]
# Lado da casa/peça das transições de formas (poucas e grandes, não um mar delas).
const GRID_CELL := 180.0
const DEFAULT_A := Color("241a2b")
const DEFAULT_B := Color("3a2b41")
const DEFAULT_EDGE := Color("d9a441")

var busy: bool = false
var _style: String = "discs"
var _last_style: String = ""
var _boss: bool = false
var _progress: float = 0.0   # 0 = tela livre, 1 = tela coberta
var _canvas: Control
var _col_a := Color("16201c")
var _col_b := Color("2a3a31")
var _col_edge := Color("5b8f4e")

# Debug (DebugFlags.SHORTCUTS): pré-visualiza as transições sem trocar de cena.
const DEBUG_STYLES := ["fade", "checker", "squares", "discs", "discs_c", "chain", "chain_sq"]
const DEBUG_PALETTES := ["floresta", "deserto", "tutorial", "menu"]
var _dbg_idx: int = -1
var _dbg_pal: int = 0
var _dbg_boss: bool = false
var _dbg_label: Label

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_transition)
	add_child(_canvas)
	if DebugFlags.SHORTCUTS and OS.is_debug_build():
		_build_debug_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not (DebugFlags.SHORTCUTS and OS.is_debug_build()):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F6: _debug_preview(1)
		KEY_F7: _debug_preview(-1)
		KEY_F8:
			_dbg_boss = not _dbg_boss
			_refresh_debug_buttons_safe()
			_debug_flash("Paleta de Chefe: %s" % ("LIGADA" if _dbg_boss else "desligada"))
		KEY_F9:
			_dbg_pal = (_dbg_pal + 1) % DEBUG_PALETTES.size()
			_refresh_debug_buttons_safe()
			_debug_flash("Paleta: %s" % DEBUG_PALETTES[_dbg_pal])

func _refresh_debug_buttons_safe() -> void:
	if _dbg_pal_btn != null:
		_refresh_debug_buttons()

func _debug_flash(text: String) -> void:
	if _dbg_label == null:
		_dbg_label = Label.new()
		_dbg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_dbg_label.offset_top = 24.0
		_dbg_label.offset_left = -400.0
		_dbg_label.offset_right = 400.0
		_dbg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dbg_label.add_theme_font_size_override("font_size", 36)
		_dbg_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_dbg_label.add_theme_constant_override("outline_size", 8)
		_dbg_label.z_index = 10
		_dbg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dbg_label)
	_dbg_label.text = text
	_dbg_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func(): _dbg_label.visible = false)

# Painel clicável (canto inferior direito): botão "TRANS" abre/fecha a lista com
# um botão por estilo, mais paleta e Chefe. Só em build de debug com SHORTCUTS.
var _dbg_panel: PanelContainer
var _dbg_pal_btn: Button
var _dbg_boss_btn: Button

func _build_debug_panel() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 20
	add_child(root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -16.0
	box.offset_bottom = -16.0
	box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(box)
	_dbg_panel = PanelContainer.new()
	_dbg_panel.visible = false
	box.add_child(_dbg_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_dbg_panel.add_child(col)
	var title := Label.new()
	title.text = "TESTAR TRANSIÇÃO"
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)
	for i in range(DEBUG_STYLES.size()):
		var b := Button.new()
		b.text = DEBUG_STYLES[i]
		b.custom_minimum_size = Vector2(260, 40)
		b.add_theme_font_size_override("font_size", 24)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_debug_play.bind(i))
		col.add_child(b)
	_dbg_pal_btn = Button.new()
	_dbg_pal_btn.custom_minimum_size = Vector2(260, 40)
	_dbg_pal_btn.add_theme_font_size_override("font_size", 24)
	_dbg_pal_btn.focus_mode = Control.FOCUS_NONE
	_dbg_pal_btn.pressed.connect(func():
		_dbg_pal = (_dbg_pal + 1) % DEBUG_PALETTES.size()
		_refresh_debug_buttons())
	col.add_child(_dbg_pal_btn)
	_dbg_boss_btn = Button.new()
	_dbg_boss_btn.custom_minimum_size = Vector2(260, 40)
	_dbg_boss_btn.add_theme_font_size_override("font_size", 24)
	_dbg_boss_btn.focus_mode = Control.FOCUS_NONE
	_dbg_boss_btn.pressed.connect(func():
		_dbg_boss = not _dbg_boss
		_refresh_debug_buttons())
	col.add_child(_dbg_boss_btn)
	var toggle := Button.new()
	toggle.text = "TRANS"
	toggle.custom_minimum_size = Vector2(110, 40)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.add_theme_font_size_override("font_size", 22)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(func(): _dbg_panel.visible = not _dbg_panel.visible)
	box.add_child(toggle)
	_refresh_debug_buttons()

func _refresh_debug_buttons() -> void:
	_dbg_pal_btn.text = "Paleta: %s" % DEBUG_PALETTES[_dbg_pal]
	_dbg_boss_btn.text = "Chefe: %s" % ("SIM" if _dbg_boss else "não")

func _debug_preview(step: int) -> void:
	_debug_play(posmod(_dbg_idx + step, DEBUG_STYLES.size()))

func _debug_play(idx: int) -> void:
	if busy:
		return
	busy = true
	_dbg_idx = idx
	_style = DEBUG_STYLES[_dbg_idx]
	_boss = _dbg_boss
	var pal: String = DEBUG_PALETTES[_dbg_pal]
	if pal == "menu":
		_apply_palette_menu()
	else:
		_apply_palette(pal)
	_debug_flash("%s (%d/%d) · %s%s" % [_style, _dbg_idx + 1, DEBUG_STYLES.size(), pal, " · CHEFE" if _boss else ""])
	var t: Array = TIMINGS[_style]
	await _animate(1.0, float(t[0]))
	await get_tree().create_timer(maxf(0.3, float(t[2]))).timeout
	await _animate(0.0, float(t[1]))
	busy = false

func pick_style(path: String) -> String:
	if path in MENU_SCENES:
		return "fade"
	if path == "res://main.tscn":
		return _pick_from(POOL_BOSS if _is_boss_dest(path) else POOL_DUEL)
	if path in MAP_SCENES:
		# Voltando de um duelo/Chefe: suave, sem repetir o padrão de entrada.
		var cur := get_tree().current_scene
		if cur != null and cur.scene_file_path == "res://main.tscn":
			return "fade"
	return _pick_from(POOL_MAP)

func _is_boss_dest(path: String) -> bool:
	return path == "res://main.tscn" and RunManager.current_node_type == MapNode.NodeType.Chefe

func _pick_from(pool: Array) -> String:
	var options: Array = pool.filter(func(x): return x != _last_style)
	if options.is_empty():
		options = pool
	return options[randi() % options.size()]

func go(path: String, style: String = "auto") -> void:
	if busy:
		return
	busy = true
	_style = pick_style(path) if style == "auto" else style
	_last_style = _style
	_boss = _is_boss_dest(path)
	_apply_biome_colors(_is_menu_transition(path))
	var t: Array = TIMINGS[_style]
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques durante a transição
	await _animate(1.0, float(t[0]))
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if float(t[2]) > 0.0:
		await get_tree().create_timer(float(t[2])).timeout
	await _animate(0.0, float(t[1]))
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false

# Menus (origem ou destino) usam as cores padrão ameixa/ouro; as do bioma
# (floresta etc.) só valem dentro do jogo.
func _is_menu_transition(dest: String) -> bool:
	var cur := get_tree().current_scene
	var src: String = cur.scene_file_path if cur != null else ""
	return dest in MENU_SCENES or src in MENU_SCENES

func _apply_biome_colors(menu: bool = false) -> void:
	if menu:
		_apply_palette_menu()
		return
	var biome := "tutorial" if TutorialManager.is_active else "floresta"
	if not TutorialManager.is_active and BiomeBackground.BIOMES.has(RunManager.map_biome):
		biome = RunManager.map_biome
	_apply_palette(biome)

func _apply_palette_menu() -> void:
	_col_a = DEFAULT_A
	_col_b = DEFAULT_B
	_col_edge = DEFAULT_EDGE

func _apply_palette(biome: String) -> void:
	var cfg: Dictionary = BiomeBackground.BIOMES.get(biome, BiomeBackground.BIOMES["floresta"])
	_col_a = cfg.get("trans_a", _col_a)
	_col_b = cfg.get("trans_b", _col_b)
	_col_edge = cfg.get("trans_edge", _col_edge)
	if _boss:
		_col_a = cfg.get("trans_boss", Color("2a1418"))
		_col_b = Color("5a1f26")
		_col_edge = Color("b8454a")

func _animate(target: float, dur: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_progress, _progress, target, dur)
	await tw.finished

func _set_progress(v: float) -> void:
	_progress = v
	_canvas.queue_redraw()

func _draw_transition() -> void:
	if _progress <= 0.001:
		return
	match _style:
		"fade": _draw_fade()
		"checker": _draw_grid("square", "checker")
		"squares": _draw_grid("square", "radial")
		"discs": _draw_grid("disc", "diag")
		"discs_c": _draw_grid("disc", "radial")
		"chain": _draw_grid("disc", "snake", true)
		"chain_sq": _draw_grid("square", "snake", true)
		_: _draw_grid("disc", "diag")

func _draw_fade() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(_col_a, _progress))

# Grade de formas de Dama (casa ou peça) que crescem e cobrem a tela.
# mode: "radial" = do centro para fora; "diag" = onda diagonal; "snake" = fileira
# a fileira, alternando o sentido (como uma captura em cadeia). `punch` faz a
# peça passar do tamanho e assentar (tranco). No fim, um fundo liso sobe por
# baixo para a tela ficar 100% coberta sem frestas.
func _draw_grid(shape: String, mode: String, punch: bool = false) -> void:
	var d := GRID_CELL
	var vp := _canvas.size
	var cols := int(ceil(vp.x / d))
	var rows := int(ceil(vp.y / d))
	var ctr := vp * 0.5
	var max_dist := ctr.length()
	var span := float(cols + rows)
	var solid := clampf((_progress - 0.86) / 0.14, 0.0, 1.0)
	if solid > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(_col_a, solid))
	for r in range(rows):
		for c in range(cols):
			var cc := Vector2(c + 0.5, r + 0.5) * d
			var delay: float
			var window := 0.55
			match mode:
				"radial":
					delay = cc.distance_to(ctr) / max_dist * 0.45
				"checker":
					# Duas fases: as casas claras entram primeiro, as escuras depois.
					delay = float(c + r) / span * 0.1 + (0.0 if (c + r) % 2 == 0 else 0.4)
					window = 0.5
				"snake":
					var along: float = float(c) / float(cols) if r % 2 == 0 else float(cols - 1 - c) / float(cols)
					delay = float(r) / float(rows) * 0.42 + along * 0.08
					window = 0.5
				_:
					delay = float(c + r) / span * 0.45
			var t := clampf((_progress - delay) / window, 0.0, 1.0)
			if t <= 0.0:
				continue
			if punch:
				t = _ease_out_back(t)
			var even := (c + r) % 2 == 0
			var base := _col_b if even else _col_a
			# Mesma "peça" para casa e disco: aro mais claro enquanto cresce
			# (tom do próprio bioma), corpo, anel escuro e miolo.
			var rim := base.lightened(0.3) if t < 0.98 else base
			if shape == "square":
				var sq := d * t
				var grow := 1.0 if t >= 1.0 else 0.0
				_paint_square(cc, sq + grow * 2.0, rim)
				_paint_square(cc, sq * 0.78, base)
				_paint_square(cc, sq * 0.56, base.darkened(0.3))
				_paint_square(cc, sq * 0.4, base)
			else:
				var rad := d * 0.74 * pow(t, 1.25)   # mesmo ritmo visual das casas
				_pixel_disc(cc, rad, rim)
				_pixel_disc(cc, rad * 0.78, base)
				_pixel_disc(cc, rad * 0.56, base.darkened(0.3))
				_pixel_disc(cc, rad * 0.4, base)

# Quadrado centrado em pixels inteiros (cresce suave, sem degraus).
func _paint_square(center: Vector2, size: float, col: Color) -> void:
	if size < 2.0:
		return
	var half := roundf(size / 2.0)
	_canvas.draw_rect(Rect2((center - Vector2(half, half)).round(), Vector2(half, half) * 2.0), col)

func _ease_out_back(x: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

# Disco em blocos de 6 px (pixel art, sem anti-aliasing): fileiras simétricas
# em torno do centro, então o círculo fica redondo (não oval).
func _pixel_disc(center: Vector2, radius: float, col: Color) -> void:
	if radius < 4.0:
		return
	var step := 6.0
	var n := int(roundf(radius / step))
	for j in range(-n, n + 1):
		var dy := float(j) * step
		var half := sqrt(maxf(0.0, radius * radius - dy * dy))
		half = roundf(half / step) * step
		if half <= 0.0:
			continue
		_canvas.draw_rect(Rect2(center.x - half, center.y + dy - step * 0.5, half * 2.0, step), col)
