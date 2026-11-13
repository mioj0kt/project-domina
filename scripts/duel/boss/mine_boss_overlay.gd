class_name MineBossOverlay
extends Node2D

# Camada de animações do chefe da Mina, por cima do tabuleiro:
#  - Garimpo: contador de pepitas de cada lado (3 pepitas ao lado do encaixe do
#    indicador de vez) e o "1/3, 2/3, 3/3" que sobe da pepita coletada e voa
#    para o contador.
#  - Trilhos: a vagoneta levando a peça de uma ponta à outra.
#  - Desabamento: as rochas caindo do teto.

const U: float = 3.0
const C_OUT := Color8(31, 22, 29)
const C_PLATE := Color8(46, 34, 44)
const C_DIM := Color8(90, 72, 85)
const C_TEXT := Color8(239, 230, 207)

var host
var shown_counts: Dictionary = {}     # time -> pepitas mostradas no contador
var _flash: Dictionary = {}           # time -> ms em que o contador acendeu
var _pops: Array = []                 # textos subindo: {pos, text, color, t0, dur}
var _fly: Array = []                  # pepitas voando: {from, to, t0, dur}
var _ride: Dictionary = {}            # {cells, piece, t0, dur}
var _falls: Array = []                # rochas caindo: {pos, t0, dur, victim}

func setup(p_host) -> void:
	host = p_host
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 40

func _process(_delta: float) -> void:
	queue_redraw()

func _font() -> Font:
	var th: Theme = ThemeDB.get_project_theme()
	if th != null and th.default_font != null:
		return th.default_font
	return ThemeDB.fallback_font

func _cell_center(p: Vector2i) -> Vector2:
	return host.board_offset + Vector2(p.x * host.cell_size + host.cell_size / 2.0, p.y * host.cell_size + host.cell_size / 2.0)

func _is_nuggets() -> bool:
	return host != null and host.current_duel is DuelBossMine and host.current_duel.law_id == DuelBossMine.LAW_NUGGETS

# Onde fica o contador de cada lado: logo abaixo do encaixe do adversário e logo
# acima do seu, na coluna do indicador de vez.
func counter_anchor(team: int, idx: int) -> Vector2:
	var cs: float = host.cell_size
	var x: float = host.board_offset.x + float(host.board.cols) * cs + 81.0
	var gap: float = 13.0 * U
	if team == host.human_team:
		var y_bot: float = host.board_offset.y + float(host.board.rows) * cs - cs * 0.5
		return Vector2(x, y_bot - 42.0 - gap - float(idx) * gap)
	var y_top: float = host.board_offset.y + cs * 0.5
	return Vector2(x, y_top + 42.0 + gap + float(idx) * gap)

# ---------------------------------------------------------------------------
# Animações (o controlador espera cada uma terminar)
# ---------------------------------------------------------------------------
func play_nugget(ev: Dictionary) -> void:
	var team: int = int(ev["team"])
	var count: int = int(ev["count"])
	var pos: Vector2i = ev["pos"]
	var mine: bool = team == host.human_team
	var col: Color = Color8(240, 210, 122) if mine else Color8(214, 120, 120)
	var c: Vector2 = _cell_center(pos)
	Sfx.play("moeda")
	_pops.append({"pos": c + Vector2(0, -host.cell_size * 0.35), "text": "%d/3" % count, "color": col,
		"t0": Time.get_ticks_msec(), "dur": 1.3, "big": count >= 3})
	var slot: int = clampi(count - 1, 0, 2)
	_fly.append({"from": c, "to": counter_anchor(team, slot), "t0": Time.get_ticks_msec() + 250, "dur": 0.45})
	await get_tree().create_timer(0.72).timeout
	shown_counts[team] = count
	_flash[team] = Time.get_ticks_msec()
	if count >= 3:
		Sfx.play("lei")
		await get_tree().create_timer(0.35).timeout
		host.rule_banner_view.pop_rule_trigger(c, "3/3 — DAMA!" if mine else "3/3 — DAMA DO CHEFE!", col, "nuggets")
		await get_tree().create_timer(0.25).timeout
		shown_counts[team] = 0
		_flash[team] = Time.get_ticks_msec()
	else:
		host.board.rule_fired.emit("nuggets")

