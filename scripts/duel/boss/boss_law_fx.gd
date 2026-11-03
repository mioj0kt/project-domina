class_name BossLawFx
extends Control

# Efeito exclusivo das Leis de Chefe: borda violeta-dourada pulsando, varredura
# de brilho diagonal e faíscas em forma de cruz subindo pela carta. Nenhuma
# outra carta do jogo usa esse conjunto — é o que diz "esta Lei é especial".
# Desenhado em passos de "pixel" (PX) pra combinar com a arte.

const BOSS_COLOR := Color(0.78, 0.45, 1.0)
const GOLD := Color(1.0, 0.86, 0.35)
const PX: float = 4.0
const SPARKS := 5

func _init(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5

func _process(_delta: float) -> void:
	queue_redraw()

func _px_rect(r: Rect2, c: Color) -> void:
	draw_rect(Rect2(r.position.snapped(Vector2(PX, PX)), r.size.snapped(Vector2(PX, PX))), c)

func _draw() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var w: float = size.x
	var h: float = size.y
	var pulse: float = 0.5 + 0.5 * sin(t * 3.2)
	var mix: float = 0.5 + 0.5 * sin(t * 1.4)
	var edge: Color = BOSS_COLOR.lerp(GOLD, mix)

	# Halo interno: 3 camadas de borda que respiram.
	# i = 0..2 fora da carta (aura), 3..4 sobre a moldura.
	for i in range(5):
		var a: float = (0.85 - i * 0.14) * (0.5 + 0.5 * pulse)
		if i >= 3:
			a = 0.7 * (0.4 + 0.6 * pulse)
		var o: float = PX * (2 - i) if i < 3 else PX * (i - 3)
		var c := Color(edge.r, edge.g, edge.b, a)
		_px_rect(Rect2(o, o, w - o * 2.0, PX), c)
		_px_rect(Rect2(o, h - o - PX, w - o * 2.0, PX), c)
		_px_rect(Rect2(o, o, PX, h - o * 2.0), c)
		_px_rect(Rect2(w - o - PX, o, PX, h - o * 2.0), c)

	# Cantos em ouro.
	var cl: float = PX * 4.0
	var gc := Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	for corner in [Vector2(PX, PX), Vector2(w - PX - cl, PX), Vector2(PX, h - PX * 2.0), Vector2(w - PX - cl, h - PX * 2.0)]:
		_px_rect(Rect2(corner, Vector2(cl, PX)), gc)
	for corner in [Vector2(PX, PX), Vector2(w - PX * 2.0, PX), Vector2(PX, h - PX - cl), Vector2(w - PX * 2.0, h - PX - cl)]:
		_px_rect(Rect2(corner, Vector2(PX, cl)), gc)

	# Varredura de brilho diagonal (a cada ~3,2 s).
	var cycle: float = fposmod(t, 3.2) / 1.1
	if cycle < 1.0:
		var x0: float = lerpf(-w * 0.4, w * 1.2, cycle)
		var band: float = w * 0.12
		var steps: int = int(h / PX)
		for i in range(steps):
			var y: float = i * PX
			var x: float = x0 - y * 0.55
			var l: float = clampf(x, 0.0, w)
			var r: float = clampf(x + band, 0.0, w)
			if r > l:
				_px_rect(Rect2(l, y, r - l, PX), Color(1, 1, 1, 0.22))

	# Faíscas em cruz subindo e piscando.
	for i in range(SPARKS):
		var ph: float = fposmod(t * (0.28 + 0.05 * (i % 3)) + i * 0.37, 1.0)
		var sx: float = fposmod(i * 53.0 + sin(t + i) * 8.0, w - PX * 8.0) + PX * 4.0
		var sy: float = h - ph * h
		var a: float = sin(ph * PI)
		var c := Color(1.0, 0.95, 0.7, a) if i % 2 == 0 else Color(0.9, 0.7, 1.0, a)
		_px_rect(Rect2(sx, sy, PX, PX), c)
		if a > 0.55:
			_px_rect(Rect2(sx - PX, sy, PX, PX), c)
			_px_rect(Rect2(sx + PX, sy, PX, PX), c)
			_px_rect(Rect2(sx, sy - PX, PX, PX), c)
			_px_rect(Rect2(sx, sy + PX, PX, PX), c)
