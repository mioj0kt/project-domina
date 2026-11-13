class_name DuelSandstorm
extends CanvasLayer

# Fundo extra do duelo travado DENTRO de uma tempestade de areia (nodo coberto no mapa do
# Deserto): rajadas de risquinhos de areia cruzando a tela inteira, um banho de cor de areia
# que pulsa com o vento e lençóis de areia mais grossos nas rajadas fortes. Fica logo acima
# do BiomeBackground e ATRÁS do tabuleiro e da interface (não atrapalha a leitura das peças).

const COLS: Array = [Color(1.0, 0.94, 0.72), Color(0.86, 0.66, 0.36), Color(0.52, 0.34, 0.17)]

var _canvas: Node2D
var _grains: Array = []     # [pos, velocidade, comprimento, tom, camada]
var _sheets: Array = []     # lençóis: [pos, velocidade, largura, altura]
var _t: float = 0.0
var _gust: float = 0.5
var _dir: float = 1.0

func _ready() -> void:
	layer = -99
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_storm)
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_dir = 1.0 if rng.randf() < 0.5 else -1.0
	for i in range(900):
		var tone: int = rng.randi() % 20
		_grains.append([
			Vector2(rng.randf(), rng.randf()), rng.randf_range(0.35, 0.95), rng.randi_range(2, 10),
			0 if tone < 6 else (1 if tone < 14 else 2), rng.randi() % 3,
		])
	for i in range(9):
		_sheets.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.18, 0.4), rng.randf_range(0.25, 0.6), rng.randi_range(2, 6)])

func _process(delta: float) -> void:
	_t += delta
	# o vento vem em ondas: calmaria, rajada, calmaria
	var wave: float = 0.5 + 0.5 * sin(_t * 0.55) * sin(_t * 0.23 + 1.3)
	_gust = lerpf(_gust, 0.45 + 0.75 * wave, minf(1.0, delta * 2.0))
	for g in _grains:
		var p: Vector2 = g[0]
		var v: float = float(g[1]) * delta * _gust * (0.7 + 0.3 * float(g[4]))
		p.x = fposmod(p.x + v * _dir, 1.0)
		p.y = fposmod(p.y + v * 0.34, 1.0)
		g[0] = p
	for s in _sheets:
		var q: Vector2 = s[0]
		q.x = fposmod(q.x + float(s[1]) * delta * _gust * _dir + 0.3, 1.6) - 0.3
		s[0] = q
	_canvas.queue_redraw()

func _draw_storm() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = maxf(2.0, round(vp.y / 540.0) * 2.0)
	# banho de areia que acompanha a força do vento
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.78, 0.52, 0.22, 0.10 + 0.14 * _gust))
	# lençóis de areia: faixas compridas e baixas, em degraus
	for s in _sheets:
		var q: Vector2 = s[0]
		var w: float = float(s[2]) * vp.x
		var h: int = int(s[3])
		var x0: float = floor(q.x * vp.x / u) * u
		var y0: float = floor(q.y * vp.y / u) * u
		for r in range(h):
			var inset: float = absf(float(r) - float(h - 1) / 2.0) * u * 6.0
			_canvas.draw_rect(Rect2(Vector2(x0 + inset, y0 + float(r) * u), Vector2(maxf(w - inset * 2.0, u), u)), Color(0.92, 0.74, 0.42, 0.10 + 0.10 * _gust))
	# risquinhos de pixel em diagonal (a cada 3 pixels para o lado, 1 para baixo)
	for g in _grains:
		var p: Vector2 = g[0]
		var col: Color = COLS[int(g[3])]
		col.a = (0.45 + 0.2 * float(g[4])) * (0.6 + 0.4 * _gust)
		var px := Vector2(floor(p.x * vp.x / u) * u, floor(p.y * vp.y / u) * u)
		var n: int = int(g[2])
		var k: int = 0
		while k < n:
			var seg: int = mini(3, n - k)
			var ox: float = -float(k + seg) * u if _dir > 0.0 else float(k) * u
			@warning_ignore("integer_division")
			_canvas.draw_rect(Rect2(px + Vector2(ox, -float(k / 3) * u), Vector2(float(seg) * u, u)), col)
			k += 3
