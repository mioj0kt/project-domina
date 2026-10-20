class_name BoardSkin

# Gera o visual do tabuleiro (moldura de madeira + casinhas) a partir de
# UM ÚNICO sprite de referência 8x8 (assets/sprites/board/board_frame_8x8.png),
# fatiando-o em código: extraímos TODAS as 64 casinhas (cada uma com um
# padrão de veio de madeira diferente — 32 claras + 32 escuras, nenhuma
# repetida no sprite original) e a moldura em 9 pedaços (4 cantos fixos +
# 4 bordas esticáveis), e remontamos isso pra QUALQUER tamanho de tabuleiro
# (6x6, 10x10, 8x10, etc — ver map_generator.POSSIBLE_BOARD_SIZES) variando
# o padrão usado em cada casinha, sem precisar de uma arte nova por tamanho.
#
# Se o arquivo não existir, has_sprite() retorna false e quem chama cai de
# volta pro desenho antigo (retângulos coloridos) — nada quebra se você
# ainda não tiver colocado o sprite.

# Estilos de tabuleiro. Cada um é UM sprite 8x8 fatiado em código e
# remontado pra qualquer tamanho:
#  - SKIN_WOOD: duelos do bioma Floresta (moldura grossa; as 64 casinhas
#    têm veio diferente, então qualquer uma pode ser usada em qualquer lugar).
#  - SKIN_TUTORIAL: duelos do tutorial (moldura fina; a maioria das casinhas
#    é lisa e só algumas têm riscos/manchas — essas "com defeito" entram
#    esparsas e nunca coladas ou repetidas por perto, ver _build_layout).
const SKIN_WOOD := "wood"
const SKIN_TUTORIAL := "tutorial"
#  - SKIN_DESERT: duelos do bioma Deserto. Não usa um sprite 8x8: monta o
#    tabuleiro com as MESMAS casas e a MESMA borda em folha do mapa do deserto
#    (ForestBackground), em qualquer tamanho. A borda é desenhada POR CIMA das
#    casas (areia/pedra acumulada), como no mapa.
const SKIN_DESERT := "desert"

const _DESERT_DIR := "res://assets/sprites/map/deserto/tabuleiro/"
const _DESERT_LIGHT: Array[String] = [
	"casa_clara_areia", "casa_clara_areia", "casa_clara_ondulada", "casa_clara_rachada",
	"casa_clara_textura_1", "casa_clara_textura_2", "casa_clara_textura_3",
	"casa_clara_textura_4", "casa_clara_textura_5", "casa_clara_textura_6",
]
const _DESERT_DARK: Array[String] = ["casa_escura", "casa_escura_2", "casa_escura_3"]
const _DESERT_FRAME := "borda/borda_tabuleiro_13x12"
# Medidas nativas (px) da folha da borda; iguais às de ForestBackground.
const _D_TILE: float = 26.0
const _D_COLS: int = 13
const _D_ROWS: int = 12
const _D_MARGIN_X: float = 8.0
const _D_MARGIN_Y: float = 10.0
const _D_SIDE_W: float = 22.0
const _D_TOP_H: float = 22.0
const _D_BOT_H: float = 26.0

# path, moldura (fração do lado da imagem), grade de referência e se o
# estilo usa defeitos esparsos.
const _SKINS := {
	SKIN_WOOD: {"path": "res://assets/sprites/board/board_floresta_8x8.png", "frame_frac": 18.0 / 292.0, "sparse": false, "segmented_frame": true},
	SKIN_TUTORIAL: {"path": "res://assets/sprites/board/board_tutorial_8x8.png", "frame_frac": 8.0 / 272.0, "sparse": true},
}
const _REF_GRID: int = 8

# Convenção: casinha do canto superior-esquerdo (linha 0, coluna 0) da
# arte de referência é CLARA — igual ao padrão de damas e igual ao que
# Board._draw() já assume ((r+c)%2==0 -> clara).
const _TOP_LEFT_IS_LIGHT: bool = true

