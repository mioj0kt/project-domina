class_name SlabStyleBox
extends StyleBox
## Fundo de botão no estilo das placas do menu inicial (MenuBoard): corpo ameixa
## em faixas, contorno escuro com cantos cortados, filete creme por dentro,
## espessura escura embaixo e, na ponta esquerda, o ENCAIXE da peça: um buraco
## com o contorno do sprite da peça do jogador, onde o MenuPieceCursor a pousa.
## Estados: "idle" | "hover" (opção ativa: filete e borda do encaixe dourados) |
## "pressed" (afunda 1 pixel) | "dis" (apagado). `accent` puxa as cores do corpo e
## do filete para a cor do botão (verde = confirmar, vermelho = sair...).
## Desenhado por código em qualquer tamanho (sem esticar pixel).

const C_OUT := Color("1f161d")
const C_GOLD := Color("f0d27a")
const C_GOLD_SH := Color("c99a3a")
const C_CREAM := Color("e4d9bc")
const C_CREAM_SH := Color("b9a983")

var state: String = "idle"
var accent: Color = Color.WHITE

static var _sockets: Dictionary = {}       # "estado|cor" -> textura do encaixe


static func make(st: String, acc: Color, height: float) -> SlabStyleBox:
	var s := SlabStyleBox.new()
	s.state = st
	s.accent = acc
	var u: float = unit(height)
	s.content_margin_left = socket_left(height) + socket_size(height).x + u * 4.0
	s.content_margin_right = u * 6.0
	s.content_margin_top = u * 2.0
	s.content_margin_bottom = u * 4.0
	return s


# Tamanho do "pixel" da placa: 2 px nos botões normais, 1 px nos baixinhos.
static func unit(height: float) -> float:
	return 2.0 if height >= 40.0 else 1.0


# Escala (inteira) do encaixe: a MESMA da peça que pousa nele.
static func socket_scale(height: float) -> float:
	var tex: Texture2D = PieceSkin.player_texture()
	var th: float = float(tex.get_height()) if tex != null else 16.0
	return maxf(1.0, floorf((height - unit(height) * 6.0) / (th + 4.0)))


static func socket_size(height: float) -> Vector2:
	var tex: Texture2D = PieceSkin.player_texture()
	var ts := Vector2(tex.get_width(), tex.get_height()) if tex != null else Vector2(16, 16)
	return (ts + Vector2(4, 4)) * socket_scale(height)


static func socket_left(height: float) -> float:
	return unit(height) * 4.0


# Centro do encaixe, em coordenadas locais do botão (para a peça pousar ali).
static func socket_center(size: Vector2) -> Vector2:
	var h: float = size.y
	var u: float = unit(h)
	var body_h: float = h - u * 5.0
	return Vector2(socket_left(h) + socket_size(h).x * 0.5, u + body_h * 0.5).round()


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect


func _draw(ci: RID, rect: Rect2) -> void:
	var h: float = rect.size.y
	var u: float = unit(h)
	var p: Vector2 = rect.position
	var w: float = rect.size.x
	var dis: bool = state == "dis"
	var on: bool = state == "hover" or state == "pressed"
	var sink: float = u if state == "pressed" else 0.0
	var bands: Array = [Color("5a4855"), Color("4a3a46"), Color("43343f")]
	var line: Color = Color("8f7f5c")
	var line_hi: Color = C_CREAM_SH
	if on:
		bands = [Color("6e5868"), Color("5c4857"), Color("51404c")]
		line = C_GOLD_SH
		line_hi = C_GOLD
	elif dis:
		bands = [Color("3e3540"), Color("362e38"), Color("312a33")]
		line = Color("4f4650")
		line_hi = Color("5c535e")
	if accent != Color.WHITE and not dis:
		var a := Color(accent.r, accent.g, accent.b)
		for i in bands.size():
			bands[i] = (bands[i] as Color).lerp(a.darkened(0.55), 0.38)
		line = line.lerp(a, 0.55)
		if not on:
			line_hi = line_hi.lerp(a.lightened(0.25), 0.6)
	var body_h: float = h - u * 5.0
	# contorno com cantos cortados (o corpo afunda quando apertado)
	_rect(ci, Rect2(p + Vector2(u, sink), Vector2(w - u * 2.0, h - sink)), C_OUT)
	_rect(ci, Rect2(p + Vector2(0, u + sink), Vector2(w, h - u * 2.0 - sink)), C_OUT)
	# espessura embaixo
	_rect(ci, Rect2(p + Vector2(u, h - u * 4.0), Vector2(w - u * 2.0, u * 3.0)), Color("2a2029"))
	# corpo em faixas
	var cuts: Array = [0.0, 0.3, 0.7, 1.0]
	var bh: float = body_h - sink
	for i in 3:
		var y0: float = p.y + u + sink + roundf(bh * cuts[i] / u) * u
		var y1: float = p.y + u + sink + roundf(bh * cuts[i + 1] / u) * u
		_rect(ci, Rect2(Vector2(p.x + u, y0), Vector2(w - u * 2.0, y1 - y0)), bands[i])
	# filete (luz em cima e na esquerda, sombra embaixo e na direita)
	var top: float = p.y + u * 2.0 + sink
	_rect(ci, Rect2(Vector2(p.x + u * 2.0, top), Vector2(w - u * 4.0, u)), line_hi)
	_rect(ci, Rect2(Vector2(p.x + u * 2.0, top), Vector2(u, bh - u * 2.0)), line_hi)
	_rect(ci, Rect2(Vector2(p.x + u * 2.0, top + bh - u * 3.0), Vector2(w - u * 4.0, u)), line)
	_rect(ci, Rect2(Vector2(p.x + w - u * 3.0, top), Vector2(u, bh - u * 2.0)), line)
	# encaixe da peça
	var stex := socket_texture("on" if on else ("dis" if dis else "idle"))
	if stex != null:
		var k: float = socket_scale(h)
		var ssz: Vector2 = stex.get_size() * k
		var c: Vector2 = p + socket_center(rect.size) + Vector2(0, sink)
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2((c - ssz * 0.5).round(), ssz), stex.get_rid())


func _rect(ci: RID, r: Rect2, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.round(), r.size.round()), c)


# Encaixe: buraco com o contorno da peça (feito do alfa dela), parede de cima na
# sombra, de baixo pegando luz, contorno escuro e borda creme/dourada/cinza.
static func socket_texture(st: String) -> Texture2D:
	var src: Texture2D = PieceSkin.player_texture()
	if src == null:
		return null
	var key: String = "%s|%d" % [st, src.get_instance_id()]
	if _sockets.has(key):
		return _sockets[key]
	var im: Image = src.get_image()
	im.convert(Image.FORMAT_RGBA8)
	var sw: int = im.get_width()
	var sh: int = im.get_height()
	var pad: int = 2
	var w: int = sw + pad * 2
	var h: int = sh + pad * 2
	var m := PackedByteArray()
	m.resize(w * h)
	for y in sh:
		for x in sw:
			if im.get_pixel(x, y).a > 0.5:
				m[(y + pad) * w + x + pad] = 1
	var rim: Color = {"on": C_GOLD, "dis": Color("5c535e")}.get(st, C_CREAM_SH)
	var rim_hi: Color = {"on": Color("f8e6a0"), "dis": Color("6a616c")}.get(st, C_CREAM)
	var floor_c := Color("2c2129")
	var shadow_c := Color("170f16")
	var lit_c := Color("4a3a46") if st != "dis" else Color("3a3340")
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var at := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == 1
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			if at.call(x, y):
				if not at.call(x, y - 1) or not at.call(x, y - 2) or not at.call(x, y - 3):
					c = shadow_c
				elif not at.call(x, y + 1):
					c = lit_c
				elif not at.call(x - 1, y) or not at.call(x - 2, y):
					c = shadow_c.lerp(floor_c, 0.5)
				else:
					c = floor_c
			elif at.call(x - 1, y) or at.call(x + 1, y) or at.call(x, y - 1) or at.call(x, y + 1):
				c = C_OUT
			else:
				var near := false
				for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					if at.call(x + d.x, y + d.y):
						near = true
						break
				if near:
					c = rim_hi if y * 2 < h else rim
			out.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(out)
	_sockets[key] = tex
	return tex
