class_name BiomeCrossing
extends Node2D

# Travessia entre biomas. Depois de derrotar o chefe (e escolher a Lei), o jogo
# volta para o mapa do bioma que acabou; a peça sai do nodo do chefe e anda PARA
# ALÉM do tabuleiro. Blocos de tabuleiro (1x1, 2x2, 2x4, 4x2...) sobem do vazio
# já encaixados na grade do mapa e formam o caminho (primeiro com as casas do
# bioma velho, depois com as do novo) até a quina do tabuleiro do próximo
# bioma: um mapa de verdade dele (casas, enfeites, moldura e base de ilha), bem
# maior que a tela. Aí o RunManager avança de bioma e o
# mapa novo abre. Clique ou tecla pula a cena.

const PX: float = 3.0
const ZIG_STEPS: int = 4          # saltos em ziguezague logo depois do tabuleiro
const RUN_STEPS: int = 6          # saltos em diagonal reta até o tabuleiro novo
const DEST_COLS: int = 18         # tabuleiro novo: bem maior que a tela (some pelas bordas)
const DEST_ROWS: int = 16
const DEST_HOPS: int = 2          # saltos já em cima do tabuleiro novo
const SHAPES: Array = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 2), Vector2i(2, 4), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 3)]
const ROCK := {
	"floresta": ["6b4a35", "4f3628", "33222b"],
	"deserto": ["d9b77a", "b98a52", "6b4a5a"],
	"mina": ["5a4855", "3a2d37", "231a22"],
	"cume": ["5a4855", "3a2d37", "231a22"],
	"caldeira": ["4a3a46", "31252f", "1f161d"],
}

var TILE: float = 78.0
var _mv: Node = null
var _done: bool = false
var _armed: bool = false          # só aceita "pular" depois de um instante
var _cam_target := Vector2.ZERO
var _follow: bool = false
var _t: float = 0.0
var _blocks: Array = []
var _used: Dictionary = {}        # casas (grade do mapa) já ocupadas por um bloco
var _board_cells := Rect2i()

# Bloco de tabuleiro: casas na grade do mapa + o toco de rocha embaixo de cada
# coluna. `origin` = casa de cima à esquerda (grade); a posição do nó fica no
# centro dessa casa, então tudo encaixa com o tabuleiro do mapa.
class Block extends Node2D:
	var size := Vector2i.ONE
	var origin := Vector2i.ZERO
	var texs: Array = []          # [linha][coluna] -> Texture2D
	var rock: Array = []
	var ice: bool = false
	var tile: float = 78.0
	var base_y: float = 0.0
	var rise: float = 0.0
	var dip: float = 0.0
	var phase: float = 0.0
	var floating: bool = false    # bloco solto (não é caminho): balança devagar
	var depth: Array = []         # por coluna: quantos px nativos de rocha cabem embaixo

	func _draw() -> void:
		var u: float = BiomeCrossing.PX
		var half: float = tile / 2.0
		var tl := Vector2(-half, -half)
		var w: float = size.x * tile
		var h: float = size.y * tile
		var cols_px: int = int(w / u)
		var sd: int = absi(hash(origin))
		# toco de rocha: mais fundo no meio, irregular, com estalactites
		for cx in range(cols_px):
			var d: float = 1.0 - absf(float(cx) - cols_px * 0.5 + 0.5) / (cols_px * 0.5)
			var hh: int = int(round(4.0 + (10.0 + 6.0 * size.x) * pow(maxf(d, 0.0), 0.7))) + absi(hash(Vector2i(cx, sd))) % 4
			if absi(hash(Vector2i(int(cx / 3.0), sd + 7))) % 5 == 0:
				hh += 4
			# não invade bloco/tabuleiro logo abaixo
			var col_i: int = clampi(int(cx * u / tile), 0, size.x - 1)
			if not depth.is_empty():
				hh = mini(hh, int(depth[col_i]))
			if hh <= 0:
				continue
			for ry in range(hh):
				var f: float = float(ry) / float(hh)
				var col := Color(rock[0] if f < 0.3 else (rock[1] if f < 0.7 else rock[2]))
				if cx > cols_px * 0.6:
					col = col.darkened(0.18)
				draw_rect(Rect2(tl + Vector2(cx * u, h + ry * u), Vector2(u, u)), col)
			if ice and absi(hash(Vector2i(cx, sd + 3))) % 6 == 0:
				draw_rect(Rect2(tl + Vector2(cx * u, h + hh * u), Vector2(u, u * 3.0)), Color("a9dcef"))
		# casas
		for r in range(size.y):
			for c in range(size.x):
				var tx: Texture2D = texs[r][c]
				if tx != null:
					draw_texture_rect(tx, Rect2(tl + Vector2(c * tile, r * tile), Vector2(tile, tile)), false)
		# contorno do bloco
		draw_rect(Rect2(tl, Vector2(w, h)).grow(u * 0.5), Color("1f161d"), false, u)
		draw_rect(Rect2(tl + Vector2(0, -u), Vector2(w, u)), Color(1, 1, 1, 0.18))

