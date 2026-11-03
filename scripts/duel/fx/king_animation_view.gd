class_name KingAnimationView
extends Node2D

signal animation_finished()

var is_animating: bool = false
var anim_pos: Vector2 = Vector2.ZERO
var cell_size: float = 64.0
var flip_scale_x: float = 1.0
var toss_scale: float = 1.0

var piece_texture: Texture2D
var active_tween: Tween

func play_coronation(screen_pos: Vector2, p_cell_size: float, piece: BoardPiece) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	anim_pos = screen_pos
	cell_size = p_cell_size
	is_animating = true
	flip_scale_x = 1.0
	toss_scale = 1.0

	# Busca o sprite da peça já com a coroa de Dama
	piece_texture = PixelRenderer.get_piece_texture(piece)

	active_tween = create_tween().set_parallel(true)

	# 1. Elevação / Salto em direção à câmera
	active_tween.tween_property(self, "toss_scale", 1.6, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "toss_scale", 1.0, 0.3).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. Rotação 3D
	var total_flips = 4
	for i in range(total_flips):
		var delay = i * 0.15
		active_tween.tween_method(func(v): flip_scale_x = v; queue_redraw(), 1.0, 0.0, 0.075).set_delay(delay)
		active_tween.tween_method(func(v): flip_scale_x = v; queue_redraw(), 0.0, 1.0, 0.075).set_delay(delay + 0.075)

	await active_tween.finished
	is_animating = false
	queue_redraw()
	animation_finished.emit()

func _draw() -> void:
	if not is_animating or piece_texture == null:
		return

	var d_w = cell_size * 0.85 * toss_scale * abs(flip_scale_x)
	var d_h = cell_size * 0.85 * toss_scale

	if d_w <= 1.0:
		return

	var dest_rect = Rect2(anim_pos.x - d_w / 2.0, anim_pos.y - d_h / 2.0, d_w, d_h)

	var height_factor = (toss_scale - 1.0) / 0.6
	var shadow_offset = Vector2(2 + height_factor * 8.0, 4 + height_factor * 12.0)
	var shadow_rect = Rect2(dest_rect.position + shadow_offset, dest_rect.size)
	draw_texture_rect(piece_texture, shadow_rect, false, Color(0, 0, 0, 0.35))

	draw_texture_rect(piece_texture, dest_rect, false, Color.WHITE)

	var tile_rect = Rect2(anim_pos.x - cell_size / 2.0, anim_pos.y - cell_size / 2.0, cell_size, cell_size)
	PixelRenderer.draw_pixel_corners(self, tile_rect, Color(1.0, 0.85, 0.2, 0.9), 8.0, 2.0)
