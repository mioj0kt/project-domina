class_name MetaTour
extends CanvasLayer
# Mini tutorial do GRIMÓRIO: holofote (escurece o resto) + caixa de diálogo
# com uma seta apontando para o alvo, e PRÓXIMO / PULAR. Roda sozinho na 1ª visita e de novo pelo botão "?".
# Os passos moram em STEPS; o alvo de cada um é resolvido por `target_provider`
# (Callable id -> Rect2 global; Rect2() = sem alvo) e `tab_switcher` (Callable
# int -> void) troca a aba do Grimório quando o passo pede.

signal finished()

const C_GOLD := Color(0.85, 0.64, 0.25)
const C_CREAM := Color(0.94, 0.9, 0.81)
const DIM_ALPHA: float = 0.7
const FRAME_PAD: float = 8.0
const PANEL_W: float = 640.0
const PANEL_BG := Color(0.08, 0.09, 0.13, 0.97)
const ARROW: float = 22.0
const GAP: float = 30.0

# target: "coroas" | "tabs" | "grid" | "side" | "" ; place: onde fica a caixa em relação ao alvo
# ("below" | "left" | "inside" | "center"); tab: -1 mantém, 0 Leis, 1 Cartas
const STEPS: Array[Dictionary] = [
	{"text": "Bem-vindo ao GRIMÓRIO! Aqui você usa as COROAS para desbloquear Leis e Cartas novas, que passam a poder aparecer nas suas próximas runs.",
		"target": "", "place": "center", "tab": 0},
	{"text": "Estas são as suas COROAS. Você ganha Coroas vencendo duelos, e mesmo que perca a run, as que ganhou continuam com você.",
		"target": "coroas", "place": "below", "tab": 0},
	{"text": "Esta aba guarda as LEIS. O BAÚ DE LEIS guarda Leis que você ainda não conhece.",
		"target": "piles", "place": "below", "tab": 0},
	{"text": "Clique no baú e pague com Coroas para abrir: a Lei é sorteada entre as que você ainda não tem. Ela fica desbloqueada para sempre e nunca repete.",
		"target": "piles", "place": "below", "tab": 0},
	{"text": "A aba de CARTAS tem o seu próprio baú e funciona do mesmo jeito. Comum, rara, épica ou lendária: quanto mais rara, mais difícil de sair!",
		"target": "piles", "place": "below", "tab": 1},
	{"text": "Depois de desbloquear algo, você pode LEVAR para a MOCHILA. O que estiver na mochila já começa a próxima run com você.",
		"target": "side", "place": "left", "tab": 1},
	{"text": "Levar custa Coroas a cada run, e cada item na mochila deixa o próximo mais caro. Escolha com cuidado o que vale a pena levar.",
		"target": "side", "place": "left", "tab": 1},
	{"text": "É isso! Se quiser rever este guia depois, clique no botão \"?\" do Grimório.",
		"target": "", "place": "center", "tab": -1},
]

# Passos do guia: por padrão os do Grimório; outras telas (ex.: fim de run)
# trocam por uma lista própria antes de chamar start().
var steps: Array[Dictionary] = STEPS
var target_provider: Callable
var tab_switcher: Callable

var _step: int = -1
var _rect: Rect2 = Rect2()
var _arrow_tip: Vector2 = Vector2.ZERO
var _arrow_dir: Vector2 = Vector2.ZERO   # de onde a seta sai, ZERO = sem seta
var _arrow_base: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _overlay: Control
var _panel: PanelContainer
var _text: Label
var _next_btn: Button
var _count: Label

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Overlay: escurece tudo, deixa o alvo "furado" e bloqueia cliques no resto.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(PANEL_BG, C_GOLD, 16))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(PANEL_W, 0)
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size", 18)
	_count.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
	v.add_child(_count)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(PANEL_W, 0)
	_text.add_theme_font_size_override("font_size", 25)
	_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(220, 48)
	_next_btn.add_theme_font_size_override("font_size", 22)
	_next_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.skin_button(_next_btn, Color(0.4, 0.85, 0.45), "", "icone_confirmar")
	_next_btn.pressed.connect(_advance)
	row.add_child(_next_btn)
	var skip := Button.new()
	skip.text = "PULAR"
	skip.custom_minimum_size = Vector2(160, 48)
	skip.add_theme_font_size_override("font_size", 22)
	skip.focus_mode = Control.FOCUS_NONE
	PixelUI.skin_button(skip, Color(0.6, 0.6, 0.65))
	skip.pressed.connect(_finish)
	row.add_child(skip)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_overlay.queue_redraw()

func is_running() -> bool:
	return visible

func start() -> void:
	_step = -1
	visible = true
	_advance()

func _advance() -> void:
	_step += 1
	if _step >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[_step]
	if int(s["tab"]) >= 0 and tab_switcher.is_valid():
		tab_switcher.call(int(s["tab"]))
	# Espera o Grimório reconstruir a aba antes de medir o alvo.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible or _step >= steps.size():
		return
	_rect = Rect2()
	if str(s["target"]) != "" and target_provider.is_valid():
		_rect = target_provider.call(str(s["target"]))
	_text.text = s["text"]
	_count.text = "%d/%d" % [_step + 1, steps.size()]
	_next_btn.text = "ENTENDIDO" if _step == steps.size() - 1 else "PRÓXIMO"
	_panel.reset_size()
	await get_tree().process_frame
	_place_panel(str(s.get("place", "center")))
	_overlay.queue_redraw()

