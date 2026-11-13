class_name MapNodeArt
extends RefCounted

# Arte dos nós do mapa (soquete + peão + anel), compartilhada entre o mapa do
# jogo (MapView) e o mapa do tutorial (TutorialMapView), pra os dois ficarem
# idênticos. Tudo é composto na resolução nativa e só depois ampliado por
# inteiro, então nada se desalinha em nenhuma resolução de janela.

const NODE_SPRITE_SCALE: int = 2
const MAP_SPRITE_DIR: String = "res://assets/sprites/mapa/nodos/"

static var _pawn_socket_cache: Dictionary = {}
static var _ring_socket_cache: Dictionary = {}

static func sprite(file: String) -> Texture2D:
	return PixelUI.hud_texture(file, NODE_SPRITE_SCALE, MAP_SPRITE_DIR)

# Aplica a arte de UM nó (soquete/anel/selo) no botão. `sprite_name` é o arquivo
# do soquete já com sufixo de estado (ex.: "_escura"); `ind_name` o anel ou, se
# `overlay_name` não for vazio, o selo (concluído/bloqueado) que vai por cima.
static func apply(btn: Control, base: TextureRect, ind: TextureRect, node_sprite: String, sprite_name: String, ind_name: String, overlay_name: String, boss_suffix: String, with_pawn: bool) -> void:
	# Anel que não existe como arquivo (ex.: o estado "disponível", que não tem mais
	# anel) = sem anel: mostra só o nodo, sem erro de carregamento.
	if ind_name != "" and overlay_name == "" and not ResourceLoader.exists(MAP_SPRITE_DIR + ind_name + boss_suffix + ".png"):
		ind_name = ""
	var base_tex = sprite(sprite_name)
	if base_tex == null:
		# Variante (_escura) ausente no projeto: usa o soquete com símbolo
		# em vez de deixar o nó invisível.
		base_tex = sprite(node_sprite)
	if with_pawn:
		# Peão parado: composto no próprio sprite do soquete (encaixe exato).
		base_tex = socket_with_pawn(node_sprite)
	base.texture = base_tex
	base.visible = true
	if ind_name == "":
		ind.visible = false
	elif overlay_name == "":
		# Anel (atual/disponível/selecionado): soquete + peão + anel viram UMA
		# textura composta em resolução nativa.
		var ring_tex: Texture2D = socket_with_ring(node_sprite, ind_name + boss_suffix, with_pawn)
		ind.texture = ring_tex
		ind.size = ring_tex.get_size()
		ind.position = (btn.size - ind.size) / 2.0
		ind.visible = true
		base.visible = false
	else:
		ind.visible = true
		var ind_tex = sprite(ind_name + boss_suffix)
		ind.texture = ind_tex
		var ind_size = ind_tex.get_size()
		ind.size = ind_size
		ind.position = (btn.size - ind_size) / 2.0 + ring_nudge(ind_name + boss_suffix)

# Cria o TextureRect padrão que recebe essas texturas.
static func make_rect(tex: Texture2D) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# Soquete + peão do jogador compostos NA RESOLUÇÃO NATIVA (peça de 32 px
# centralizada no sprite do nó) e só depois ampliados por inteiro, então os dois
# nunca se desalinham — é uma imagem só.
# A cor da peça mudou nas Configurações: refaz as imagens compostas.
static var _skin_version: int = -1
static func _check_skin() -> void:
	if _skin_version != PieceSkin.version:
		_skin_version = PieceSkin.version
		_pawn_socket_cache.clear()
		_ring_socket_cache.clear()

# Cola o peão no meio do soquete. O anel do soquete tem relevo: em cima/à
# esquerda a borda de dentro é escura (sombra do buraco) e, com a peça
# encaixada, essa faixa escura de 1 px parecia um vão entre a peça e o nodo,
# como se a peça estivesse fora do centro. Aqui essa faixa (só onde ela é mais
# escura que o anel logo atrás) recebe a cor clara do anel, e a peça fica
# rente ao anel dos dois lados.
static func _blend_pawn(img: Image, pimg: Image) -> void:
	@warning_ignore("integer_division")
	var off := Vector2i((img.get_width() - pimg.get_width()) / 2, (img.get_height() - pimg.get_height()) / 2)
	img.blend_rect(pimg, Rect2i(Vector2i.ZERO, pimg.get_size()), off)
	var pw: int = pimg.get_width()
	var ph: int = pimg.get_height()
	var center := Vector2(off) + Vector2(pw, ph) / 2.0
	var in_pawn := func(x: int, y: int) -> bool:
		var px: int = x - off.x
		var py: int = y - off.y
		return px >= 0 and py >= 0 and px < pw and py < ph and pimg.get_pixel(px, py).a > 0.5
	var fixes: Array = []
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if in_pawn.call(x, y) or img.get_pixel(x, y).a < 0.5:
				continue
			if not (in_pawn.call(x + 1, y) or in_pawn.call(x - 1, y) or in_pawn.call(x, y + 1) or in_pawn.call(x, y - 1)):
				continue
			# um passo para fora (afastando do centro da peça)
			var d := Vector2(x + 0.5, y + 0.5) - center
			var step := Vector2i(signi(roundi(d.x / maxf(absf(d.x), absf(d.y)))), signi(roundi(d.y / maxf(absf(d.x), absf(d.y)))))
			var ox: int = x + step.x
			var oy: int = y + step.y
			if ox < 0 or oy < 0 or ox >= img.get_width() or oy >= img.get_height():
				continue
			var here: Color = img.get_pixel(x, y)
			var out: Color = img.get_pixel(ox, oy)
			if out.a > 0.5 and out.get_luminance() > here.get_luminance() + 0.08:
				fixes.append([x, y, out])
	for f in fixes:
		img.set_pixel(f[0], f[1], f[2])

