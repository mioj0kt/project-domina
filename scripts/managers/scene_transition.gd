extends CanvasLayer
# Autoload SceneTransition (registrado em Project Settings > Autoload): transições pixel art entre cenas (em vez de corte
# seco), lentas e suaves (sem piscar). O padrão e as cores dependem de para
# onde se vai e do bioma:
#   "fade"    : escurece suave (menus, Grimório, fim de run)
#   "diamond" : losangos grandes crescem em onda (mapa, loja, apostas, eventos)
#   "checker" : tabuleiro de casas em duas fases (duelos)
#   "bars"    : colunas que fecham de cima e de baixo, vermelhas (Chefe)
# Uso: SceneTransition.go("res://map_view.tscn")  (estilo escolhido sozinho)
#      SceneTransition.go(path, "checker")        (estilo forçado)
# Cores por bioma: chaves trans_* em BiomeBackground.BIOMES (dados, não código).

const MAP_SCENES := ["res://map_view.tscn", "res://tutorial_map_view.tscn"]
const MENU_SCENES := ["res://main_menu.tscn", "res://meta_view.tscn", "res://run_over_view.tscn"]
# estilo -> [tempo cobrindo, tempo revelando, pausa com a tela coberta]
const TIMINGS := {
	"fade": [0.45, 0.45, 0.0],
	"diamond": [0.7, 0.7, 0.05],
	"checker": [0.75, 0.75, 0.05],
	"bars": [1.0, 1.0, 0.25],
}

const DEFAULT_A := Color("241a2b")
const DEFAULT_B := Color("3a2b41")
const DEFAULT_EDGE := Color("d9a441")

var busy: bool = false
var _style: String = "diamond"
var _progress: float = 0.0   # 0 = tela livre, 1 = tela coberta
var _canvas: Control
var _col_a := Color("16201c")
var _col_b := Color("2a3a31")
var _col_edge := Color("5b8f4e")

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_transition)
	add_child(_canvas)

func pick_style(path: String) -> String:
	if path in MENU_SCENES:
		return "fade"
	if path == "res://main.tscn":
		return "bars" if RunManager.current_node_type == MapNode.NodeType.Chefe else "checker"
	if path in MAP_SCENES:
		# Voltando de um duelo/Chefe: suave, sem repetir o padrão de entrada.
		var cur := get_tree().current_scene
		if cur != null and cur.scene_file_path == "res://main.tscn":
			return "fade"
	return "diamond"

func go(path: String, style: String = "auto") -> void:
	if busy:
		return
	busy = true
	_style = pick_style(path) if style == "auto" else style
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
		_col_a = DEFAULT_A
		_col_b = DEFAULT_B
		_col_edge = DEFAULT_EDGE
		return
	var biome := "tutorial" if TutorialManager.is_active else "floresta"
	if not TutorialManager.is_active and BiomeBackground.BIOMES.has(RunManager.map_biome):
		biome = RunManager.map_biome
	var cfg: Dictionary = BiomeBackground.BIOMES.get(biome, BiomeBackground.BIOMES["floresta"])
	_col_a = cfg.get("trans_a", _col_a)
	_col_b = cfg.get("trans_b", _col_b)
	_col_edge = cfg.get("trans_edge", _col_edge)
	if _style == "bars":
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
		"checker": _draw_checker()
		"bars": _draw_bars()
		_: _draw_diamonds()

func _draw_fade() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(_col_a, _progress))

# Losangos grandes e lentos; onda diagonal suave.
func _draw_diamonds() -> void:
	var d := 160.0
	var vp := _canvas.size
	var cols := int(ceil(vp.x / d)) + 1
	var rows := int(ceil(vp.y / d)) + 1
	var span := float(cols + rows)
	for r in range(rows):
		for c in range(cols):
			var delay := float(c + r) / span * 0.4
			var t := clampf((_progress - delay) / 0.6, 0.0, 1.0)
			if t <= 0.0:
				continue
			var ctr := Vector2(c + 0.5, r + 0.5) * d
			var rad := d * t * 1.02
			if rad < 2.0:
				continue
			var pts := PackedVector2Array([ctr + Vector2(0, -rad), ctr + Vector2(rad, 0), ctr + Vector2(0, rad), ctr + Vector2(-rad, 0)])
			_canvas.draw_colored_polygon(pts, _col_a if (c + r) % 2 == 0 else _col_a.lerp(_col_b, 0.35))

# Casas de tabuleiro: as claras primeiro, as escuras depois.
func _draw_checker() -> void:
	var d := 135.0
	var vp := _canvas.size
	var cols := int(ceil(vp.x / d))
	var rows := int(ceil(vp.y / d))
	var span := float(cols + rows)
	for r in range(rows):
		for c in range(cols):
			var even := (c + r) % 2 == 0
			var delay := float(c + r) / span * 0.12
			var t := clampf(((_progress - delay) - (0.0 if even else 0.42)) / 0.5, 0.0, 1.0)
			if t <= 0.0:
				continue
			var s := d * t
			var ctr := Vector2(c + 0.5, r + 0.5) * d
			var rect := Rect2(ctr - Vector2(s, s) / 2.0, Vector2(s, s))
			if t >= 1.0:
				rect = rect.grow(1.0)
			_canvas.draw_rect(rect, _col_b if even else _col_a)

# Chefe: colunas vermelhas descem e sobem alternadas, do centro para fora.
func _draw_bars() -> void:
	var w := 120.0
	var vp := _canvas.size
	var n := int(ceil(vp.x / w))
	var mid := n / 2.0
	for i in range(n):
		var delay := absf(i + 0.5 - mid) / mid * 0.35
		var t := clampf((_progress - delay) / 0.65, 0.0, 1.0)
		if t <= 0.0:
			continue
		var h := (vp.y + 2.0) * t
		var x := i * w
		var from_top := i % 2 == 0
		var y := 0.0 if from_top else vp.y - h
		_canvas.draw_rect(Rect2(x, y, w + 1.0, h), _col_a if from_top else _col_b.lerp(_col_a, 0.55))
		if t < 1.0:
			var ey := y + h - 4.0 if from_top else y
			_canvas.draw_rect(Rect2(x, ey, w + 1.0, 4.0), _col_edge)