# Estilo esparso: nota de "sujeira" de cada casinha = nº de pixels do miolo
# diferentes da cor dominante dela. Até _CLEAN_MAX é lisa; acima de
# _HEAVY_MIN é mancha grande; no meio, riscos leves.
const _CLEAN_MAX: int = 4
const _HEAVY_MIN: int = 30
# Chance (em %) de uma casinha receber defeito leve / pesado (sujeito às
# regras de distância — na prática sai bem menos que isso).
const _MINOR_CHANCE: int = 22
const _HEAVY_CHANCE: int = 7
# Distância mínima (em casinhas, Chebyshev) entre duas casinhas com defeito,
# e entre duas usando o MESMO desenho de defeito.
const _DEFECT_GAP: int = 2
const _SAME_VARIANT_GAP: int = 5

static var _skins: Dictionary = {}   # id -> dados carregados
static var _layouts: Dictionary = {} # "id:rows:cols" -> Array[int] (índice do desenho por casinha)

static func _ensure_loaded(skin_id: String = SKIN_WOOD) -> void:
	if _skins.has(skin_id):
		return
	var cfg = _SKINS.get(skin_id, null)
	if cfg == null or not ResourceLoader.exists(cfg["path"]):
		_skins[skin_id] = null
		return

	var tex: Texture2D = load(cfg["path"])
	var tex_size = tex.get_size()
	var margin = tex_size.x * cfg["frame_frac"]
	var tile_px = (tex_size.x - 2.0 * margin) / float(_REF_GRID)
	var data := {
		"tex": tex, "size": tex_size, "margin": margin, "tile_px": tile_px,
		"light": [], "dark": [], "sparse": cfg["sparse"],
		"segmented": cfg.get("segmented_frame", false), "edge_detail": [],
	}
	var img: Image = tex.get_image() if cfg["sparse"] else null
	for r in range(_REF_GRID):
		for c in range(_REF_GRID):
			var region = Rect2(margin + c * tile_px, margin + r * tile_px, tile_px, tile_px)
			var is_light = ((r + c) % 2 == 0) == _TOP_LEFT_IS_LIGHT
			var info = _dirt_score(img, region)
			data["light" if is_light else "dark"].append({"region": region, "score": info["score"], "base": info["base"]})
	if data["segmented"]:
		data["edge_detail"] = _edge_detail_scores(tex.get_image(), margin, tile_px)
	if cfg["sparse"]:
		# Casinha com tom de fundo diferente do dominante do grupo conta como
		# "leve" (aparece pouco), mesmo sem riscos — senão vira mancha de cor.
		for key in ["light", "dark"]:
			var tally := {}
			for t in data[key]:
				tally[t["base"]] = tally.get(t["base"], 0) + 1
			var dom := ""
			var dom_n := 0
			for b in tally:
				if tally[b] > dom_n:
					dom_n = tally[b]
					dom = b
			for t in data[key]:
				if t["base"] != dom:
					t["score"] = maxi(t["score"], _CLEAN_MAX + 1)
	_skins[skin_id] = data