# Posiciona a caixa em relação ao alvo e define a seta que aponta para ele.
func _place_panel(place: String) -> void:
	var vp := _overlay.size
	var sz := _panel.size
	var pos := (vp - sz) / 2.0
	_arrow_dir = Vector2.ZERO
	if _rect.size != Vector2.ZERO:
		var r := _rect
		match place:
			"below":
				pos = Vector2(r.end.x - sz.x, r.end.y + GAP + FRAME_PAD)
				pos.x = clampf(pos.x, 20.0, vp.x - sz.x - 20.0)
				var tip := Vector2(clampf(r.get_center().x, pos.x + 40.0, pos.x + sz.x - 40.0), r.end.y + FRAME_PAD + 4.0)
				_set_arrow(tip, Vector2(0, -1), pos, sz)
			"above":
				# Caixa acima do alvo (alvos perto da borda de baixo da tela).
				pos = Vector2(r.get_center().x - sz.x / 2.0, r.position.y - sz.y - GAP - FRAME_PAD)
				pos.x = clampf(pos.x, 20.0, vp.x - sz.x - 20.0)
				pos.y = maxf(pos.y, 20.0)
				_arrow_tip = Vector2(clampf(r.get_center().x, pos.x + 40.0, pos.x + sz.x - 40.0), r.position.y - FRAME_PAD - 4.0)
				_arrow_dir = Vector2(0, 1)
				_arrow_base = Vector2(_arrow_tip.x, pos.y + sz.y)
			"left":
				pos = Vector2(r.position.x - sz.x - GAP - FRAME_PAD, r.position.y + 120.0)
				pos.x = maxf(pos.x, 20.0)
				var tip2 := Vector2(r.position.x - FRAME_PAD - 4.0, clampf(pos.y + 60.0, r.position.y + 30.0, r.end.y - 30.0))
				_set_arrow(tip2, Vector2(1, 0), pos, sz)
			"inside":
				# Dentro da área, na parte baixa; a seta sobe até a 1ª fileira.
				pos = Vector2(r.get_center().x - sz.x / 2.0, r.end.y - sz.y - 50.0)
				var tip3 := Vector2(r.get_center().x, r.position.y + 150.0)
				_set_arrow(tip3, Vector2(0, 1), pos, sz)
	_panel.position = pos

# Seta: ponta em `tip`; sai da borda da caixa que olha para o alvo.
func _set_arrow(tip: Vector2, from_side: Vector2, pos: Vector2, sz: Vector2) -> void:
	_arrow_tip = tip
	_arrow_dir = from_side
	if from_side.y < 0:      # caixa abaixo do alvo: seta sai da borda de cima
		_arrow_base = Vector2(clampf(tip.x, pos.x + 40.0, pos.x + sz.x - 40.0), pos.y)
	elif from_side.y > 0:    # caixa dentro/embaixo: seta sai da borda de cima, apontando p/ cima
		_arrow_base = Vector2(clampf(tip.x, pos.x + 40.0, pos.x + sz.x - 40.0), pos.y)
	else:                    # caixa à esquerda do alvo: seta sai da borda direita
		_arrow_base = Vector2(pos.x + sz.x, clampf(tip.y, pos.y + 40.0, pos.y + sz.y - 40.0))

func _finish() -> void:
	visible = false
	_step = -1
	finished.emit()

func _draw_overlay() -> void:
	var full := Rect2(Vector2.ZERO, _overlay.size)
	var dim := Color(0.03, 0.02, 0.05, DIM_ALPHA)
	if _rect.size == Vector2.ZERO:
		_overlay.draw_rect(full, dim)
		return
	var r := _rect.grow(FRAME_PAD)
	r = r.intersection(full)
	# 4 faixas ao redor do alvo
	_overlay.draw_rect(Rect2(0, 0, full.size.x, r.position.y), dim)
	_overlay.draw_rect(Rect2(0, r.end.y, full.size.x, full.size.y - r.end.y), dim)
	_overlay.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	_overlay.draw_rect(Rect2(r.end.x, r.position.y, full.size.x - r.end.x, r.size.y), dim)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var col := C_GOLD.lerp(Color(1.0, 0.95, 0.6), pulse)
	_overlay.draw_rect(r, col, false, 4.0)
	_draw_arrow()

func _draw_arrow() -> void:
	if _arrow_dir == Vector2.ZERO or _rect.size == Vector2.ZERO:
		return
	var axis := (_arrow_tip - _arrow_base)
	var len_ := minf(axis.length(), 70.0)
	if axis.length() < 1.0:
		return
	var d := axis.normalized()
	var n := Vector2(-d.y, d.x)
	var tip := _arrow_base + d * len_
	var b1 := _arrow_base + n * ARROW
	var b2 := _arrow_base - n * ARROW
	# contorno dourado + miolo igual ao da caixa (a base fica escondida sob a caixa)
	var back := d * 8.0
	var pts := PackedVector2Array([b1 - back, tip, b2 - back])
	_overlay.draw_colored_polygon(pts, C_GOLD)
	var c := (pts[0] + pts[1] + pts[2]) / 3.0
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.72)
	_overlay.draw_colored_polygon(inner, PANEL_BG)
