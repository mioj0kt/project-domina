class_name BlockadeView
extends CanvasLayer

# Fim de duelo por BLOQUEIO TOTAL (o inimigo ainda tem peças, mas nenhuma jogada).
# Antes a vitória aparecia do nada; agora a cena explica o que houve:
#   1) cada peça inimiga recebe, uma por uma, um "X" vermelho com anel (travada);
#   2) uma faixa atravessa a tela: BLOQUEIO TOTAL! / o inimigo não tem jogadas;
#   3) a faixa sai e as marcas ficam até o painel de vitória aparecer por cima.
# Uso: await BlockadeView.play(host, cells) — host = o duelo (Node2D com
# board_offset/cell_size), cells = casas (Vector2i coluna, linha) das peças inimigas.

const C_RED := Color("#e0453c")
const C_GOLD := Color(1.0, 0.84, 0.2)
const C_DARK := Color(0.06, 0.03, 0.05)

var _marks: Array = []        # [{pos (tela), t (tempo desde que apareceu)}]
var _canvas: Control
var _t: float = 0.0
var _cell: float = 64.0

static func play(host: Node2D, cells: Array, shake_node: Node = null) -> BlockadeView:
	var v := BlockadeView.new()
	host.add_child(v)
	await v._run(host, cells, shake_node)
	return v

func _ready() -> void:
	layer = 90   # abaixo do painel de vitória (100)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de clicar no tabuleiro durante a cena
	_canvas.draw.connect(_draw_marks)
	add_child(_canvas)

func _process(delta: float) -> void:
	_t += delta
	for m in _marks:
		m["t"] = float(m["t"]) + delta
	_canvas.queue_redraw()

func _run(host: Node2D, cells: Array, shake_node: Node) -> void:
	var xf: Transform2D = host.get_global_transform_with_canvas()
	var off: Vector2 = host.get("board_offset")
	var cs: float = float(host.get("cell_size"))
	_cell = cs * xf.get_scale().x
	# escurece de leve o tabuleiro, para as marcas saltarem aos olhos
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	create_tween().tween_property(dim, "color:a", 0.28, 0.25)
	await get_tree().create_timer(0.3).timeout
	# as peças vão sendo marcadas uma a uma (mais rápido quando são muitas)
	var gap: float = clampf(1.2 / maxf(1.0, float(cells.size())), 0.08, 0.22)
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		var local: Vector2 = off + Vector2(c.x * cs + cs / 2.0, c.y * cs + cs / 2.0)
		_marks.append({"pos": xf * local, "t": 0.0})
		Sfx.play("bloqueio", -2.0, 1.0 + 0.04 * float(i))
		await get_tree().create_timer(gap).timeout
	await get_tree().create_timer(0.35).timeout
	await _banner(shake_node)

# Faixa no meio da tela, no mesmo estilo da MORTE SÚBITA, mas dourada (é vitória).
func _banner(shake_node: Node) -> void:
	var vp: Vector2 = _canvas.get_viewport_rect().size
	var band_h: float = 210.0
	var band := Control.new()
	band.position = Vector2(0.0, (vp.y - band_h) / 2.0)
	band.size = Vector2(vp.x, band_h)
	band.pivot_offset = Vector2(vp.x / 2.0, band_h / 2.0)
	band.scale = Vector2(1.0, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var fill := ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.color = Color(0.07, 0.05, 0.03, 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(fill)
	for top in [true, false]:
		var line := ColorRect.new()
		line.color = C_GOLD
		line.size = Vector2(vp.x, 6.0)
		line.position = Vector2(0.0, 0.0 if top else band_h - 6.0)
		band.add_child(line)
		var line2 := ColorRect.new()
		line2.color = C_RED
		line2.size = Vector2(vp.x, 2.0)
		line2.position = Vector2(0.0, 10.0 if top else band_h - 12.0)
		band.add_child(line2)
	var word := Label.new()
	word.text = "BLOQUEIO TOTAL!"
	word.position = Vector2(0.0, 24.0)
	word.size = Vector2(vp.x, 120.0)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 104)
	word.add_theme_color_override("font_color", C_GOLD)
	word.add_theme_color_override("font_outline_color", C_DARK)
	word.add_theme_constant_override("outline_size", 16)
	word.pivot_offset = word.size / 2.0
	word.scale = Vector2(1.5, 1.5)
	word.modulate.a = 0.0
	band.add_child(word)
	var sub := Label.new()
	sub.text = "O inimigo não tem mais nenhuma jogada possível"
	sub.position = Vector2(0.0, 140.0)
	sub.size = Vector2(vp.x, 44.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Color(0.94, 0.9, 0.81))
	sub.add_theme_color_override("font_outline_color", C_DARK)
	sub.add_theme_constant_override("outline_size", 8)
	sub.modulate.a = 0.0
	band.add_child(sub)

	Sfx.play("lei")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(band, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(word, "modulate:a", 1.0, 0.06).set_delay(0.06)
	tw.tween_property(word, "scale", Vector2.ONE, 0.16).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 1.0, 0.2).set_delay(0.25)
	await get_tree().create_timer(0.18).timeout
	if shake_node != null:
		Juice.shake(shake_node, 10.0, 0.22)
	await tw.finished
	await get_tree().create_timer(1.3).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(band, "scale:y", 0.0, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	out.tween_property(word, "modulate:a", 0.0, 0.1)
	out.tween_property(sub, "modulate:a", 0.0, 0.1)
	await out.finished
	band.queue_free()

# Marca de peça travada: anel vermelho pulsando + "X" em pixel com contorno escuro.
func _draw_marks() -> void:
	var px: float = maxf(2.0, roundf(_cell / 22.0))
	for m in _marks:
		var p: Vector2 = m["pos"]
		var k: float = clampf(float(m["t"]) / 0.16, 0.0, 1.0)
		var pop: float = 1.0 + 0.5 * (1.0 - k) * (1.0 - k)
		var r: float = _cell * 0.42 * pop
		var pulse: float = 0.55 + 0.25 * sin(_t * 6.0 + p.x * 0.01)
		_canvas.draw_arc(p, r, 0.0, TAU, 40, Color(C_DARK, 0.8 * k), px * 2.6)
		_canvas.draw_arc(p, r, 0.0, TAU, 40, Color(C_RED, pulse * k), px * 1.4)
		var h: float = r * 0.62
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			var a: Vector2 = p - d * h
			var b: Vector2 = p + d * h
			_canvas.draw_line(a, b, Color(C_DARK, k), px * 3.4)
			_canvas.draw_line(a, b, Color(C_RED, k), px * 1.9)
