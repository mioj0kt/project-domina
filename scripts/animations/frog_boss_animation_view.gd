class_name FrogBossAnimationView
extends Node2D

signal attack_sequence_finished()
signal flies_spawn_finished()

const FLY_SPRITE_PATH: String = "res://assets/sprites/fx/fly.png"  # sem o arquivo, desenha a mosca por código

var fly_texture: Texture2D = null
var hazard_tiles: Array = []
var board_offset: Vector2 = Vector2.ZERO
var cell_size: float = 64.0

var active_flies: Dictionary = {}

var is_attacking: bool = false
var is_spawning_flies: bool = false
var tongue_origin: Vector2 = Vector2.ZERO
var tongue_tip: Vector2 = Vector2.ZERO
var devouring_piece: BoardPiece = null

func _ready() -> void:
	z_index = 45
	if FLY_SPRITE_PATH != "" and ResourceLoader.exists(FLY_SPRITE_PATH):
		fly_texture = load(FLY_SPRITE_PATH)

func configure(p_board_offset: Vector2, p_cell_size: float) -> void:
	board_offset = p_board_offset
	cell_size = p_cell_size

# Pulo rápido e leve da mosca caso uma peça se mova na casa dela
func hop_fly_at(tile: Vector2i) -> void:
	if not active_flies.has(tile) or is_spawning_flies:
		return

	var fly_data = active_flies[tile]
	if fly_data.get("is_fleeing", false):
		return

	var base_center = board_offset + Vector2(tile.x * cell_size + cell_size / 2.0, tile.y * cell_size + cell_size / 2.0)
	var peak_pos = base_center - Vector2(0, 20.0)

	var hop_tween = create_tween()
	hop_tween.tween_method(func(progress: float):
		fly_data["pos"] = base_center.lerp(peak_pos, sin(progress * PI))
		fly_data["scale"] = lerpf(1.0, 1.3, sin(progress * PI))
		queue_redraw()
	, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await hop_tween.finished

# Pouso Otimizado com um único Tween mestre
func spawn_new_flies(tiles: Array) -> void:
	hazard_tiles = tiles.duplicate()
	active_flies.clear()

	if hazard_tiles.is_empty():
		queue_redraw()
		flies_spawn_finished.emit()
		return

	is_spawning_flies = true
	var fly_flight_paths: Array[Dictionary] = []

	for i in range(hazard_tiles.size()):
		var tile: Vector2i = hazard_tiles[i]
		var target_center = board_offset + Vector2(tile.x * cell_size + cell_size / 2.0, tile.y * cell_size + cell_size / 2.0)
		var start_pos = Vector2(target_center.x + randf_range(-50.0, 50.0), -60.0)

		var fly_data = {
			"pos": start_pos,
			"scale": 1.7,
			"alpha": 0.0,
			"is_fleeing": false
		}
		active_flies[tile] = fly_data

		fly_flight_paths.append({
			"data": fly_data,
			"start": start_pos,
			"target": target_center,
			"delay": i * 0.12
		})

	var total_duration = 0.55 + (hazard_tiles.size() * 0.12)
	var master_tween = create_tween()

	# Interpolação unificada: apenas 1 chamada de queue_redraw por frame
	master_tween.tween_method(func(elapsed: float):
		for flight in fly_flight_paths:
			var t = clamp((elapsed - flight["delay"]) / 0.45, 0.0, 1.0)
			var fly = flight["data"]
			if t > 0.0:
				var quad_t = ease(t, -2.0) # Efeito EASE_OUT suave
				fly["pos"] = flight["start"].lerp(flight["target"], quad_t)
				fly["scale"] = lerpf(1.7, 1.0, quad_t)
				fly["alpha"] = clamp(t * 3.0, 0.0, 1.0)
		queue_redraw()
	, 0.0, total_duration, total_duration)

	await master_tween.finished
	is_spawning_flies = false
	queue_redraw()
	flies_spawn_finished.emit()

# Isca do Sapo (carta): uma mosca pousa numa casa SEM apagar as outras.
func add_fly(tile: Vector2i) -> void:
	var target_center = board_offset + Vector2(tile.x * cell_size + cell_size / 2.0, tile.y * cell_size + cell_size / 2.0)
	var start_pos = Vector2(target_center.x + randf_range(-50.0, 50.0), -60.0)
	var fly_data = {"pos": start_pos, "scale": 1.7, "alpha": 0.0, "is_fleeing": false}
	active_flies[tile] = fly_data
	var tw = create_tween()
	tw.tween_method(func(t: float):
		var q = ease(t, -2.0)
		fly_data["pos"] = start_pos.lerp(target_center, q)
		fly_data["scale"] = lerpf(1.7, 1.0, q)
		fly_data["alpha"] = clampf(t * 3.0, 0.0, 1.0)
		queue_redraw()
	, 0.0, 1.0, 0.55)
	await tw.finished

# Garante que cada casa da lista tem uma mosca parada (usado depois de um ataque
# ou quando o chefe-sapo troca as moscas dele).
func ensure_static_flies(tiles: Array) -> void:
	for tile in tiles:
		if not active_flies.has(tile):
			active_flies[tile] = {"pos": board_offset + Vector2(tile.x * cell_size + cell_size / 2.0, tile.y * cell_size + cell_size / 2.0),
				"scale": 1.0, "alpha": 1.0, "is_fleeing": false}
	queue_redraw()

# Ataque sequencial da língua
func play_tongue_attack(board: Board, tiles_to_attack: Array) -> void:
	if tiles_to_attack.is_empty():
		attack_sequence_finished.emit()
		return

	is_attacking = true
	board.rule_fired.emit("frog_devourer")
	tongue_origin = Vector2(board_offset.x + (board.cols * cell_size) / 2.0, -160.0)

	for tile_obj in tiles_to_attack:
		var tile: Vector2i = tile_obj
		var target_pos = board_offset + Vector2(tile.x * cell_size + cell_size / 2.0, tile.y * cell_size + cell_size / 2.0)
		var piece_on_tile: BoardPiece = board.grid[tile.y][tile.x]

		tongue_tip = tongue_origin
		devouring_piece = null

		# 1. Língua estica até a casa — mais devagar que antes (era 0.16s),
		# dá tempo de perceber a aproximação antes do "impacto".
		var extend_duration = 0.45
		var extend_tween = create_tween()
		extend_tween.tween_method(func(pos: Vector2):
			tongue_tip = pos
			queue_redraw()
		, tongue_origin, target_pos, extend_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# 2. A mosca percebe e foge ANTES da língua terminar de chegar (no
		# meio do trajeto, não só na chegada) — é isso que dá a sensação de
		# "desviar por pouco" em vez de só desaparecer no impacto.
		if active_flies.has(tile):
			await get_tree().create_timer(extend_duration * 0.55).timeout

			var escaping_fly = active_flies[tile]
			escaping_fly["is_fleeing"] = true
			var escape_dest = Vector2(target_pos.x + randf_range(-40.0, 40.0), -120.0)

			var fly_escape_tween = create_tween().set_parallel(true)
			fly_escape_tween.tween_method(func(pos: Vector2):
				escaping_fly["pos"] = pos
				queue_redraw()
			, target_pos, escape_dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fly_escape_tween.tween_method(func(s: float): escaping_fly["scale"] = s, 1.0, 1.5, 0.3)
			fly_escape_tween.tween_method(func(a: float): escaping_fly["alpha"] = a, 1.0, 0.0, 0.3)
			fly_escape_tween.finished.connect(func(): active_flies.erase(tile))

			await get_tree().create_timer(extend_duration * 0.45).timeout
		else:
			await get_tree().create_timer(extend_duration).timeout

		# 3. Captura a peça se houver (a mosca já fugiu — isso é só sobre a
		# peça de damas que estiver na casa, não a mosca)
		if piece_on_tile != Board.EMPTY:
			# Última Chance: a Dama do jogador pode escapar da língua.
			var escaped: bool = false
			if piece_on_tile.is_king and "human_team" in get_parent():
				escaped = await RuleLastChance.try_save(get_parent(), tile, piece_on_tile)
			if not escaped:
				devouring_piece = piece_on_tile
				board.grid[tile.y][tile.x] = Board.EMPTY
				get_parent().queue_redraw()

		# 4. Língua recolhe
		var retract_tween = create_tween()
		retract_tween.tween_method(func(pos: Vector2):
			tongue_tip = pos
			queue_redraw()
		, target_pos, tongue_origin, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await retract_tween.finished

		devouring_piece = null
		await get_tree().create_timer(0.06).timeout

	active_flies.clear()
	hazard_tiles.clear()
	is_attacking = false
	queue_redraw()
	attack_sequence_finished.emit()

func _draw() -> void:
	# 1. Desenha as Moscas
	for tile in active_flies.keys():
		var fly_data = active_flies[tile]
		_draw_animated_fly(fly_data["pos"], fly_data["scale"], fly_data["alpha"])

	# 2. Desenha a Língua
	if is_attacking:
		draw_line(tongue_origin + Vector2(0, 8), tongue_tip + Vector2(0, 8), Color(0.05, 0.05, 0.08, 0.4), 12.0)
		draw_line(tongue_origin, tongue_tip, Color(0.95, 0.28, 0.46), 9.0)
		draw_line(tongue_origin, tongue_tip, Color(1.0, 0.65, 0.75), 3.0)
		draw_circle(tongue_tip, 9.0, Color(0.85, 0.18, 0.35))

		if devouring_piece != null:
			PixelRenderer.draw_piece(self, devouring_piece, tongue_tip, cell_size, 0.95)

const FLY_FPS: float = 16.0
const FLY_CELL_FRACTION: float = 0.55   # largura da mosca em relação à casa

# Ordem do bater de asas: 0 = asas em cima ... N-1 = asas abertas embaixo; vai e volta.
func _fly_sequence(frames: int) -> Array:
	var seq: Array = []
	for i in range(frames):
		seq.append(i)
	for i in range(frames - 2, 0, -1):
		seq.append(i)
	return seq

func _draw_animated_fly(center: Vector2, scale_mod: float, alpha: float) -> void:
	if alpha <= 0.01:
		return

	if fly_texture != null:
		var tw: float = float(fly_texture.get_width())
		var th: float = float(fly_texture.get_height())
		if tw >= th * 2.0:
			# Tira de quadros quadrados (bater de asas): vai-e-volta, escala inteira
			# de pixel (nada de pixel "quebrado"). Cada mosca tem uma fase própria.
			var frames: int = int(round(tw / th))
			var seq: Array = _fly_sequence(frames)
			var phase: int = int(absf(center.x * 0.37 + center.y * 0.11)) % seq.size()
			var idx: int = int(seq[(int(Time.get_ticks_msec() / 1000.0 * FLY_FPS) + phase) % seq.size()])
			var px: float = maxf(1.0, round(cell_size * FLY_CELL_FRACTION / th)) * scale_mod
			var dest_sz := Vector2(th, th) * px
			var dest_pos := (center - dest_sz / 2.0).round()
			draw_texture_rect_region(fly_texture, Rect2(dest_pos, dest_sz), Rect2(idx * th, 0.0, th, th), Color(1.0, 1.0, 1.0, alpha))
			queue_redraw()   # mantém as asas batendo enquanto houver mosca
		else:
			var base_sz = cell_size * 0.5 * scale_mod
			var dest = Rect2(center - Vector2(base_sz, base_sz) / 2.0, Vector2(base_sz, base_sz))
			draw_texture_rect(fly_texture, dest, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		var body_col = Color(0.12, 0.12, 0.15, alpha)
		var wing_col = Color(0.8, 0.9, 1.0, 0.8 * alpha)
		var eye_col = Color(0.95, 0.15, 0.15, alpha)

		var wing_spread = 6.0 * scale_mod
		draw_circle(center + Vector2(-wing_spread, -4.0 * scale_mod), 4.5 * scale_mod, wing_col)
		draw_circle(center + Vector2(wing_spread, -4.0 * scale_mod), 4.5 * scale_mod, wing_col)

		draw_circle(center, 5.0 * scale_mod, body_col)
		draw_circle(center + Vector2(0, 4.0 * scale_mod), 3.5 * scale_mod, body_col)

		draw_circle(center + Vector2(-2.0 * scale_mod, 4.5 * scale_mod), 1.5 * scale_mod, eye_col)
		draw_circle(center + Vector2(2.0 * scale_mod, 4.5 * scale_mod), 1.5 * scale_mod, eye_col)