# Moldura "segmentada": a borda da arte (8 casinhas de comprimento) é fatiada
# em 8 pedaços de 1 casinha. Num tabuleiro 8x8 saem na ordem original (a arte
# exata); em outros tamanhos os pedaços são sorteados, com os que têm detalhe
# (folhagem, cogumelos) esparsos e nunca colados, e o resto liso — assim os
# detalhes não esticam nem se repetem em fila.
# Nota de detalhe de cada pedaço: [topo, base, esquerda, direita] -> 8 notas.
static func _edge_detail_scores(img: Image, margin: float, tile_px: float) -> Array:
	var w = img.get_width()
	var h = img.get_height()
	var m = int(margin)
	var out: Array = []
	for edge in range(4):
		var arr: Array = []
		for k in range(_REF_GRID):
			var n = 0
			var a = int(margin + k * tile_px)
			var b = int(margin + (k + 1) * tile_px)
			for t in range(a, b):
				for u in range(m):
					var px: Color
					match edge:
						0: px = img.get_pixel(t, u)
						1: px = img.get_pixel(t, h - m + u)
						2: px = img.get_pixel(u, t)
						_: px = img.get_pixel(w - m + u, t)
					if px.a < 0.5:
						continue
					var green = px.g > px.r + 0.04 and px.g > px.b + 0.04
					var red = px.r > px.g + 0.2 and px.r > px.b + 0.2
					if green or red:
						n += 1
			arr.append(n)
		out.append(arr)
	return out

# Qual pedaço (0..7) usar na posição i de uma borda com `count` casinhas.
static func _edge_segment(skin: Dictionary, edge: int, i: int, count: int, prev: Array) -> int:
	if count == _REF_GRID:
		return i
	var scores: Array = skin["edge_detail"][edge]
	var plain: Array = []
	var detailed: Array = []
	for k in range(_REF_GRID):
		if scores[k] <= 6:
			plain.append(k)
		else:
			detailed.append(k)
	var roll = _variant_index(i + 31 * edge, count + 7, 100)
	var last_detail = prev[1]
	if not detailed.is_empty() and roll < 16 and i - last_detail >= 4 and i > 0 and i < count - 1:
		prev[1] = i
		var d = detailed[_variant_index(i, edge + 3, detailed.size())]
		if d == prev[0] and detailed.size() > 1:
			d = detailed[(detailed.find(d) + 1) % detailed.size()]
		prev[0] = d
		return d
	if plain.is_empty():
		return _variant_index(i, edge, _REF_GRID)
	var pick = plain[_variant_index(i * 3 + edge, count * 5 + 1, plain.size())]
	if pick == prev[2] and plain.size() > 1:
		pick = plain[(plain.find(pick) + 1) % plain.size()]
	prev[2] = pick
	return pick

# Nº de pixels do miolo da casinha que fogem da cor dominante dela.
static func _dirt_score(img: Image, region: Rect2) -> Dictionary:
	if img == null:
		return {"score": 0, "base": ""}
	var inset = int(round(region.size.x * 0.0625))
	var x0 = int(region.position.x) + inset
	var y0 = int(region.position.y) + inset
	var x1 = int(region.end.x) - inset
	var y1 = int(region.end.y) - inset
	var counts := {}
	var total := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var col = img.get_pixel(x, y).to_html()
			counts[col] = counts.get(col, 0) + 1
			total += 1
	var best := 0
	var best_col := ""
	for k in counts:
		if counts[k] > best:
			best = counts[k]
			best_col = k
	return {"score": total - best, "base": best_col}

# Escolhe, de forma determinística (mesma casinha sempre cai no mesmo
# padrão — sem "piscar" a cada redraw), qual das variações do pool usar
# pra posição (r, c). Mistura linha e coluna pra não repetir o mesmo
# padrão em listras/colunas inteiras.
static func _variant_index(r: int, c: int, count: int) -> int:
	if count <= 1:
		return 0
	var h = (r * 73856093) ^ (c * 19349663)
	if h < 0:
		h = -h
	return h % count

static var _desert: Dictionary = {}

static func _ensure_desert() -> void:
	if not _desert.is_empty():
		return
	var light: Array = []
	var dark: Array = []
	for n in _DESERT_LIGHT:
		var p: String = _DESERT_DIR + "casas/" + n + ".png"
		if ResourceLoader.exists(p):
			light.append(load(p))
	for n in _DESERT_DARK:
		var p2: String = _DESERT_DIR + "casas/" + n + ".png"
		if ResourceLoader.exists(p2):
			dark.append(load(p2))
	var fp: String = _DESERT_DIR + _DESERT_FRAME + ".png"
	var frame: Texture2D = load(fp) if ResourceLoader.exists(fp) else null
	_desert = {"light": light, "dark": dark, "frame": frame, "ok": not light.is_empty() and not dark.is_empty() and frame != null}

