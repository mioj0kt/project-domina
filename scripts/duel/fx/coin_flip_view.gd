class_name CoinFlipView
extends Node2D

# Moeda: um lado é a peça comum BRANCA e o outro a peça comum PRETA. O sinal
# devolve se o resultado foi FAVORÁVEL — ou seja, se a moeda caiu no lado cuja
# cor é `favorable_is_white` (por padrão o lado branco; efeitos de carta/lei
# usam play_toss_for_team() pra tornar favorável a cor do time beneficiado).
signal flip_completed(favorable: bool)

# Troca os sprites das duas faces da moeda (padrão: peça comum branca vs peça
# comum preta). Só usado em casos especiais; os efeitos de jogo mantêm o par
# padrão pra a moeda sempre significar BRANCA x PRETA.
func set_side_textures(new_white_path: String, new_black_path: String) -> void:
	white_sprite_path = new_white_path
	black_sprite_path = new_black_path
	_reload_textures()

func _reload_textures() -> void:
	white_texture = load(white_sprite_path) if ResourceLoader.exists(white_sprite_path) else null
	black_texture = load(black_sprite_path) if ResourceLoader.exists(black_sprite_path) else null

var is_animating: bool = false
var is_finished: bool = false
var show_coin: bool = false
var is_white_side: bool = true
# Lado da moeda que conta como resultado favorável (true = branca).
var favorable_is_white: bool = true
# Cor em que a moeda caiu no último arremesso (true = branca).
var landed_white: bool = true
# -1 = aleatório; 1 = cai branca; 0 = cai preta. O tutorial força o resultado
# para o Duelo 1 ser sempre o mesmo (jogador de brancas, começa jogando).
var forced_result: int = -1
# Moeda Viciada: time cuja cor a PRÓXIMA moeda (de qualquer CoinFlipView) vai
# mostrar; consumido ao arremessar. 0 = ninguém. Estático porque as moedas de
# carta, de lei e de várias moedas são nós separados.
static var rigged_team: int = 0
var _pending_lands_white: bool = true
# Esta moeda foi armada pela Moeda Viciada / Lei da Moeda Fiel: ganha halo
# dourado, faíscas orbitando e uma explosão ao pousar.
var _rigged_toss: bool = false
var _fx_t: float = 0.0
const RIGGED_GOLD := Color(1.0, 0.82, 0.25)

func _process(delta: float) -> void:
	if show_coin and _rigged_toss:
		_fx_t += delta
		queue_redraw()

func _roll_lands_white() -> bool:
	if forced_result == 1:
		return true
	if forced_result == 0:
		return false
	if rigged_team != 0:
		var rigged_white = (rigged_team == Board.WHITE)
		rigged_team = 0
		return rigged_white
	return randi() % 2 == 0
var coin_center: Vector2 = Vector2.ZERO
var cell_size: float = 64.0

var flip_scale_x: float = 1.0
var toss_scale: float = 1.0

var active_tween: Tween
var active_timer: SceneTreeTimer
var result_label: Label

# Quando true (padrão, uso avulso — início de duelo, cartas), a moeda
# some sozinha um tempo depois de mostrar o resultado. Quando false (usado
# pelo MultiCoinFlipView numa sequência), a moeda FICA parada mostrando o
# resultado final indefinidamente — quem a criou é responsável por
# escondê-la (só quando a sequência inteira terminar), não a moeda sozinha.
var auto_hide_coin_after_result: bool = true

# Textos customizáveis — outros usos (como uma aposta) podem trocar por
# mensagens próprias antes de chamar play_toss(). Os valores padrão mantêm
# o comportamento original (sorteio de brancas/pretas no início do duelo).
var win_text: String = "VOCE JOGA COM AS BRANCAS!"
var lose_text: String = "VOCE JOGA COM AS PRETAS!"

var white_sprite_path: String = "res://assets/sprites/pieces/white.png"
var black_sprite_path: String = "res://assets/sprites/pieces/black.png"

var white_texture: Texture2D
var black_texture: Texture2D

func _ready() -> void:
	_reload_textures()

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 42)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	result_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	result_label.add_theme_constant_override("outline_size", 8)
	result_label.visible = false
	add_child(result_label)

# Arremesso em que o resultado favorável é a moeda cair na cor de `team`
# (Board.WHITE / Board.BLACK). Os textos mostram a cor sorteada seguida da
# consequência: "PRETA! TURNO EXTRA PRA VOCE!" / "BRANCA... TURNO EXTRA...".
func play_toss_for_team(p_center: Vector2, p_cell_size: float, team: int, win_msg: String, lose_msg: String) -> void:
	set_side_textures("res://assets/sprites/pieces/white.png", "res://assets/sprites/pieces/black.png")
	favorable_is_white = (team == Board.WHITE)
	win_text = "%s! %s" % [color_word(favorable_is_white), win_msg]
	lose_text = "%s... %s" % [color_word(not favorable_is_white), lose_msg]
	play_toss(p_center, p_cell_size)

static func color_word(is_white: bool) -> String:
	return "BRANCA" if is_white else "PRETA"

