class_name RuleChargeBadge
extends Control

## Contador de cargas no canto de uma Lei do quadro de Leis do duelo (Lei da
## Carga, Vingança, Contra-Ataque...). Lê RuleCard.get_charge_state() a cada
## quadro: uma luzinha por carga numa plaquinha fina; cheia = dourada e piscando;
## quando o valor muda dá um pulinho. Some sozinho se a Lei não usa cargas.

const FONT := preload("res://assets/fonts/m5x7.ttf")
const C_BG := Color8(31, 22, 29)
const C_EDGE := Color8(150, 96, 28)
const C_TEXT := Color8(240, 230, 207)
const C_FULL := Color8(240, 210, 122)

var rule: RuleCard
var _last: int = -999
var _pop: float = 0.0
var _t: float = 0.0

func setup(p_rule: RuleCard, slot_size: float) -> void:
	rule = p_rule
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(slot_size, slot_size)
	position = Vector2.ZERO
	z_index = 5

func _process(delta: float) -> void:
	if rule == null:
		return
	_t += delta
	var st: Array = rule.get_charge_state()
	visible = st.size() >= 2
	if not visible:
		return
	var cur: int = int(st[0])
	if cur != _last:
		if _last != -999:
			_pop = 1.0
		_last = cur
	_pop = maxf(0.0, _pop - delta * 4.0)
	queue_redraw()

func _draw() -> void:
	if rule == null:
		return
	var st: Array = rule.get_charge_state()
	if st.size() < 2:
		return
	var cur: int = int(st[0])
	var mx: int = int(st[1])
	var full: bool = mx > 0 and cur >= mx
	var blink: bool = full and int(_t * 3.0) % 2 == 0
	# Discreto: só uma fileira de "luzinhas" (uma por carga) numa plaquinha fina
	# no canto de cima, à direita. Com muitas cargas (mais de 6), vira um "3/8" pequeno.
	var u: float = maxf(2.0, round(size.x / 80.0))
	var pip: float = u * 2.0
	var gap: float = u
	var use_pips: bool = mx > 0 and mx <= 6
	var txt: String = "%d/%d" % [cur, mx]
	var fs: int = 16
	var inner_w: float = (pip * mx + gap * (mx - 1)) if use_pips else FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var inner_h: float = pip if use_pips else fs * 0.7
	var w: float = round(inner_w + u * 4.0)
	var h: float = round(inner_h + u * 4.0)
	var s: float = 1.0 + 0.3 * sin(_pop * PI)
	var center := Vector2(size.x - w * 0.5 - u * 3.0, h * 0.5 + u * 3.0)
	draw_set_transform(center, 0.0, Vector2(s, s))
	var r := Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h))
	draw_rect(r.grow(u * 0.5), (C_FULL if blink else C_EDGE) if full else Color8(90, 72, 85))
	draw_rect(r, Color(C_BG, 0.92))
	if use_pips:
		var x0: float = r.position.x + u * 2.0
		var y0: float = r.position.y + u * 2.0
		for i in range(mx):
			var on: bool = i < cur
			var c: Color = (C_FULL if full else Color8(217, 162, 58)) if on else Color8(74, 58, 70)
			var pr := Rect2(Vector2(x0 + (pip + gap) * i, y0), Vector2(pip, pip))
			draw_rect(pr, c)
			if on:
				draw_rect(Rect2(pr.position, Vector2(u, u)), Color(1, 0.96, 0.8, 0.9))   # brilho
	else:
		draw_string(FONT, Vector2(r.position.x, r.position.y + h * 0.5 + fs * 0.28), txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, C_FULL if full else C_TEXT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