# A borda deste estilo cobre a beirada das casas: quem desenha deve chamar
# draw_tiles ANTES de draw_frame.
static func frame_over_tiles(skin_id: String) -> bool:
	return skin_id == SKIN_DESERT

static func has_sprite(skin_id: String = SKIN_WOOD) -> bool:
	if skin_id == SKIN_DESERT:
		_ensure_desert()
		return _desert["ok"]
	_ensure_loaded(skin_id)
	return _skins[skin_id] != null

# Espessura da moldura (em pixels de tela) pro cell_size atual — usada por
# quem centraliza o tabuleiro na viewport, já que a moldura cresce PRA
# FORA do retângulo das casinhas (ver draw_frame).
static func get_frame_px(cell_size: float, skin_id: String = SKIN_WOOD) -> float:
	if skin_id == SKIN_DESERT:
		return cell_size * (_D_MARGIN_Y / _D_TILE)
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return 0.0
	return cell_size * (d["margin"] / d["tile_px"])

# Monta (e guarda) qual desenho cada casinha usa, só pro estilo esparso.
# Determinístico por (estilo, linhas, colunas): não pisca entre redraws.
# Regras: lisas são a regra; defeito leve/pesado só com sorteio baixo, nunca
# a menos de _DEFECT_GAP casinhas de outro defeito, e o mesmo desenho de
# defeito só reaparece a _SAME_VARIANT_GAP ou mais de distância. Quando
# vários servem, escolhe o desenho menos usado até agora.
static func _build_layout(skin_id: String, rows: int, cols: int) -> Array:
	_ensure_loaded(skin_id)
	var key = "%s:%d:%d" % [skin_id, rows, cols]
	if _layouts.has(key):
		return _layouts[key]
	var d = _skins[skin_id]
	var out: Array = []
	out.resize(rows * cols)
	var defect_at := {}   # Vector2i -> índice do desenho (dentro do pool)
	var use_count := {}   # "L3"/"D7" -> vezes usado
	for r in range(rows):
		for c in range(cols):
			var is_light = (r + c) % 2 == 0
			var pool: Array = d["light" if is_light else "dark"]
			var roll = _variant_index(r + 11, c + 5, 100)
			var want = 0  # 0 lisa, 1 leve, 2 pesada
			if roll < _HEAVY_CHANCE:
				want = 2
			elif roll < _MINOR_CHANCE:
				want = 1
			var pick := -1
			if want > 0 and _defect_clear(defect_at, r, c, _DEFECT_GAP):
				pick = _pick_variant(pool, want, is_light, r, c, defect_at, use_count)
			if pick < 0:
				pick = _pick_clean(pool, is_light, r, c, use_count)
			else:
				defect_at[Vector2i(c, r)] = pick
			out[r * cols + c] = pick
	_layouts[key] = out
	return out

static func _defect_clear(defect_at: Dictionary, r: int, c: int, gap: int) -> bool:
	for dr in range(-gap, gap + 1):
		for dc in range(-gap, gap + 1):
			if defect_at.has(Vector2i(c + dc, r + dr)):
				return false
	return true