static func next_biome() -> String:
	var i: int = RunManager.BIOME_ORDER.find(RunManager.map_biome)
	if i < 0 or i >= RunManager.BIOME_ORDER.size() - 1:
		return ""
	return RunManager.BIOME_ORDER[i + 1]

static func _tile_tex(biome: String, cell: Vector2i) -> Texture2D:
	var th: Dictionary = ForestBackground.THEMES.get(biome, ForestBackground.THEMES["floresta"])
	var light: bool = ((cell.x + cell.y) % 2 + 2) % 2 == 0
	var pool: Array = th["tiles_light"] if light else th["tiles_dark"]
	# só casas "lisas" (as 4 primeiras do conjunto): as variações com gelo/enfeite ficam pro mapa
	var n: int = mini(pool.size(), 8)
	return ForestBackground._tex(ForestBackground.BOARD_DIR + String(pool[absi(hash(cell)) % n]), th["dir"])

func run(mv: Node) -> void:
	_mv = mv
	TILE = mv.TILE_SIZE
	z_index = 6          # acima do tabuleiro, abaixo da peça (z 10)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mv.is_traveling = true
	var from_b: String = RunManager.map_biome
	var to_b: String = next_biome()
	var pawn = mv.player_pawn
	if to_b == "" or pawn == null or mv.forest == null or mv.camera == null:
		_finish()
		return
	if mv._cam_tween != null and mv._cam_tween.is_valid():
		mv._cam_tween.kill()
	pawn.visible = true
	# cena limpa: sem HUD nem dica de rolagem
	if mv.hud_bar != null:
		mv.hud_bar.visible = false
	for ch in mv.get_children():
		if ch is MapScrollHint:
			ch.visible = false
	var g: Vector2i = pawn.current_grid_pos
	var board_rect: Rect2 = mv.forest._board_rect
	var top_row: int = int(round((board_rect.position.y + TILE * 0.5) / TILE))   # 1ª fileira de casas do mapa
	var side: int = 1 if g.x <= 0 else -1          # o tabuleiro novo fica deste lado

	# caminho: sobe em ziguezague até sair do tabuleiro, mais ZIG_STEPS no céu
	# (derivando para o lado oposto) e RUN_STEPS em diagonal reta até a beirada nova
	var path: Array[Vector2i] = []
	var cur: Vector2i = g
	var zig: int = -side
	var guard: int = 0
	while cur.y > top_row and guard < 40:
		cur += Vector2i(zig, -1)
		zig = -zig
		path.append(cur)
		guard += 1
	var sky_from: int = path.size()
	for i in range(ZIG_STEPS):
		cur += Vector2i(-side if i % 3 != 2 else side, -1)
		path.append(cur)
	for i in range(RUN_STEPS):
		cur += Vector2i(side, -1)
		path.append(cur)
	var sky_end: int = path.size()
	# tabuleiro novo: a próxima casa da diagonal é o canto de baixo dele
	var entry: Vector2i = cur + Vector2i(side, -1)
	var dest_left: int = entry.x if side > 0 else entry.x - (DEST_COLS - 1)
	var dest_origin := Vector2i(dest_left, entry.y - (DEST_ROWS - 1))
	for i in range(DEST_HOPS + 1):
		cur += Vector2i(side, -1)
		path.append(cur)
	# o tabuleiro novo e a moldura dele (uma casa em volta) ficam reservados
	for r in range(-1, DEST_ROWS + 1):
		for c in range(-1, DEST_COLS + 1):
			var rc: Vector2i = dest_origin + Vector2i(c, r)
			if rc == entry + Vector2i(-side, 1):
				continue   # a quina por onde o caminho entra
			_used[rc] = true
	var board_cells := Rect2i(int(round(board_rect.position.x / TILE)), top_row, int(round(board_rect.size.x / TILE)), 999)
	# a base de ilha do tabuleiro novo pendura uns 5 casas embaixo dele: reservado
	for r in range(DEST_ROWS + 1, DEST_ROWS + 6):
		for c in range(DEST_COLS):
			_used[dest_origin + Vector2i(c, r)] = true
	_board_cells = board_cells

	# blocos do caminho, na ordem em que a peça passa
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from_b + to_b) + g.x * 31
	var plan: Array = []           # [Block, índice do caminho em que ele precisa estar de pé]
	var i0: int = sky_from
	while i0 < sky_end:
		if _used.has(path[i0]):
			i0 += 1
			continue
		var cells: Array = _place_block(path, i0, sky_end, rng, board_cells)
		var biome: String = from_b if i0 < sky_from + int((sky_end - sky_from) / 2.0) else to_b
		var b: Block = _make_block(cells, biome, false)
		plan.append([b, i0])
		i0 += 1
	# blocos soltos em volta do caminho (de enfeite)
	var deco: Array = []
	for k in range(7):
		var anchor: Vector2i = path[rng.randi_range(sky_from, sky_end - 1)]
		var shape: Vector2i = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2)][rng.randi() % 4]
		var o := anchor + Vector2i(rng.randi_range(3, 6) * (1 if rng.randf() < 0.5 else -1), rng.randi_range(-2, 2))
		var cells2: Array = []
		var ok := true
		for yy in range(shape.y):
			for xx in range(shape.x):
				var c2: Vector2i = o + Vector2i(xx, yy)
				if _near_used(c2) or board_cells.has_point(c2) or c2.y >= top_row - 1:
					ok = false
				cells2.append(c2)
		if not ok:
			continue
		for c2 in cells2:
			_used[c2] = true
		var bd: Block = _make_block(cells2, from_b if k % 2 == 0 else to_b, true)
		deco.append([bd, mini(sky_end - 1, path.find(anchor) + 1)])

	# rocha embaixo de cada bloco: só até o próximo bloco/tabuleiro
	var solid: Dictionary = {}
	for e in plan:
		for yy in range(e[0].size.y):
			for xx in range(e[0].size.x):
				solid[e[0].origin + Vector2i(xx, yy)] = true
	for r in range(-1, DEST_ROWS + 6):
		for c in range(-1, DEST_COLS + 1):
			solid[dest_origin + Vector2i(c, r)] = true
	for e in plan + deco:
		var b0: Block = e[0]
		b0.depth = []
		for xx in range(b0.size.x):
			var free: int = 0
			for k in range(1, 3):
				var below: Vector2i = b0.origin + Vector2i(xx, b0.size.y - 1 + k)
				if solid.has(below) or board_cells.has_point(below) or board_cells.has_point(below + Vector2i(0, 1)):
					break
				free += 1
			b0.depth.append(int(float(free) * TILE * 0.85 / PX))

	# beirada do tabuleiro novo + base de ilha dele (escondidas até a hora)
	# O tabuleiro do próximo bioma é um mapa de verdade (ForestBackground do bioma,
	# com casas, enfeites e moldura) bem maior que a tela, e a base de ilha dele.
	var dest := Node2D.new()
	dest.modulate.a = 0.0
	dest.position = Vector2(0, 300.0)
	add_child(dest)
	move_child(dest, 0)   # atrás dos blocos do caminho
	var landing := MapNode.new()
	landing.position = Vector2(path[path.size() - 1]) * TILE
	var walk := MapNode.new()
	walk.position = Vector2(entry) * TILE
	walk.children.append(landing)
	var fb := ForestBackground.new()
	fb.biome = to_b
	fb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dest.add_child(fb)
	fb.build([[walk], [landing]], TILE, int(PX), dest_origin.x, dest_origin.x + DEST_COLS - 1, dest_origin.y, dest_origin.y + DEST_ROWS - 1)
	var base := IslandBase.new()
	base.biome = to_b
	if to_b == "cume":
		base.top_overlap_px = 6.0 * TILE / 26.0
	dest.add_child(base)
	dest.move_child(base, 0)
	base.build(fb.world_rect, int(PX), null)
	var dest_pos := Vector2.ZERO
	# a câmera fica na quina de entrada, com o tabuleiro tomando a tela para o lado e para cima
	var corner_view: Vector2 = Vector2(entry) * TILE + Vector2(float(side) * TILE * 4.5, -TILE * 2.5)

	_cam_target = Vector2(mv.camera.position.x, mv._cam_y)
	_follow = true
	await get_tree().create_timer(0.7).timeout
	_armed = true
	if _done:
		return

	var dest_shown := false
	var pi: int = 0
	for i in range(path.size()):
		# blocos que precisam estar de pé até a casa i+1
		while pi < plan.size() and plan[pi][1] <= i + 1:
			_raise(plan[pi][0])
			for dd in deco:
				if dd[1] == plan[pi][1] and not dd[0].is_inside_tree():
					_raise(dd[0])
			pi += 1
			await get_tree().create_timer(0.12).timeout
			if _done:
				return
		# o tabuleiro novo sobe quando faltam poucas casas
		if not dest_shown and i >= sky_end - 6:
			dest_shown = true
			var tw := create_tween().set_parallel(true)
			tw.tween_property(dest, "modulate:a", 1.0, 0.6)
			tw.tween_property(dest, "position", dest_pos, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			Sfx.play("brotar")
		var target: Vector2 = Vector2(path[i]) * TILE
		_cam_target = target + Vector2(float(side) * 60.0, -170.0)
		if i >= sky_end - 3:
			_cam_target = corner_view
		await pawn._do_single_diagonal_hop(target, false)
		pawn.current_grid_pos = path[i]
		if _done:
			return
		_dip_block_at(path[i], target)
	# chegou: a peça assenta no tabuleiro novo
	Sfx.play("coroar")
	Juice.ring(self, pawn.position, TILE * 0.9, Color(1, 0.95, 0.75), 5.0, 0.5)
	Juice.burst(self, pawn.position, Color(1, 0.95, 0.75), 16, 260.0, 0.6, 5.0, 200.0, 90.0)
	await get_tree().create_timer(1.0).timeout
	_finish()

# Casa livre e sem bloco encostado (blocos soltos não grudam no caminho).
func _near_used(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _used.has(c + Vector2i(dx, dy)):
				return true
	return false

# Escolhe a forma e a posição do bloco que cobre path[i0] (e o máximo das casas
# seguintes do caminho), sem encostar no tabuleiro velho nem em outro bloco.
func _place_block(path: Array, i0: int, i_end: int, rng: RandomNumberGenerator, board_cells: Rect2i) -> Array:
	var shapes: Array = SHAPES.duplicate()
	shapes.shuffle()
	if rng.randf() < 0.25:
		shapes.push_front(Vector2i(1, 1))   # de vez em quando uma casa sozinha
	var p: Vector2i = path[i0]
	for shape in shapes:
		var best: Array = []
		var best_cover: int = -1
		for oy in range(shape.y):
			for ox in range(shape.x):
				var o: Vector2i = p - Vector2i(ox, oy)
				var cells: Array = []
				var ok := true
				for yy in range(shape.y):
					for xx in range(shape.x):
						var c: Vector2i = o + Vector2i(xx, yy)
						if _used.has(c) or board_cells.has_point(c) or board_cells.has_point(c + Vector2i(0, 1)):
							ok = false
						cells.append(c)
				if not ok:
					continue
				var cover: int = 0
				for j in range(i0, mini(i_end, i0 + 6)):
					if cells.has(path[j]):
						cover += 1
				if cover > best_cover:
					best_cover = cover
					best = cells
		if not best.is_empty():
			for c in best:
				_used[c] = true
			return best
	_used[p] = true
	return [p]

func _make_block(cells: Array, biome: String, floating: bool) -> Block:
	var mn: Vector2i = cells[0]
	var mx: Vector2i = cells[0]
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var b := Block.new()
	b.origin = mn
	b.size = mx - mn + Vector2i.ONE
	b.tile = TILE
	b.rock = ROCK.get(biome, ROCK["mina"])
	b.ice = biome == "cume"
	b.floating = floating
	b.phase = float(absi(hash(mn)) % 100) * 0.07
	for r in range(b.size.y):
		var row: Array = []
		for c in range(b.size.x):
			row.append(_tile_tex(biome, mn + Vector2i(c, r)))
		b.texs.append(row)
	b.base_y = float(mn.y) * TILE
	b.position = Vector2(float(mn.x) * TILE, b.base_y)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if floating:
		b.modulate = Color(0.78, 0.78, 0.85)
		b.z_index = -2
	return b

# O bloco sobe do vazio e encaixa no lugar.
func _raise(b: Block) -> void:
	if b.is_inside_tree():
		return
	b.rise = 260.0
	b.modulate.a = 0.0
	add_child(b)
	_blocks.append(b)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "modulate:a", 1.0, 0.2)
	tw.tween_property(b, "rise", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not b.floating:
		Sfx.play("mover")

# O bloco afunda um tiquinho quando a peça pisa nele.
func _dip_block_at(cell: Vector2i, pos: Vector2) -> void:
	for b in _blocks:
		if b.floating:
			continue
		if Rect2i(b.origin, b.size).has_point(cell):
			b.dip = 8.0
			Juice.dust(self, pos + Vector2(0, TILE * 0.3), TILE)
			return

func _process(delta: float) -> void:
	_t += delta
	for b in _blocks:
		if b.dip > 0.0:
			b.dip = maxf(0.0, b.dip - delta * 32.0)
		var bob: float = roundf(sin(_t * 1.5 + b.phase) * 1.4) * PX if b.floating else 0.0
		b.position.y = b.base_y + b.rise + roundf(b.dip / PX) * PX + bob
	if _follow and _mv != null and _mv.camera != null and not _done:
		var k: float = 1.0 - pow(0.04, delta)
		_mv.camera.position.x = lerpf(_mv.camera.position.x, _cam_target.x, k)
		_mv._set_cam_y(lerpf(_mv._cam_y, _cam_target.y, k))

func _input(event: InputEvent) -> void:
	if _done or not _armed:
		return
	var skip: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	RunManager.biome_crossing_pending = false
	RunManager.advance_to_next_biome()
	SceneTransition.go(_mv.scene_file_path if _mv != null and _mv.scene_file_path != "" else "res://scenes/map_view.tscn")
