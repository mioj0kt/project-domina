class_name PieceShatterView
extends Node2D

class Shard:
	var texture: AtlasTexture
	var pos: Vector2
	var vel: Vector2
	var rot: float = 0.0
	var rot_speed: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var alpha: float = 1.0
	var size: Vector2 = Vector2.ZERO

var active_shards: Array[Shard] = []
const GRAVITY: float = 850.0

func _ready() -> void:
	z_index = 50

func _process(delta: float) -> void:
	if active_shards.is_empty():
		return

	var expired: Array[Shard] = []
	for shard in active_shards:
		shard.vel.y += GRAVITY * delta
		shard.pos += shard.vel * delta
		shard.rot += shard.rot_speed * delta
		shard.alpha = max(0.0, shard.alpha - delta * 1.8)

		if shard.alpha <= 0.0:
			expired.append(shard)

	for gone in expired:
		active_shards.erase(gone)

	queue_redraw()

func shatter_piece(world_center: Vector2, piece: BoardPiece, cell_size: float) -> void:
	if piece == null:
		return

	var base_tex: Texture2D = PixelRenderer.get_piece_texture(piece)
	if base_tex == null:
		return

	var tex_w = base_tex.get_width()
	var tex_h = base_tex.get_height()
	var display_size = cell_size * 0.85

	var split_x = randf_range(0.35, 0.65) * tex_w
	var split_y = randf_range(0.35, 0.65) * tex_h

	var rects = [
		Rect2(0, 0, split_x, split_y),
		Rect2(split_x, 0, tex_w - split_x, split_y),
		Rect2(0, split_y, split_x, tex_h - split_y),
		Rect2(split_x, split_y, tex_w - split_x, tex_h - split_y)
	]

	var dir_bases = [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 0.6),
		Vector2(1, 0.6)
	]

	for i in range(4):
		var r = rects[i]
		if r.size.x <= 1 or r.size.y <= 1:
			continue

		var atlas = AtlasTexture.new()
		atlas.atlas = base_tex
		atlas.region = r

		var shard = Shard.new()
		shard.texture = atlas
		
		var shard_w = (r.size.x / tex_w) * display_size
		var shard_h = (r.size.y / tex_h) * display_size
		shard.size = Vector2(shard_w, shard_h)

		var offset_x = ((r.position.x + r.size.x / 2.0) / tex_w - 0.5) * display_size
		var offset_y = ((r.position.y + r.size.y / 2.0) / tex_h - 0.5) * display_size
		shard.pos = world_center + Vector2(offset_x, offset_y)

		var base_dir = dir_bases[i].normalized()
		var spread_angle = randf_range(-0.35, 0.35)
		var launch_dir = base_dir.rotated(spread_angle)
		var speed = randf_range(160.0, 320.0)

		shard.vel = Vector2(launch_dir.x * speed, launch_dir.y * speed - randf_range(60.0, 140.0))
		shard.rot_speed = randf_range(-12.0, 12.0)
		shard.alpha = 1.0

		active_shards.append(shard)

	queue_redraw()

func _draw() -> void:
	for shard in active_shards:
		if shard.alpha <= 0.0 or shard.texture == null:
			continue

		var dest = Rect2(-shard.size / 2.0, shard.size)
		draw_set_transform(shard.pos, shard.rot, shard.scale)
		draw_texture_rect(shard.texture, dest, false, Color(1.0, 1.0, 1.0, shard.alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