static func _pick_variant(pool: Array, want: int, is_light: bool, r: int, c: int, defect_at: Dictionary, use_count: Dictionary) -> int:
	var best := -1
	var best_n := 1 << 30
	var start = _variant_index(r, c, pool.size())
	for k in range(pool.size()):
		var i = (start + k) % pool.size()
		var sc: int = pool[i]["score"]
		var kind = 0 if sc <= _CLEAN_MAX else (2 if sc >= _HEAVY_MIN else 1)
		if kind != want:
			continue
		# Mesmo desenho por perto? Pula.
		var near := false
		for dr in range(-_SAME_VARIANT_GAP, _SAME_VARIANT_GAP + 1):
			for dc in range(-_SAME_VARIANT_GAP, _SAME_VARIANT_GAP + 1):
				var p = Vector2i(c + dc, r + dr)
				if defect_at.has(p) and defect_at[p] == i and ((p.y + p.x) % 2 == 0) == is_light:
					near = true
		if near:
			continue
		var n = use_count.get(_vkey(is_light, i), 0)
		if n < best_n:
			best_n = n
			best = i
	if best >= 0:
		use_count[_vkey(is_light, best)] = best_n + 1
	return best

static func _pick_clean(pool: Array, _is_light: bool, r: int, c: int, _use_count: Dictionary) -> int:
	var cleans: Array = []
	for i in range(pool.size()):
		if pool[i]["score"] <= _CLEAN_MAX:
			cleans.append(i)
	if cleans.is_empty():
		return _variant_index(r, c, pool.size())
	return cleans[_variant_index(r, c, cleans.size())]

static func _vkey(is_light: bool, i: int) -> String:
	return ("L%d" if is_light else "D%d") % i

# Desenha as N x M casinhas. Estilo "wood": qualquer uma das 64 variações,
# escolhida por hash. Estilo "tutorial": maioria lisa + defeitos esparsos
# (ver _build_layout). tint_light/tint_dark multiplicam a cor (branco = sem
# alteração; usado pra rebater o tema difícil/chefe sem perder a textura).
static func draw_tiles(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint_light: Color = Color.WHITE, tint_dark: Color = Color.WHITE, skin_id: String = SKIN_WOOD) -> void:
	if skin_id == SKIN_DESERT:
		_draw_desert_tiles(canvas, board_offset, rows, cols, cell_size, tint_light, tint_dark)
		return
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return
	var layout: Array = _build_layout(skin_id, rows, cols) if d["sparse"] else []

	for r in range(rows):
		for c in range(cols):
			var rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
			var is_light = (r + c) % 2 == 0
			var pool: Array = d["light" if is_light else "dark"]
			var idx = layout[r * cols + c] if d["sparse"] else _variant_index(r, c, pool.size())
			var tint = tint_light if is_light else tint_dark
			canvas.draw_texture_rect_region(d["tex"], rect, pool[idx]["region"], tint)