static func socket_with_pawn(sprite_name: String) -> Texture2D:
	_check_skin()
	if _pawn_socket_cache.has(sprite_name):
		return _pawn_socket_cache[sprite_name]
	var base_tex: Texture2D = load(MAP_SPRITE_DIR + sprite_name + ".png")
	var pawn_tex: Texture2D = PieceSkin.player_texture(false)
	if base_tex == null or pawn_tex == null:
		return sprite(sprite_name)
	var img: Image = base_tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var pimg: Image = pawn_tex.get_image()
	pimg.convert(Image.FORMAT_RGBA8)
	_blend_pawn(img, pimg)
	img.resize(img.get_width() * NODE_SPRITE_SCALE, img.get_height() * NODE_SPRITE_SCALE, Image.INTERPOLATE_NEAREST)
	var tex = ImageTexture.create_from_image(img)
	_pawn_socket_cache[sprite_name] = tex
	return tex

# Quanto (em px nativos do PNG) o desenho do indicador precisa DESCER para ficar
# concêntrico com o soquete. Os anéis têm o desenho ~1-2 px acima do meio do
# arquivo (medido pelo centróide dos pixels de cada PNG), então não bastam
# "centralizar o arquivo". Valor em px nativos; ampliado por NODE_SPRITE_SCALE.
const _RING_DROP_NATIVE := {
	"ind_concluido": 1.5, "ind_concluido_boss": 2.5,
	"ind_bloqueado": 1.5, "ind_bloqueado_boss": 2.5,
}

const _RING_CUT_ROW := {}   # anéis novos são simétricos: sem corte de linha

static func ring_nudge(ind_file: String) -> Vector2:
	return Vector2(0.0, float(_RING_DROP_NATIVE.get(ind_file, 0.0)) * NODE_SPRITE_SCALE)


# Soquete (com o peão, se ele estiver parado aqui) + anel numa só imagem nativa,
# ampliada por inteiro. O anel é desenhado _RING_DROP_NATIVE px mais baixo
# porque o círculo dele não fica no meio do PNG.
static func socket_with_ring(sprite_name: String, ring_name: String, with_pawn: bool) -> Texture2D:
	var key = "%s|%s|%s" % [sprite_name, ring_name, with_pawn]
	_check_skin()
	if _ring_socket_cache.has(key):
		return _ring_socket_cache[key]
	var base_tex: Texture2D = load(MAP_SPRITE_DIR + sprite_name + ".png")
	var ring_tex: Texture2D = load(MAP_SPRITE_DIR + ring_name + ".png")
	if base_tex == null or ring_tex == null:
		return sprite(ring_name)
	var bimg: Image = base_tex.get_image()
	bimg.convert(Image.FORMAT_RGBA8)
	var rimg: Image = ring_tex.get_image()
	rimg.convert(Image.FORMAT_RGBA8)
	if with_pawn:
		var pawn_tex: Texture2D = PieceSkin.player_texture(false)
		if pawn_tex:
			var pimg: Image = pawn_tex.get_image()
			pimg.convert(Image.FORMAT_RGBA8)
			_blend_pawn(bimg, pimg)
	var canvas := Image.create(rimg.get_width(), rimg.get_height(), false, Image.FORMAT_RGBA8)
	@warning_ignore("integer_division")
	canvas.blend_rect(bimg, Rect2i(Vector2i.ZERO, bimg.get_size()), Vector2i((canvas.get_width() - bimg.get_width()) / 2, (canvas.get_height() - bimg.get_height()) / 2))
	var drop: int = int(_RING_DROP_NATIVE.get(ring_name, 0.0))
	var rh: int = rimg.get_height()
	var rw: int = rimg.get_width()
	if _RING_CUT_ROW.has(ring_name):
		# O interior do anel é 1 px mais baixo que a peça: tira UMA linha do
		# equador (parte reta dos lados, sem perda visual) e encaixa as duas
		# metades, o que encolhe o anel 1 px só na vertical.
		@warning_ignore("integer_division")
		var cut: int = int(_RING_CUT_ROW.get(ring_name, rh / 2))
		canvas.blend_rect(rimg, Rect2i(0, 0, rw, cut), Vector2i(0, drop))
		canvas.blend_rect(rimg, Rect2i(0, cut + 1, rw, rh - cut - 1), Vector2i(0, drop + cut))
	else:
		canvas.blend_rect(rimg, Rect2i(Vector2i.ZERO, rimg.get_size()), Vector2i(0, drop))
	canvas.resize(canvas.get_width() * NODE_SPRITE_SCALE, canvas.get_height() * NODE_SPRITE_SCALE, Image.INTERPOLATE_NEAREST)
	var tex = ImageTexture.create_from_image(canvas)
	_ring_socket_cache[key] = tex
	return tex
