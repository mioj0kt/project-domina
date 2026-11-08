class_name MapPlayerPawn
extends Node2D

signal jump_finished()

var current_grid_pos: Vector2i = Vector2i.ZERO
var current_world_pos: Vector2 = Vector2.ZERO
var jump_scale: float = 1.0
var jump_offset_y: float = 0.0
var dummy_piece: BoardPiece
var tile_size: float = 64.0
# Lado (px de tela) do sprite da peça. O MapView passa 32 px nativos x a escala
# dos nodos, pra a peça preencher o furo do soquete 1:1.
var piece_px: float = 64.0

func _ready() -> void:
	z_index = 30
	dummy_piece = BoardPiece.new(Board.WHITE, true)

func set_initial_position(pos: Vector2, p_tile_size: float = 64.0) -> void:
	tile_size = p_tile_size
	current_world_pos = pos
	current_grid_pos = Vector2i(int(round(pos.x / tile_size)), int(round(pos.y / tile_size)))
	position = pos
	queue_redraw()

# Percorre o caminho casa por casa, obrigatoriamente pulando nas diagonais (±1, ±1)
func jump_to_node(target_pos: Vector2, p_tile_size: float = 64.0) -> void:
	tile_size = p_tile_size
	var target_grid = Vector2i(int(round(target_pos.x / tile_size)), int(round(target_pos.y / tile_size)))
	
	var path: Array[Vector2i] = calculate_diagonal_path(current_grid_pos, target_grid)

	for next_tile in path:
		var target_world = Vector2(next_tile.x * tile_size, next_tile.y * tile_size)
		await _do_single_diagonal_hop(target_world)
		current_grid_pos = next_tile

	current_world_pos = target_pos
	position = target_pos
	jump_finished.emit()

# Gera a sequência de coordenadas intermediárias respeitando a paridade de casas de damas
static func calculate_diagonal_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var curr = start

	while curr != target:
		var dx = target.x - curr.x
		var dy = target.y - curr.y

		# Direção primária no eixo Y (o mapa sobe no sentido negativo de Y)
		var step_y = -1 if dy < 0 else (1 if dy > 0 else 0)
		var step_x = -1 if dx < 0 else (1 if dx > 0 else 0)

		# Se o alinhamento X for 0 mas ainda precisa subir, oscila na diagonal para manter a regra de damas
		if step_x == 0:
			step_x = 1 if (curr.x + curr.y) % 2 == 0 else -1

		# Se o alinhamento Y for 0 mas ainda precisa andar de lado, oscila em Y
		if step_y == 0:
			step_y = -1 if (curr.x + curr.y) % 2 == 0 else 1

		curr += Vector2i(step_x, step_y)
		result.append(curr)

	return result

func _do_single_diagonal_hop(to_world_pos: Vector2) -> void:
	var from_p = current_world_pos
	var tween = create_tween().set_parallel(true)

	# Duração do salto
	var hop_duration = 0.32

	# Movimento linear entre as duas casas diagonais
	tween.tween_method(func(pos: Vector2):
		current_world_pos = pos
		position = pos
		queue_redraw()
	, from_p, to_world_pos, hop_duration).set_trans(Tween.TRANS_LINEAR)

	# Arco vertical do salto com parábola mais suave
	tween.tween_method(func(h: float):
		jump_offset_y = -sin(h * PI) * 26.0
		jump_scale = 1.0 + sin(h * PI) * 0.3
		queue_redraw()
	, 0.0, 1.0, hop_duration)

	await tween.finished
	Sfx.play("salto")
	current_world_pos = to_world_pos
	position = to_world_pos
	jump_offset_y = 0.0
	jump_scale = 1.0
	queue_redraw()
	
	# Pausa/amortecimento ao tocar o chão antes do próximo salto
	await get_tree().create_timer(0.08).timeout

func _draw() -> void:
	var draw_offset = Vector2(0, jump_offset_y)

	# Sombra no chão só enquanto a peça está no ar (parada ela já está
	# encaixada no soquete, sem nada saindo pra fora).
	if jump_offset_y < -0.5:
		var air = clampf(-jump_offset_y / 26.0, 0.0, 1.0)
		draw_circle(Vector2(0, piece_px * 0.12), piece_px * 0.42 * (1.0 - 0.25 * air), Color(0.0, 0.0, 0.0, 0.30))

	if dummy_piece != null:
		# Textura desenhada direto, sem a sombra deslocada do draw_piece, pra
		# a peça preencher o furo do soquete exatamente.
		var tex = PixelRenderer.get_piece_texture(dummy_piece)
		if tex != null:
			var sz = Vector2(piece_px, piece_px) * jump_scale
			draw_texture_rect(tex, Rect2(draw_offset - sz / 2.0, sz), false)
