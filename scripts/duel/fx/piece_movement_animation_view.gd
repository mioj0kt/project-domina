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

# Pulo em arco (como na primeira versão): desliza linear até a casa enquanto
# sobe e desce numa parábola, crescendo um pouco no ponto mais alto.
func play_move_jump(from_center: Vector2, to_center: Vector2, piece: BoardPiece, cell_size: float, is_capture: bool) -> void:
	is_animating = true
	active_piece = piece
	active_cell_size = cell_size
	current_anim_pos = from_center
	_move_dir = (to_center - from_center).normalized() if from_center != to_center else Vector2.RIGHT
	_move_from = from_center
	_move_len = maxf(1.0, from_center.distance_to(to_center))
	_spark_clock = 0.0

	var tween = create_tween().set_parallel(true)
	var duration = 0.25 if not is_capture else 0.31
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
	# Pousa exatamente na casa e segura a peça desenhada por mais 1 quadro, para
	# não haver lacuna (peça sumindo/piscando) na troca para o desenho do tabuleiro.
	current_anim_pos = to_center
	jump_offset_y = 0.0
	jump_scale = 1.0
	queue_redraw()
	landed.emit(to_center, is_capture)
	await get_tree().process_frame

	is_animating = false
	active_piece = null
	queue_redraw()
	jump_completed.emit()

# Faíscas de movimento: quadradinhos cremes/dourados que a peça solta durante o
# pulo e que caem devagar, sumindo.
var _sparks: Array = []   # {pos, vel, age, life, size, col}
var _spark_clock: float = 0.0
const SPARK_COLORS := [Color(0.80, 0.74, 0.63), Color(0.68, 0.62, 0.53), Color(0.88, 0.83, 0.73)]   # poeira fosca, sem brilho
var _move_dir: Vector2 = Vector2.RIGHT
var _move_from: Vector2 = Vector2.ZERO
var _move_len: float = 1.0

func _process(delta: float) -> void:
	if _sparks.is_empty() and not is_animating:
		return
	for sp in _sparks:
		sp["age"] += delta
		sp["vel"].y += 70.0 * delta
		sp["pos"] += sp["vel"] * delta
	_sparks = _sparks.filter(func(sp): return sp["age"] < sp["life"])
	# Só solta poeira na primeira parte do trajeto (peça ainda rápida) e sempre
	# ATRÁS dela, perto de onde veio: nada surge no centro quando ela desacelera.
	var progress: float = current_anim_pos.distance_to(_move_from) / _move_len
	if is_animating and active_piece != null and progress < 0.65:
		_spark_clock += delta
		while _spark_clock >= 0.022:
			_spark_clock -= 0.022
			var back: Vector2 = current_anim_pos - _move_dir * active_cell_size * 0.38
			var side: Vector2 = Vector2(-_move_dir.y, _move_dir.x)
			_sparks.append({
				"pos": back + side * randf_range(-0.18, 0.18) * active_cell_size + Vector2(0, jump_offset_y + active_cell_size * 0.12),
				"vel": Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)),
				"age": 0.0, "life": randf_range(0.25, 0.4),
				"size": maxf(3.0, active_cell_size / randf_range(12.0, 17.0)),
				"len": randf_range(2.5, 4.5),
				"col": SPARK_COLORS[randi() % SPARK_COLORS.size()]})
	queue_redraw()

# Cada faísca é um retângulo esticado no sentido do movimento (rastro de
# poeira), que encolhe e some com o tempo. Cores foscas, sem brilho.
func _draw_sparks() -> void:
	var ang: float = _move_dir.angle() + PI   # cauda para trás
	for sp in _sparks:
		var k: float = 1.0 - sp["age"] / sp["life"]
		var w: float = sp["size"] * (0.5 + 0.5 * k)
		var l: float = w * sp["len"] * (0.4 + 0.6 * k)
		var c: Color = sp["col"]
		c.a = 0.75 * k
		draw_set_transform(sp["pos"].round(), ang, Vector2.ONE)
		draw_rect(Rect2(0.0, -w / 2.0, l, w), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	_draw_sparks()
	if not is_animating or active_piece == null:
		return

	# Sombra suave no chão projetada sob a peça
	var shadow_radius = (active_cell_size * 0.32) * (1.0 - (-jump_offset_y / 100.0))
	draw_circle(current_anim_pos + Vector2(2, 4), max(6.0, shadow_radius), Color(0.0, 0.0, 0.0, 0.32))

	# Desenho da peça elevada (pixel inteiro: sem tremida do sprite)
	var draw_pos = (current_anim_pos + Vector2(0, jump_offset_y)).round()
	PixelRenderer.draw_piece(self, active_piece, draw_pos, active_cell_size, jump_scale)
