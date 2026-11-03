class_name PieceMovementAnimationView
extends Node2D

signal jump_completed()
signal landed(center: Vector2, is_capture: bool)

var is_animating: bool = false
var current_anim_pos: Vector2 = Vector2.ZERO
var jump_offset_y: float = 0.0
var jump_scale: float = 1.0
var active_piece: BoardPiece = null
var active_cell_size: float = 64.0

func _ready() -> void:
	z_index = 35 # Fica acima das peças normais e abaixo de tooltips/modais

func play_move_jump(from_center: Vector2, to_center: Vector2, piece: BoardPiece, cell_size: float, is_capture: bool) -> void:
	is_animating = true
	active_piece = piece
	active_cell_size = cell_size
	current_anim_pos = from_center

	var tween = create_tween().set_parallel(true)
	var duration = 0.22 if not is_capture else 0.28
	var peak_height = 20.0 if not is_capture else 36.0
	var scale_peak = 1.25 if not is_capture else 1.45

	# 1. Movimento horizontal/vertical linear
	tween.tween_method(func(pos: Vector2):
		current_anim_pos = pos
		queue_redraw()
	, from_center, to_center, duration).set_trans(Tween.TRANS_LINEAR)

	# 2. Arco parabólico de elevação
	tween.tween_method(func(h: float):
		jump_offset_y = -sin(h * PI) * peak_height
		jump_scale = 1.0 + sin(h * PI) * (scale_peak - 1.0)
		queue_redraw()
	, 0.0, 1.0, duration)

	await tween.finished
	landed.emit(to_center, is_capture)

	is_animating = false
	active_piece = null
	jump_offset_y = 0.0
	jump_scale = 1.0
	queue_redraw()
	jump_completed.emit()

func _draw() -> void:
	if not is_animating or active_piece == null:
		return

	# Sombra suave no chão projetada sob a peça
	var shadow_radius = (active_cell_size * 0.32) * (1.0 - (-jump_offset_y / 100.0))
	draw_circle(current_anim_pos + Vector2(2, 4), max(6.0, shadow_radius), Color(0.0, 0.0, 0.0, 0.32))

	# Desenho da peça elevada
	var draw_pos = current_anim_pos + Vector2(0, jump_offset_y)
	PixelRenderer.draw_piece(self, active_piece, draw_pos, active_cell_size, jump_scale)