func play_rail_ride(ev: Dictionary) -> void:
	var cells: Array = ev["cells"]
	var dest: Vector2i = ev["to"]
	host.piece_spawn_scales[dest] = 0.0
	var dur: float = 0.16 * float(maxi(1, cells.size() - 1)) + 0.15
	_ride = {"cells": cells, "piece": ev["piece"], "t0": Time.get_ticks_msec(), "dur": dur}
	Sfx.play("salto")
	host.rule_banner_view.pop_rule_trigger(_cell_center(ev["from"]), "VAGONETA!", Color(0.95, 0.8, 0.45), "rails")
	await get_tree().create_timer(dur).timeout
	_ride = {}
	host.piece_spawn_scales[dest] = 1.0
	var tw := create_tween()
	tw.tween_method(func(v): host.piece_spawn_scales[dest] = v, 1.25, 1.0, 0.18)
	await tw.finished
	host.piece_spawn_scales.erase(dest)

# Rochas caindo: as peças atingidas continuam visíveis até a pedra chegar,
# depois quebram (piece_destroyed) e a rocha aparece na casa.
func play_cave_in(rocks: Array, killed: Array) -> void:
	var now: int = Time.get_ticks_msec()
	var tiles: Array = rocks.duplicate()
	for k in killed:
		if not tiles.has(k[0]):
			tiles.append(k[0])
	for p in rocks:
		host.piece_spawn_scales[p] = 0.0
	var i: int = 0
	for p in tiles:
		var victim = null
		for k in killed:
			if k[0] == p:
				victim = k[1]
		_falls.append({"pos": p, "t0": now + i * 90, "dur": 0.38, "victim": victim})
		i += 1
	await get_tree().create_timer(0.38 + 0.09 * float(maxi(0, tiles.size() - 1))).timeout
	Sfx.play("bloqueio")
	for f in _falls:
		if f["victim"] != null:
			host.board.piece_destroyed.emit(f["pos"], f["victim"])
	_falls.clear()
	for p in rocks:
		host.piece_spawn_scales.erase(p)

# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------
func _draw() -> void:
	if host == null or host.board == null:
		return
	var now: int = Time.get_ticks_msec()
	var cs: float = host.cell_size
	var u: float = MineBossFx.unit(cs)
	# rochas caindo (com a vítima ainda no lugar)
	for f in _falls:
		var c: Vector2 = _cell_center(f["pos"])
		if f["victim"] != null:
			PixelRenderer.draw_piece(self, f["victim"], c, cs, 1.0)
		var k: float = clampf((now - int(f["t0"])) / 1000.0 / float(f["dur"]), 0.0, 1.0)
		if k <= 0.0:
			continue
		var y: float = lerpf(-cs * 3.0, 0.0, k * k)
		var tmp := BoardPiece.make_rock()
		MineBossFx.draw_rock(self, tmp, c + Vector2(0, y), cs, 1.0)
		# sombra crescendo
		draw_rect(Rect2(Vector2(c.x - cs * 0.3 * k, c.y + cs * 0.28).round(), Vector2(cs * 0.6 * k, u)), Color(0, 0, 0, 0.35))
	# vagoneta andando pelo trilho com a peça dentro
	if not _ride.is_empty():
		var cells: Array = _ride["cells"]
		var k2: float = clampf((now - int(_ride["t0"])) / 1000.0 / float(_ride["dur"]), 0.0, 1.0)
		var e: float = k2 * k2 * (3.0 - 2.0 * k2)
		var fpos: float = e * float(cells.size() - 1)
		var i0: int = mini(int(fpos), cells.size() - 2) if cells.size() > 1 else 0
		var a: Vector2 = _cell_center(cells[i0])
		var b: Vector2 = _cell_center(cells[mini(i0 + 1, cells.size() - 1)])
		var p: Vector2 = a.lerp(b, fpos - float(i0)).round()
		PixelRenderer.draw_piece(self, _ride["piece"], p + Vector2(0, -cs * 0.08), cs, 0.9)
		var cart: Texture2D = MineBossFx.tex(MineBossFx.CART)
		if cart != null:
			var ck: float = maxf(1.0, floorf(cs / 36.0))
			var csz: Vector2 = cart.get_size() * ck
			draw_texture_rect(cart, Rect2(Vector2(p.x - csz.x / 2.0, p.y + cs * 0.46 - csz.y).round(), csz), false)
		# faíscas nas rodas
		for j in range(2):
			var sp := Vector2(p.x + (j * 2 - 1) * cs * 0.2 + randf_range(-u, u), p.y + cs * 0.42).round()
			draw_rect(Rect2(sp, Vector2(u, u)), Color(1.0, 0.85, 0.4, 0.9))
	# pepitas voando para o contador
	var keep_fly: Array = []
	for fl in _fly:
		var k3: float = (now - int(fl["t0"])) / 1000.0 / float(fl["dur"])
		if k3 > 1.0:
			continue
		keep_fly.append(fl)
		if k3 < 0.0:
			continue
		var pos: Vector2 = (fl["from"] as Vector2).lerp(fl["to"], k3 * k3) + Vector2(0, -sin(k3 * PI) * cs * 0.6)
		MineBossFx.draw_nugget_icon(self, pos, u)
	_fly = keep_fly
	if _is_nuggets():
		_draw_counters(now)
	# textos "1/3" subindo
	var keep: Array = []
	var font: Font = _font()
	for pp in _pops:
		var k4: float = (now - int(pp["t0"])) / 1000.0 / float(pp["dur"])
		if k4 > 1.0:
			continue
		keep.append(pp)
		var fs: int = int((64 if pp["big"] else 54) * (1.0 + 0.35 * maxf(0.0, 1.0 - k4 * 6.0)))
		var pos2: Vector2 = pp["pos"] + Vector2(0, -k4 * cs * 0.5)
		var alpha: float = clampf((1.0 - k4) * 3.0, 0.0, 1.0)
		var txt: String = pp["text"]
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var iu: float = 4.0
		var total: float = w + iu * 11.0
		var base := Vector2(pos2.x - total / 2.0 + iu * 11.0, pos2.y).round()
		# pepita ao lado do número, para ficar claro o que está sendo contado
		MineBossFx.draw_nugget_icon(self, Vector2(pos2.x - total / 2.0 + iu * 4.5, pos2.y - fs * 0.32), iu, alpha)
		draw_string_outline(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(C_OUT, alpha))
		draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(pp["color"], alpha))
	_pops = keep

# Três encaixes de pepita por lado, com o "n/3" embaixo. A pepita acende quando
# chega; com 3 o contador pisca e zera (a Dama já foi dada).
func _draw_counters(now: int) -> void:
	var font: Font = _font()
	var enemy_team: int = Board.BLACK if host.human_team == Board.WHITE else Board.WHITE
	for team in [host.human_team, enemy_team]:
		var n: int = int(shown_counts.get(team, host.board.nugget_counts.get(team, 0)))
		var fl: float = clampf(1.0 - (now - int(_flash.get(team, -10000))) / 600.0, 0.0, 1.0)
		for i in range(3):
			var c: Vector2 = counter_anchor(team, i)
			var box := Rect2(Vector2(c.x - 18.0, c.y - 16.0).round(), Vector2(36, 32))
			draw_rect(box.grow(3), C_OUT)
			draw_rect(box, C_PLATE)
			if i < n:
				draw_rect(box, Color(0.95, 0.8, 0.4, 0.18 + 0.5 * fl))
			MineBossFx.draw_nugget_icon(self, c, 3.0, 1.0, i >= n)
		var last: Vector2 = counter_anchor(team, 2)
		var lab: String = "%d/3" % n
		var fs: int = 20
		var w: float = font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ly: float = last.y + (40.0 if team != host.human_team else -26.0)
		var tc: Color = C_TEXT.lerp(Color8(240, 210, 122), fl)
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(font, Vector2(last.x - w / 2.0, ly) + d, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_OUT)
		draw_string(font, Vector2(last.x - w / 2.0, ly), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