func play_toss(p_center: Vector2, p_cell_size: float) -> void:
	_kill_tweens()

	coin_center = p_center
	cell_size = p_cell_size
	is_animating = true
	is_finished = false
	show_coin = true
	flip_scale_x = 1.0
	toss_scale = 1.0
	result_label.visible = false

	result_label.position = Vector2(coin_center.x - 350.0, coin_center.y - cell_size * 2.2)
	result_label.size = Vector2(700, 60)

	active_tween = create_tween()
	active_tween.set_parallel(true)

	# 1. Efeito de Altura
	active_tween.tween_property(self, "toss_scale", 1.85, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "toss_scale", 1.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.65)

	# 2. Giro da Moeda
	var total_flips = 9
	for i in range(total_flips):
		var delay = i * 0.14
		active_tween.tween_method(func(v): flip_scale_x = v; queue_redraw(), 1.0, 0.0, 0.07).set_delay(delay)
		active_tween.tween_callback(func(): is_white_side = not is_white_side).set_delay(delay + 0.07)
		active_tween.tween_method(func(v): flip_scale_x = v; queue_redraw(), 0.0, 1.0, 0.07).set_delay(delay + 0.07)

	# Precisa ser lido ANTES do _roll_lands_white(), que consome a moeda armada.
	_rigged_toss = rigged_team != 0 and forced_result == -1
	_fx_t = 0.0
	var lands_white = _roll_lands_white()
	_pending_lands_white = lands_white
	active_tween.chain().tween_callback(func(): _finish_flip(lands_white))

func skip_spin() -> void:
	if not is_animating or is_finished:
		return

	_kill_tweens()
	_finish_flip(_pending_lands_white)

func _kill_tweens() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null

func _finish_flip(lands_white: bool) -> void:
	if is_finished:
		return
	is_finished = true
	is_animating = false
	_kill_tweens()

	landed_white = lands_white
	var favorable = (lands_white == favorable_is_white)
	is_white_side = lands_white
	flip_scale_x = 1.0
	toss_scale = 1.0

	result_label.text = win_text if favorable else lose_text
	result_label.visible = true
	queue_redraw()
	if _rigged_toss and is_inside_tree():
		var gpos: Vector2 = to_global(coin_center)
		Juice.ring(self, gpos, cell_size * 1.4, RIGGED_GOLD, 6.0, 0.4)
		Juice.sparkle(self, gpos, 26)

	active_timer = get_tree().create_timer(1.4)
	await active_timer.timeout

	result_label.visible = false
	if auto_hide_coin_after_result:
		show_coin = false
	queue_redraw()

	flip_completed.emit(favorable)

func _draw() -> void:
	if not show_coin:
		return

	var current_tex = white_texture if is_white_side else black_texture
	var base_diameter = cell_size * 0.95 * toss_scale
	var w = base_diameter * abs(flip_scale_x)
	var h = base_diameter

	if w <= 1.0:
		return

	var dest_rect = Rect2(coin_center.x - (w / 2.0), coin_center.y - (h / 2.0), w, h)

	if _rigged_toss:
		_draw_rigged_aura(base_diameter, w)

	var height_factor = (toss_scale - 1.0) / 0.85
	var shadow_offset = Vector2(4 + height_factor * 12.0, 6 + height_factor * 20.0)
	var shadow_scale = 1.0 + (height_factor * 0.25)
	var shadow_w = w * shadow_scale
	var shadow_h = h * shadow_scale
	var shadow_rect = Rect2(
		coin_center.x - (shadow_w / 2.0) + shadow_offset.x,
		coin_center.y - (shadow_h / 2.0) + shadow_offset.y,
		shadow_w,
		shadow_h
	)
	var shadow_alpha = clamp(0.45 - (height_factor * 0.2), 0.2, 0.45)

	if current_tex != null:
		draw_texture_rect(current_tex, shadow_rect, false, Color(0, 0, 0, shadow_alpha))
		draw_texture_rect(current_tex, dest_rect, false, Color(1.2, 1.1, 0.8) if _rigged_toss else Color.WHITE)
	else:
		var bg_col = Color(0.92, 0.92, 0.95) if is_white_side else Color(0.18, 0.2, 0.24)
		draw_rect(shadow_rect, Color(0, 0, 0, shadow_alpha))
		draw_rect(dest_rect, bg_col)
		draw_rect(dest_rect, Color(0.08, 0.08, 0.1), false, 2.0)

# Halo dourado pulsante (camadas de círculos) + 6 faíscas quadradas orbitando.
func _draw_rigged_aura(diameter: float, coin_w: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_fx_t * 7.0)
	for i in range(4):
		var r: float = diameter * (0.58 + 0.13 * i + 0.05 * pulse)
		draw_circle(coin_center, r, Color(RIGGED_GOLD.r, RIGGED_GOLD.g, RIGGED_GOLD.b, 0.20 - 0.04 * i))
	var px: float = maxf(4.0, diameter / 12.0)
	for i in range(6):
		var a: float = _fx_t * 3.2 + i * TAU / 6.0
		var rr: float = diameter * (0.78 + 0.06 * sin(_fx_t * 5.0 + i))
		var p: Vector2 = coin_center + Vector2(cos(a), sin(a)) * rr
		draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), Color(1.0, 0.95, 0.6, 0.9))