# Desenha a moldura de madeira em volta do retângulo do tabuleiro, como um
# 9-slice manual: os 4 cantos são desenhados no tamanho original (sem
# esticar, pra não deformar o entalhe), e as 4 bordas esticam só no eixo
# que acompanha o tamanho do tabuleiro.
static func draw_frame(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint: Color = Color.WHITE, skin_id: String = SKIN_WOOD) -> void:
	if skin_id == SKIN_DESERT:
		_draw_desert_frame(canvas, board_offset, rows, cols, cell_size, tint)
		return
	_ensure_loaded(skin_id)
	var d = _skins[skin_id]
	if d == null:
		return
	var _texture: Texture2D = d["tex"]
	var _tex_size: Vector2 = d["size"]
	var m: float = d["margin"]
	var frame_px = cell_size * (m / d["tile_px"])

	var board_size = Vector2(cols * cell_size, rows * cell_size)
	var outer_pos = board_offset - Vector2(frame_px, frame_px)
	var outer_size = board_size + Vector2(frame_px * 2.0, frame_px * 2.0)

	var w = _tex_size.x
	var h = _tex_size.y

	var src_tl = Rect2(0.0, 0.0, m, m)
	var src_tr = Rect2(w - m, 0.0, m, m)
	var src_bl = Rect2(0.0, h - m, m, m)
	var src_br = Rect2(w - m, h - m, m, m)
	var src_top = Rect2(m, 0.0, w - 2.0 * m, m)
	var src_bottom = Rect2(m, h - m, w - 2.0 * m, m)
	var src_left = Rect2(0.0, m, m, h - 2.0 * m)
	var src_right = Rect2(w - m, m, m, h - 2.0 * m)

	# Cantos (tamanho fixo, sem esticar).
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos, Vector2(frame_px, frame_px)), src_tl, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(outer_size.x - frame_px, 0.0), Vector2(frame_px, frame_px)), src_tr, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(0.0, outer_size.y - frame_px), Vector2(frame_px, frame_px)), src_bl, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + outer_size - Vector2(frame_px, frame_px), Vector2(frame_px, frame_px)), src_br, tint)

	# Bordas.
	if d["segmented"]:
		_draw_segmented_edges(canvas, d, outer_pos, outer_size, rows, cols, cell_size, frame_px, tint)
		return
	# Bordas (esticam no eixo que acompanha o tamanho do tabuleiro).
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(frame_px, 0.0), Vector2(outer_size.x - 2.0 * frame_px, frame_px)), src_top, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(frame_px, outer_size.y - frame_px), Vector2(outer_size.x - 2.0 * frame_px, frame_px)), src_bottom, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(0.0, frame_px), Vector2(frame_px, outer_size.y - 2.0 * frame_px)), src_left, tint)
	canvas.draw_texture_rect_region(_texture, Rect2(outer_pos + Vector2(outer_size.x - frame_px, frame_px), Vector2(frame_px, outer_size.y - 2.0 * frame_px)), src_right, tint)


# Bordas da moldura segmentada: um pedaço por casinha (ver _edge_segment).
static func _draw_segmented_edges(canvas: CanvasItem, d: Dictionary, outer_pos: Vector2, outer_size: Vector2, rows: int, cols: int, cell_size: float, frame_px: float, tint: Color) -> void:
	var tex: Texture2D = d["tex"]
	var m: float = d["margin"]
	var tp: float = d["tile_px"]
	var w = d["size"].x
	var h = d["size"].y
	for edge in range(4):
		var count = cols if edge < 2 else rows
		var prev := [-1, -100, -1]
		for i in range(count):
			var k = _edge_segment(d, edge, i, count, prev)
			var along = m + float(k) * tp
			var dst: Rect2
			var src: Rect2
			match edge:
				0:
					dst = Rect2(outer_pos + Vector2(frame_px + i * cell_size, 0.0), Vector2(cell_size, frame_px))
					src = Rect2(along, 0.0, tp, m)
				1:
					dst = Rect2(outer_pos + Vector2(frame_px + i * cell_size, outer_size.y - frame_px), Vector2(cell_size, frame_px))
					src = Rect2(along, h - m, tp, m)
				2:
					dst = Rect2(outer_pos + Vector2(0.0, frame_px + i * cell_size), Vector2(frame_px, cell_size))
					src = Rect2(0.0, along, m, tp)
				_:
					dst = Rect2(outer_pos + Vector2(outer_size.x - frame_px, frame_px + i * cell_size), Vector2(frame_px, cell_size))
					src = Rect2(w - m, along, m, tp)
			canvas.draw_texture_rect_region(tex, dst, src, tint)


# ---------------------------------------------------------------------------
# Deserto: casas e borda do mapa do deserto
# ---------------------------------------------------------------------------

# Casas: sorteio determinístico por posição (não pisca entre redraws), sem
# repetir a mesma arte na casa de cima nem na da esquerda da mesma cor.
static func _desert_pick(r: int, c: int, is_light: bool, count: int) -> int:
	var i: int = _variant_index(r + 3, c + 17, count)
	var k := 0
	while k < count:
		var clash := false
		for d in [Vector2i(-2, 0), Vector2i(0, -2)]:
			var rr: int = r + d.y
			var cc: int = c + d.x
			if rr >= 0 and cc >= 0 and _variant_index(rr + 3, cc + 17, count) == i:
				clash = true
		if not clash:
			break
		i = (i + 1) % count
		k += 1
	return i

static func _draw_desert_tiles(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint_light: Color, tint_dark: Color) -> void:
	_ensure_desert()
	if not _desert["ok"]:
		return
	for r in range(rows):
		for c in range(cols):
			var is_light: bool = (r + c) % 2 == 0
			var pool: Array = _desert["light" if is_light else "dark"]
			var tex: Texture2D = pool[_desert_pick(r, c, is_light, pool.size())]
			var rect := Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
			canvas.draw_texture_rect(tex, rect, false, tint_light if is_light else tint_dark)

# Mesma montagem de ForestBackground._draw_frame_sheet: 8 px (lados) e 10 px
# (topo/base) nativos ficam FORA do tabuleiro; o resto da peça entra sobre as casas.
static func _draw_desert_frame(canvas: CanvasItem, board_offset: Vector2, rows: int, cols: int, cell_size: float, tint: Color) -> void:
	_ensure_desert()
	if not _desert["ok"]:
		return
	var tex: Texture2D = _desert["frame"]
	var S: float = cell_size / _D_TILE
	var W: float = tex.get_width()
	var H: float = tex.get_height()
	var board_size := Vector2(cols * cell_size, rows * cell_size)
	var outer := Rect2(board_offset - Vector2(_D_MARGIN_X, _D_MARGIN_Y) * S, board_size + Vector2(_D_MARGIN_X, _D_MARGIN_Y) * S * 2.0)
	for i in range(cols):
		var sx: float = _D_MARGIN_X + _D_TILE * float(i % _D_COLS)
		var dx: float = board_offset.x + float(i) * cell_size
		canvas.draw_texture_rect_region(tex, Rect2(dx, outer.position.y, cell_size, _D_TOP_H * S), Rect2(sx, 0, _D_TILE, _D_TOP_H), tint)
		canvas.draw_texture_rect_region(tex, Rect2(dx, outer.end.y - _D_BOT_H * S, cell_size, _D_BOT_H * S), Rect2(sx, H - _D_BOT_H, _D_TILE, _D_BOT_H), tint)
	for j in range(rows):
		var sy: float = _D_MARGIN_Y + _D_TILE * float(j % _D_ROWS)
		var dy: float = board_offset.y + float(j) * cell_size
		canvas.draw_texture_rect_region(tex, Rect2(outer.position.x, dy, _D_SIDE_W * S, cell_size), Rect2(0, sy, _D_SIDE_W, _D_TILE), tint)
		canvas.draw_texture_rect_region(tex, Rect2(outer.end.x - _D_SIDE_W * S, dy, _D_SIDE_W * S, cell_size), Rect2(W - _D_SIDE_W, sy, _D_SIDE_W, _D_TILE), tint)
	var top_sz := Vector2(_D_SIDE_W, _D_TOP_H) * S
	var bot_sz := Vector2(_D_SIDE_W, _D_BOT_H) * S
	canvas.draw_texture_rect_region(tex, Rect2(outer.position, top_sz), Rect2(0, 0, _D_SIDE_W, _D_TOP_H), tint)
	canvas.draw_texture_rect_region(tex, Rect2(Vector2(outer.end.x - top_sz.x, outer.position.y), top_sz), Rect2(W - _D_SIDE_W, 0, _D_SIDE_W, _D_TOP_H), tint)
	canvas.draw_texture_rect_region(tex, Rect2(Vector2(outer.position.x, outer.end.y - bot_sz.y), bot_sz), Rect2(0, H - _D_BOT_H, _D_SIDE_W, _D_BOT_H), tint)
	canvas.draw_texture_rect_region(tex, Rect2(outer.end - bot_sz, bot_sz), Rect2(W - _D_SIDE_W, H - _D_BOT_H, _D_SIDE_W, _D_BOT_H), tint)
