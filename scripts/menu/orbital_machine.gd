class_name OrbitalMachine
extends Control
# MÁQUINA do Grimório: Cartas e Leis ainda bloqueadas orbitam um núcleo.
# SEGURAR o clique carrega (raios, relâmpagos, tremor, tiques subindo de tom);
# ao encher, tudo é sugado num vórtice, câmera lenta, o núcleo racha e explode
# na cor da raridade (feixe de luz, raios, ondas, faíscas, flash, tremor de tela).
# É preciso SEGURAR até encher: soltar antes cancela (não há clique rápido).
#
# Fluxo com a tela dona (MetaView):
#   charge_started  -> tela monta o palco em tela cheia
#   charge_complete -> tela paga/sorteia e chama resolve(tier, cor) (ou abort())
#   cancelled       -> soltou antes de encher
#   burst           -> hora de mostrar o prêmio
#   shake(amount)   -> tela aplica tremor
# Desenho em código; o brilho (aditivo) vai numa camada filha.

signal charge_started
signal charge_complete
signal cancelled
signal burst
signal sequence_done
signal shake(amount: float)

enum St { IDLE, CHARGING, WAIT, VORTEX, CRACK, BURST, REST }

const T_CHARGE: float = 1.7
const T_AUTO: float = 1.9
const T_WAIT: float = 0.3
const T_VORTEX: float = 1.0
const T_CRACK: float = 0.3
const T_BURST: float = 1.5
const MAX_TOKENS: int = 44
# Sorteios em sequência aceleram: 1º normal, depois mais rápidos. A sequência
# esfria se o jogador ficar mais de STREAK_COOLDOWN_MS sem sortear de novo.
const STREAK_SPEEDS: Array[float] = [1.0, 1.5, 2.0, 2.6, 3.2]
const STREAK_COOLDOWN_MS: int = 10000
const RARITY_COLS: Array[Color] = [
	Color(0.92, 0.88, 0.75), Color(0.3, 0.7, 0.95), Color(0.72, 0.4, 1.0), Color(1.0, 0.8, 0.25)]
const GOLD := Color(1.0, 0.8, 0.25)

class Glow extends Control:
	var m: OrbitalMachine
	func _draw() -> void:
		if m != null:
			m._draw_glow(self)

var enabled: bool = true
var hint_text: String = "SEGURE PARA DESBLOQUEAR"   # instrução desenhada sob o pedestal (parado)
var cards_left: int = 0
var rules_left: int = 0
var items: Array = []              # [{id,is_rule,rarity}] bloqueados: viram os sprites em órbita
var _tex_cache: Dictionary = {}

var _glow: Glow
var _overlay: Control
var key_allowed: Callable = Callable()   # devolve false quando a tecla não deve valer (ex.: tutorial aberto)
var _hold_key: bool = false
# static: a tela dona recria a máquina depois de cada sorteio, então a sequência
# precisa sobreviver à instância (antes zerava toda vez e nunca acelerava).
static var _streak: int = 0
static var _last_burst_ms: int = 0
var _spd: float = 1.0          # velocidade do sorteio atual (fixada ao começar a carga)
var crown_source: Callable = Callable()   # devolve a posição GLOBAL de onde as coroas saem
var _crowns: Array[Dictionary] = []
var _crown_acc: float = 0.0
var _crown_tex: Texture2D = null
var _st: int = St.IDLE
var _skipping: bool = false   # o jogador pulou a animação (clique/espaço depois de encher)
var _t: float = 0.0
var _time: float = 0.0
var _charge: float = 0.0
var _auto: bool = false
var _holding: bool = false
var _hold_t: float = 0.0
var _hover: bool = false
var _tier: int = 0
var _color: Color = GOLD
var _pend: bool = false
var _pend_tier: int = 0
var _pend_col: Color = GOLD
var _tokens: Array[Dictionary] = []
var _parts: Array[Dictionary] = []
var _rings: Array[float] = []
var _bolts: Array = []
var _bolt_acc: float = 0.0
var _flash: float = 0.0
var _show_t: float = 1.0
var _sc: float = 1.55

# ---- Rachaduras do altar (lore: o ritual se refazendo) ----
# O altar nasce rachado. Cada Carta/Lei desbloqueada FECHA uma parte das
# rachaduras (a luz que vazava por elas some, deixando uma cicatriz dourada fina).
# Quando tudo está desbloqueado, não resta nenhuma aberta. O jogador só acha
# que o altar está "ficando bonito"; ninguém explica.
const CRACK_N: int = 34
const CRACK_HEAL_TIME: float = 0.8
const CRACK_HEAL_GAP: float = 0.32
static var _cracks_shown: int = -1   # quantas estavam abertas da última vez que o altar foi visto
var total_items: int = 0             # total de itens desbloqueáveis (a tela dona informa)
var _crack_defs: Array = []          # [PackedVector2Array(xf, y)], da maior para a menor
var _crack_px: Array = []            # cache dos pixels de cada rachadura (offset de c.x / ped_y)
var _crack_px_wt: float = -1.0
var _crack_open: Array[float] = []   # 1 = aberta ... 0 = selada
var _heal_queue: Array[int] = []
var _healing: Array[int] = []
var _heal_delay: float = 0.0
var _heal_gap: float = 0.0
var _heal_flash: float = 0.0

# Texto e barra de carga ficam numa camada DEPOIS do filtro de pixel, pra
# continuarem nítidos.
class Overlay extends Control:
	var m: OrbitalMachine
	func _draw() -> void:
		if m != null:
			m._draw_overlay(self)

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 560)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	_glow = Glow.new()
	_glow.m = self
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	var ov := Overlay.new()
	ov.m = self
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)
	_overlay = ov
	_build_tokens()
	_init_cracks()
	_init_altars()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func is_busy() -> bool:
	return _st != St.IDLE

func _build_tokens() -> void:
	_tokens.clear()
	if not items.is_empty():
		var pool: Array = items.duplicate()
		pool.shuffle()
		for i in range(mini(pool.size(), MAX_TOKENS)):
			var it: Dictionary = pool[i]
			var tk := {"ring": randi() % 3, "ang": randf() * TAU, "rule": bool(it["is_rule"]),
				"rar": int(it["rarity"]), "ph": randf() * TAU, "tex": null, "icon": null}
			_fill_sprites(tk, it)
			_tokens.append(tk)
		return
	var total: int = cards_left + rules_left
	var n: int = mini(total, MAX_TOKENS)
	var n_rules: int = int(round(float(n) * float(rules_left) / float(maxi(total, 1))))
	for i in range(n):
		_tokens.append({
			"ring": randi() % 3, "ang": randf() * TAU, "rule": i < n_rules,
			"rar": [0, 0, 0, 1, 1, 2, 3][randi() % 7],
			"ph": randf() * TAU})

func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]

# Sprites reais: Carta = moldura da raridade + ícone; Lei = nota da categoria.
func _fill_sprites(tk: Dictionary, it: Dictionary) -> void:
	var id: String = String(it["id"])
	if bool(it["is_rule"]):
		for r in LootTables.get_all_rules():
			if r.id == id:
				tk["tex"] = _tex("res://assets/sprites/rules/back_%s.png" % RuleCard.get_category_slug(r.category))
				break
	else:
		var slug: String = ["common", "rare", "epic", "legendary"][clampi(int(it["rarity"]), 0, 3)]
		tk["tex"] = _tex("res://assets/sprites/cards/faces/back_%s.png" % slug)

# ---- entrada ----
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		if _st == St.IDLE and enabled:
			_holding = true
			_hold_key = false
			_hold_t = 0.0
			_auto = false
			_enter(St.CHARGING)
			_play_charge()
			charge_started.emit()
		elif skippable():
			accept_event()
			skip_to_reveal()

# Barra de espaço faz o mesmo que segurar o botão do mouse sobre o Oráculo.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or ev.keycode != KEY_SPACE or ev.echo:
		return
	if not is_visible_in_tree():
		return
	if key_allowed.is_valid() and not bool(key_allowed.call()):
		return
	if ev.pressed:
		if skippable():
			get_viewport().set_input_as_handled()
			skip_to_reveal()
			return
		if _st == St.IDLE and enabled:
			get_viewport().set_input_as_handled()
			_holding = true
			_hold_key = true
			_hold_t = 0.0
			_auto = false
			_enter(St.CHARGING)
			_play_charge()
			charge_started.emit()
	elif _hold_key:
		get_viewport().set_input_as_handled()

# Velocidade do sorteio atual (1.0 = normal). A tela dona usa o mesmo fator
# para encurtar as esperas dela (explosão, dica de "clique para continuar").
func speed() -> float:
	return _spd

# Depois que a carga enche (compressão, vórtex, rachadura, explosão) um novo
# clique ou toque da barra de espaço pula a animação direto para a carta virando.
func skippable() -> bool:
	if _skipping:
		return false
	return (_st == St.WAIT and _pend) or _st == St.VORTEX or _st == St.CRACK or _st == St.BURST

func is_skipping() -> bool:
	return _skipping

func skip_to_reveal() -> void:
	if not skippable():
		return
	_skipping = true
	Engine.time_scale = 1.0
	if _st == St.BURST:
		# a explosão já aconteceu: só encurta o resto (a tela dona deixa de esperar)
		_t = maxf(_t, 0.6)
		return
	if _pend:
		_pend = false
		_tier = _pend_tier
		_color = _pend_col
	Sfx.stop("maquina_carga")
	Sfx.stop("maquina_vortex")
	Sfx.stop("maquina_crack")
	_do_burst()

func _begin_speed() -> void:
	_skipping = false
	if _last_burst_ms > 0 and Time.get_ticks_msec() - _last_burst_ms > STREAK_COOLDOWN_MS:
		_streak = 0
	_spd = STREAK_SPEEDS[clampi(_streak, 0, STREAK_SPEEDS.size() - 1)]

func _play_charge() -> void:
	_begin_speed()
	# o riser dura ~1.9s; segurando (1.7s) acelera um pouco para fechar junto com a carga
	Sfx.play("maquina_carga", 0.0, (1.0 if _auto else T_AUTO / T_CHARGE) * minf(_spd, 2.2))

func begin_auto() -> void:
	if _st == St.IDLE and enabled:
		_auto = true
		_holding = false
		_enter(St.CHARGING)
		_play_charge()
		charge_started.emit()

func abort() -> void:
	_crowns.clear()
	Sfx.stop("maquina_carga")
	_auto = false
	_holding = false
	_enter(St.IDLE)
	cancelled.emit()

# A tela dona chama isto depois de sortear: tier = raridade (0..3).
func resolve(tier: int, color: Color) -> void:
	if _st != St.WAIT:
		return
	_pend_tier = clampi(tier, 0, 3)
	_pend_col = color
	_pend = true
	_t = 0.0                      # a compressão dura T_WAIT a partir daqui
	Sfx.stop("maquina_carga")
	Sfx.play("maquina_vortex")

func _enter(s: int) -> void:
	_st = s
	_t = 0.0

func _ts(v: float, real_secs: float = 0.0) -> void:
	Engine.time_scale = v
	if real_secs > 0.0:
		get_tree().create_timer(real_secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

# ---- simulação ----
func _process(dt: float) -> void:
	_time += dt
	var sdt: float = dt * (_spd if _st != St.IDLE else 1.0)   # tempo da sequência (acelera nos sorteios seguidos)
	_t += sdt
	_flash = maxf(_flash - dt * 1.8, 0.0)
	_sc = clampf(minf(size.x / 760.0, size.y / 500.0) * 1.3, 1.1, 2.2)
	_sc = clampf(minf(_sc, (size.y * 0.66 - 150.0) / 150.0), 1.0, 2.2)   # altar + legenda sempre cabem na altura
	var shk: float = 0.0
	match _st:
		St.IDLE:
			_charge = maxf(_charge - dt * 1.4, 0.0)
			_show_t = minf(_show_t + dt * 1.5, 1.0)
		St.CHARGING:
			_hold_t += sdt
			# soltar o botão antes de encher cancela: só segurando desbloqueia
			var still_down: bool = Input.is_key_pressed(KEY_SPACE) if _hold_key else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			if _holding and not still_down:
				_holding = false
				if _charge < 1.0:
					abort()
					return
			var rate: float = (1.0 / T_AUTO) if _auto else (1.0 / T_CHARGE)
			_charge = minf(_charge + sdt * rate, 1.0)
			# sem tiques: o riser contínuo já constrói a tensão (os tiques soavam como chocalho)
			shk = 9.0 * _charge * _charge
			_crown_acc += sdt
			var ci: float = lerpf(0.15, 0.045, _charge)
			while _crown_acc >= ci and _charge < 1.0:
				_crown_acc -= ci
				_spawn_crown()
			if _charge >= 1.0:
				_enter(St.WAIT)
				charge_complete.emit()
		St.WAIT:
			if _pend:
				var w0: float = clampf(_t / T_WAIT, 0.0, 1.0)
				shk = 9.0 + 5.0 * w0
				if _t >= T_WAIT:
					_pend = false
					_tier = _pend_tier
					_color = _pend_col
					_flash = 0.6
					_enter(St.VORTEX)
			else:
				shk = 9.0
				if _t > 6.0:
					abort()
					return
		St.VORTEX:
			shk = 6.0 + 8.0 * (_t / T_VORTEX)
			if _t >= T_VORTEX:
				_enter(St.CRACK)
				_ts(0.6)
				Sfx.play("maquina_crack")
		St.CRACK:
			shk = 20.0
			if _t >= T_CRACK:
				_do_burst()
		St.BURST:
			shk = 26.0 * maxf(0.0, 1.0 - _t / 0.6)
			if _t >= T_BURST:
				_enter(St.REST)
		St.REST:
			_charge = 0.0
			_show_t = 0.0
			_build_tokens()
			_enter(St.IDLE)
			sequence_done.emit()
	shake.emit(shk)
	_update_cracks(dt)
	_update_altars(dt)
	_update_crowns(dt)
	var spin: float = _spin_speed()
	for tk in _tokens:
		tk["ang"] = float(tk["ang"]) + dt * spin * (1.0 + 0.35 * float(tk["ring"])) * (1.0 if int(tk["ring"]) != 1 else -1.0)
	for p in _parts:
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * dt
		p["vel"] = Vector2(p["vel"]) * (1.0 - dt * 1.3) + Vector2(0, 220.0 * dt * float(p["grav"]))
		p["life"] = float(p["life"]) - dt
	var alive: Array[Dictionary] = []
	for p in _parts:
		if float(p["life"]) > 0.0:
			alive.append(p)
	_parts = alive
	var keep: Array[float] = []
	for i in range(_rings.size()):
		_rings[i] += dt * (700.0 + 200.0 * _tier) * _sc * 0.6
		if _rings[i] < 1400.0:
			keep.append(_rings[i])
	_rings = keep
	_bolt_acc += dt
	if _bolt_acc > 0.05:
		_bolt_acc = 0.0
		_regen_bolts()
	queue_redraw()
	_glow.queue_redraw()

func _spin_speed() -> float:
	match _st:
		St.IDLE: return 0.45 + (0.25 if _hover and enabled else 0.0)
		St.CHARGING: return 0.45 + 8.0 * _charge * _charge
		St.WAIT: return 8.45 + (6.0 * clampf(_t / T_WAIT, 0.0, 1.0) if _pend else 0.0)
		St.VORTEX: return 8.0 + 16.0 * (_t / T_VORTEX)
		_: return 1.0

func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.34)

func _do_burst() -> void:
	_enter(St.BURST)
	_flash = 0.5 if _skipping else 1.0
	if _skipping:
		_t = T_BURST - 0.5   # pulou: a explosão é só um estalo, sem tremor nem câmera lenta
	else:
		_ts(0.25, 0.28)
	_rings.clear()
	_rings.append_array([0.0, -90.0, -200.0] if _tier >= 2 else [0.0, -110.0])
	if not _skipping:
		Sfx.play_variant("maquina_boom", _tier)
	var c := _center()
	var n: int = (24 if _skipping else 70 + 55 * _tier)
	for i in range(n):
		var a: float = randf() * TAU
		var sp: float = randf_range(180.0, 520.0 + 140.0 * _tier) * _sc * 0.7
		var spark: bool = i % 3 != 0
		_parts.append({
			"pos": c, "vel": Vector2(cos(a), sin(a)) * sp + Vector2(0, -120),
			"life": randf_range(0.8, 1.7), "max": 1.7, "grav": 0.0 if spark else 1.0,
			"col": _color.lerp(Color.WHITE, randf() * 0.6), "sz": randf_range(2.5, 6.5) * _sc * 0.7,
			"spark": spark})
	burst.emit()
	_streak += 1
	_last_burst_ms = Time.get_ticks_msec()

func _regen_bolts() -> void:
	_bolts.clear()
	if not (_st == St.CHARGING or _st == St.WAIT or _st == St.VORTEX):
		return
	var cnt: int = 0
	if _st == St.VORTEX:
		cnt = 6
	elif _charge > 0.2:
		cnt = int(1.0 + _charge * 5.0)
	if cnt == 0 or _tokens.is_empty():
		return
	var c := _center()
	for i in range(cnt):
		var tk: Dictionary = _tokens[randi() % _tokens.size()]
		var rr: float = _ring_radius(int(tk["ring"])) * _radius_mul()
		var a2: float = float(tk["ang"])
		var from := c + Vector2(cos(a2) * rr, sin(a2) * rr * 0.42)
		var pts := PackedVector2Array()
		var seg: int = 8
		var dir := (c - from)
		var perp := dir.orthogonal().normalized()
		for s in range(seg + 1):
			var f: float = float(s) / seg
			var off: float = 0.0 if (s == 0 or s == seg) else randf_range(-1.0, 1.0) * 22.0 * _sc * 0.6 * sin(f * PI)
			pts.append(from.lerp(c, f) + perp * off)
		_bolts.append(pts)

func _ring_radius(r: int) -> float:
	return [145.0, 208.0, 272.0][r] * _sc

func _radius_mul() -> float:
	match _st:
		St.CHARGING: return 1.0 - 0.3 * _charge
		St.WAIT: return 0.7 - (0.12 * clampf(_t / T_WAIT, 0.0, 1.0) if _pend else 0.0)
		St.VORTEX:
			var f: float = clampf(_t / T_VORTEX, 0.0, 1.0)
			return 0.7 * (1.0 - f * f * f)
		St.CRACK, St.BURST: return 0.0
		_: return 1.0

func _intensity() -> float:
	match _st:
		St.IDLE: return 0.15 + 0.07 * sin(_time * 2.0) + (0.1 if _hover and enabled else 0.0)
		St.CHARGING, St.WAIT: return 0.2 + 0.8 * _charge
		St.VORTEX, St.CRACK: return 1.0
		St.BURST: return maxf(0.0, 1.0 - _t / 0.8)
	return 0.1

func _base_col() -> Color:
	if not enabled and _st == St.IDLE:
		return Color(0.5, 0.45, 0.6)
	if _st == St.VORTEX or _st == St.CRACK or _st == St.BURST:
		return GOLD.lerp(_color, clampf(_t / 0.4, 0.0, 1.0)) if _st == St.VORTEX else _color
	return GOLD

# ---- desenho normal (corpo) ----
func _draw() -> void:
	var c := _center()
	var dead: bool = not enabled and _st == St.IDLE
	var base_col := _base_col()
	var k := _intensity()
	if dead:
		k = 0.05
	var ped_y: float = c.y + 150.0 * _sc
	_draw_pedestal(c, ped_y, base_col, k)

	var rad_mul := _radius_mul()
	if _st != St.BURST and _st != St.CRACK:
		for r in range(3):
			var rr: float = _ring_radius(r) * rad_mul
			if rr < 4.0:
				continue
			PixelBeam.ring(self, c, rr, Color(base_col, 0.14 + 0.2 * k), PIX, 1, 0.42)

	var alpha_all: float = _show_t if _st == St.IDLE else 1.0
	if _st == St.CRACK or _st == St.BURST:
		alpha_all = 0.0
	if _st == St.VORTEX:
		var f: float = clampf(_t / T_VORTEX, 0.0, 1.0)
		alpha_all = 1.0 - f * f
	var front: Array = []
	for tk in _tokens:
		var rr2: float = _ring_radius(int(tk["ring"])) * rad_mul
		var a2: float = float(tk["ang"])
		var bob: float = sin(_time * 1.6 + float(tk["ph"])) * 0.0
		var pos := Vector2(cos(a2) * rr2, sin(a2) * rr2 * 0.42 + bob)
		var depth: float = (sin(a2) + 1.0) * 0.5
		var item := {"pos": c + pos, "depth": depth, "tk": tk, "a": alpha_all}
		if depth < 0.5:
			_draw_token(item, base_col, dead, k)
		else:
			front.append(item)

	# núcleo sólido (o brilho fica na camada aditiva)
	if _st != St.BURST:
		var core_r: float = (20.0 + 24.0 * k) * (1.0 + 0.06 * sin(_time * 3.0)) * _sc
		if _st == St.WAIT and _pend:
			core_r *= lerpf(1.0, 0.45, clampf(_t / T_WAIT, 0.0, 1.0))
		PixelBeam.disc(self, c, core_r + PIX, Color("#241a2b"), PIX)
		PixelBeam.disc(self, c, core_r, Color(base_col, 0.95).lerp(Color.WHITE, 0.35 + 0.5 * k), PIX)
		PixelBeam.disc(self, c, core_r * 0.55, Color(1, 1, 1, 0.6 + 0.4 * k), PIX)
	for item in front:
		_draw_token(item, base_col, dead, k)

	if _overlay != null:
		_overlay.queue_redraw()

func _draw_token(item: Dictionary, base_col: Color, dead: bool, k: float) -> void:
	var tk: Dictionary = item["tk"]
	var depth: float = float(item["depth"])
	var s: float = (0.7 + 0.5 * depth) * _sc * 0.65   # cartas/leis em órbita menores
	var a: float = float(item["a"]) * (0.6 + 0.4 * depth)
	if a <= 0.01:
		return
	var p: Vector2 = item["pos"]
	var col: Color = GOLD if bool(tk["rule"]) else RARITY_COLS[int(tk["rar"])]
	if dead:
		col = Color(0.4, 0.38, 0.45)
	col = col.lerp(base_col, 0.1 + 0.3 * k)
	var font := get_theme_default_font()
	var tex: Texture2D = tk.get("tex")
	if tex != null:
		# brilho na cor da raridade atrás do sprite
		var tint := Color(1, 1, 1, a)
		if dead:
			tint = Color(0.45, 0.43, 0.5, a)
		if bool(tk["rule"]):
			var sz := Vector2(60, 60) * s * 0.9
			var bt: Texture2D = _baked(tex, sz)
			var bs: Vector2 = bt.get_size()
			draw_texture(bt, (p - bs * 0.5).round(), tint)
		else:
			var sz := Vector2(160, 224) * 0.2 * s
			var bt2: Texture2D = _baked(tex, sz)
			var bs2: Vector2 = bt2.get_size()
			var tl: Vector2 = (p - bs2 * 0.5).round()
			draw_rect(Rect2(tl, bs2).grow(3.0 * s * 0.6), Color(col, 0.35 * a))
			draw_texture(bt2, tl, tint)
		return
	if bool(tk["rule"]):
		# Lei: selo redondo com losango e estrela
		var rr: float = 13.0 * s
		draw_circle(p, rr + 2.0, Color(0.1, 0.06, 0.05, a))
		draw_circle(p, rr, Color(col, a))
		draw_circle(p, rr * 0.7, Color(0.16, 0.1, 0.2, a))
		var h: float = rr * 0.55
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -h), p + Vector2(h, 0), p + Vector2(0, h), p + Vector2(-h, 0)]), Color(col, a))
	else:
		# Carta misteriosa: moldura brilhante na cor da raridade + "?"
		var w: float = 19.0 * s
		var hh: float = 27.0 * s
		var r := Rect2(p - Vector2(w * 0.5, hh * 0.5), Vector2(w, hh))
		draw_rect(r.grow(2.0), Color(0.05, 0.03, 0.07, a))
		draw_rect(r, Color(col, a))
		draw_rect(r.grow(-2.5 * s * 0.6), Color(0.15, 0.1, 0.2, a))
		draw_string(font, p + Vector2(-5.0 * s, 6.0 * s), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * s), Color(col, a))

# ---- camada aditiva (brilho) ----
func _draw_glow(g: Control) -> void:
	var c := _center()
	var base_col := _base_col()
	var k := _intensity()
	var dead: bool = not enabled and _st == St.IDLE
	if dead:
		k = 0.04
	_draw_cracks_glow(g, c, c.y + 150.0 * _sc, k)
	_draw_altar_glow(g, c, c.y + 150.0 * _sc)
	# raios afilados com degradê (brilho no centro, somem na ponta)
	var ray_a: float = 0.0
	var ray_len: float = 0.0
	var ray_n: int = 18
	match _st:
		St.IDLE:
			ray_a = 0.05 + 0.05 * k
			ray_len = 260.0 * _sc * 0.8
		St.CHARGING, St.WAIT:
			ray_a = 0.08 + 0.3 * _charge
			ray_len = (240.0 + 420.0 * _charge) * _sc * 0.8
		St.VORTEX, St.CRACK:
			ray_a = 0.4
			ray_len = 760.0 * _sc * 0.8
		St.BURST:
			var f: float = clampf(_t / T_BURST, 0.0, 1.0)
			ray_a = 0.7 * (1.0 - f)
			ray_len = (1000.0 + 700.0 * f) * _sc * 0.8
			ray_n = 22 + 8 * _tier
	if ray_a > 0.01 and not dead:
		for i in range(ray_n):
			var spd: float = (0.18 + 0.4 * k) * (1.0 if i % 2 == 0 else -0.6)
			var a0: float = _time * spd + i * TAU / ray_n + sin(i * 12.9) * 0.2
			var w: float = 0.012 + 0.012 * (0.5 + 0.5 * sin(i * 7.3))   # raios finos, larguras variadas
			var ln: float = ray_len * (0.55 + 0.45 * (0.5 + 0.5 * sin(i * 4.1 + _time * 2.5)))
			var hot := Color(base_col.lerp(Color.WHITE, 0.5), minf(ray_a * 2.2, 1.0))
			PixelBeam.beam(g, c + Vector2(cos(a0), sin(a0)) * 14.0 * _sc, a0, ln, clampf(w * 2.0, 0.04, 0.07), hot)
	# compressão: anéis convergindo para o núcleo
	if _st == St.WAIT and _pend:
		var w1: float = clampf(_t / T_WAIT, 0.0, 1.0)
		for i in range(3):
			var q: float = fmod(w1 * 1.6 + i / 3.0, 1.0)
			var rr: float = (1.0 - q) * 300.0 * _sc * 0.8
			PixelBeam.ring(g, c, rr, Color(base_col.lerp(Color.WHITE, 0.4), 0.7 * q), PIX, 2 + int(q * 3.0))
	# redemoinho: braços em espiral sugando para o núcleo
	if _st == St.VORTEX:
		var vf: float = clampf(_t / T_VORTEX, 0.0, 1.0)
		for arm in range(6):
			var prev := Vector2.ZERO
			var steps: int = 28
			for st in range(steps + 1):
				var u: float = float(st) / steps        # 0 = fora, 1 = dentro
				var rr2: float = (1.0 - u) * 330.0 * _sc * 0.8 * (1.0 - vf * 0.6)
				var ang: float = arm * TAU / 6.0 + _time * 7.0 + u * 5.0
				var pt: Vector2 = c + Vector2(cos(ang) * rr2, sin(ang) * rr2 * 0.6)
				if st > 0:
					PixelBeam.line(g, prev, pt, Color(base_col.lerp(Color.WHITE, u * 0.6), 0.25 + u * 0.5), PIX, 1)
				prev = pt
	# halo do núcleo
	if _st != St.BURST:
		var core_r: float = (20.0 + 24.0 * k) * _sc
		for i in range(6):
			PixelBeam.disc(g, c, core_r * (3.2 - i * 0.5), Color(base_col, 0.03 + 0.03 * k), PIX)
	# relâmpagos
	for bolt in _bolts:
		var pts: PackedVector2Array = bolt
		for bi in range(pts.size() - 1):
			PixelBeam.line(g, pts[bi], pts[bi + 1], Color(base_col, 0.5), PIX, 5)
			PixelBeam.line(g, pts[bi], pts[bi + 1], Color(1, 1, 1, 0.95), PIX, 1)
	# feixe de luz subindo na explosão
	if _st == St.BURST:
		var f2: float = clampf(_t / 0.9, 0.0, 1.0)
		var bw: float = (70.0 + 30.0 * _tier) * _sc * 0.7 * (1.0 - f2 * 0.8)
		for i in range(6):
			var ww: float = bw * (1.0 - i * 0.15)
			g.draw_rect(Rect2(roundf((c.x - ww * 0.5) / PIX) * PIX, -20.0, roundf(ww / PIX) * PIX, c.y + 20.0), Color(_color.lerp(Color.WHITE, i * 0.1), 0.07 * (1.0 - f2)))
	# lens flare: estrela de 4 pontas + linha horizontal
	if _st == St.BURST or _st == St.CRACK:
		var ff: float = 1.0 if _st == St.CRACK else maxf(0.0, 1.0 - _t / 0.9)
		var fl: float = (260.0 + 120.0 * _tier) * _sc * 0.8 * (ff if _st == St.BURST else _t / T_CRACK)
		for sgn in [-1.0, 1.0]:
			PixelBeam.beam(g, c, 0.0 if sgn > 0.0 else PI, fl * 2.6, 0.05, Color(1, 1, 1, 0.9 * ff))
			PixelBeam.beam(g, c, PI * 0.5 * sgn, fl * 1.3, 0.09, Color(1, 1, 1, 0.8 * ff))
	# ondas de choque
	for rv in _rings:
		if rv > 0.0:
			var al: float = clampf(1.0 - rv / 1100.0, 0.0, 1.0)
			PixelBeam.ring(g, c, rv, Color(_color, 0.35 * al), PIX, 8)
			PixelBeam.ring(g, c, rv, Color(1, 1, 1, 0.8 * al), PIX, 1)
	# faíscas
	for p in _parts:
		var pa: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var pos: Vector2 = p["pos"]
		var col: Color = p["col"]
		var sz: float = float(p["sz"])
		var q: float = PIX
		var sp := Vector2(roundf(pos.x / q) * q, roundf(pos.y / q) * q)
		g.draw_rect(Rect2(sp - Vector2(q, q) * 0.5, Vector2(q, q) * (2.0 if sz > 5.0 else 1.0)), Color(col, pa))
		if pa > 0.5:
			g.draw_rect(Rect2(sp - Vector2(q, q) * 0.25, Vector2(q, q) * 0.5), Color(1, 1, 1, pa))
	# flash central
	if _flash > 0.0:
		PixelBeam.disc(g, c, (300.0 * _flash + 60.0) * _sc * 0.7, Color(_color.lerp(Color.WHITE, 0.6), 0.55 * _flash), PIX * 1.5)

func _draw_overlay(g: Control) -> void:
	_draw_crowns(g)
	var c := _center()
	var ped_y: float = c.y + 150.0 * _sc
	var base_col := _base_col()
	# instrução parada: pulsa sob o pedestal (ou o motivo de estar desligado)
	if _st == St.IDLE and hint_text != "":
		var hf := get_theme_default_font()
		var hs: int = int(30.0 * _sc * 0.8)
		var pulse: float = 0.8 + 0.2 * sin(_time * 3.0) if enabled else 0.8
		var hcol: Color = Color(GOLD, pulse) if enabled else Color(0.75, 0.6, 0.6, pulse)
		var tw: Vector2 = hf.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs)
		var hp := Vector2(c.x - tw.x * 0.5, ped_y + 30.0 + hs * 0.35)   # no meio do pedestal
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(2, 2)]:
			g.draw_string(hf, hp + o, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(0.1, 0.06, 0.14, pulse))
		g.draw_string(hf, hp, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, hcol)

	_draw_altar_labels(g, c, ped_y)

	# barra de carga
	if _st == St.CHARGING or _st == St.WAIT:
		var bw: float = 260.0 * _sc * 0.8
		var bp := Vector2(c.x - bw * 0.5, ped_y + 120.0)
		var ink := Color("#241a2b")
		g.draw_rect(Rect2(bp - Vector2(4, 4), Vector2(bw + 8, 20)), ink)
		var seg: int = int(bw / 12.0)
		var on_n: int = int(round(float(seg) * _charge))
		for i in range(seg):
			var cc: Color = base_col.lerp(Color.WHITE, 0.3) if i < on_n else Color("#3a2b41")
			g.draw_rect(Rect2(bp + Vector2(i * 12.0, 0), Vector2(10, 12)), cc)

const PED_PX: int = 2
const PIX: float = 2.0

# Altar estilizado em vista FRONTAL (sem perspectiva): três blocos de pedra
# empilhados, o de cima largo o bastante pra servir de placa pro texto.
func _block(cx: float, y: float, w: float, h: float, body: Color, trim: Color, P: float) -> void:
	var ink := Color("#241a2b")
	var x: float = roundf((cx - w * 0.5) / P) * P
	draw_rect(Rect2(x - P * 2.0, y - P * 2.0, w + P * 4.0, h + P * 4.0), ink)
	draw_rect(Rect2(x, y, w, h), body)
	# luz em cima/esquerda, sombra embaixo/direita
	draw_rect(Rect2(x, y, w, P * 2.0), body.lightened(0.25))
	draw_rect(Rect2(x, y, P * 2.0, h), body.lightened(0.12))
	draw_rect(Rect2(x, y + h - P * 2.0, w, P * 2.0), body.darkened(0.3))
	draw_rect(Rect2(x + w - P * 2.0, y, P * 2.0, h), body.darkened(0.2))
	# filete dourado
	draw_rect(Rect2(x, y + P * 2.0, w, P), trim)

func _draw_pedestal(c: Vector2, ped_y: float, base_col: Color, k: float) -> void:
	var P: float = float(PED_PX)
	var plum_d := Color("#3a2b41")
	var plum_m := Color("#5a4561")
	var gold := Color("#d9a441")
	var gold_d := Color("#9a6f2a")
	var cream := Color("#efe6cf")
	var glow_col: Color = base_col.lerp(Color.WHITE, 0.15)
	var trim: Color = gold.lerp(glow_col, 0.2 + 0.5 * k)
	var wt: float = 380.0 * _sc * 0.8
	var h1: float = 56.0
	var h2: float = 30.0
	var h3: float = 30.0
	# base, meio e topo (de baixo pra cima)
	_block(c.x, ped_y + h1 + h2, wt * 1.30, h3, plum_d, gold_d, P)
	_block(c.x, ped_y + h1, wt * 1.15, h2, plum_m.darkened(0.1), gold_d, P)
	_block(c.x, ped_y, wt, h1, plum_m, trim, P)
	# faixa em xadrez no bloco do meio (tema de damas)
	var cell: float = 12.0
	var cols: int = int(wt * 1.15 / cell) - 2
	var x0: float = c.x - cols * cell * 0.5
	for i in range(cols):
		var cc: Color = plum_d if i % 2 == 0 else plum_m.lightened(0.08)
		draw_rect(Rect2(x0 + i * cell, ped_y + h1 + P * 4.0, cell, cell), cc)
		draw_rect(Rect2(x0 + i * cell, ped_y + h1 + P * 4.0 + cell, cell, cell * 0.5), cc.darkened(0.15))
	# runa acesa no topo: linha de glifos que acendem com a energia
	var n: int = 9
	for i in range(n):
		var gx: float = roundf((c.x - wt * 0.46 + float(i) * wt * 0.92 / float(n - 1)) / P) * P
		var on: bool = k > 0.15 and (i + int(_time * 1.2)) % 3 == 0
		var gc: Color = Color(glow_col, 0.5 + 0.5 * k) if on else gold_d
		draw_rect(Rect2(gx - P, ped_y + h1 - P * 5.0, P * 3.0, P), gc)
		draw_rect(Rect2(gx, ped_y + h1 - P * 6.0, P, P * 3.0), gc)
	# pinos dourados nos cantos do bloco de cima
	for sgn in [-1.0, 1.0]:
		var sx: float = roundf((c.x + sgn * (wt * 0.5 - P * 5.0)) / P) * P
		draw_rect(Rect2(sx - P * 2.0, ped_y + P * 5.0, P * 4.0, P * 4.0), gold)
		draw_rect(Rect2(sx - P * 2.0, ped_y + P * 5.0, P * 2.0, P * 2.0), cream)
	_draw_cracks_body(c, ped_y)
	_draw_mini_altars(c, ped_y)
	# brilho da energia saindo do topo do altar (faixas)
	for i in range(3):
		var bw: float = wt * (0.5 - i * 0.14)
		draw_rect(Rect2(c.x - bw * 0.5, ped_y - P * (2 + i * 2), bw, P * 2.0), Color(glow_col, (0.12 + 0.3 * k) * (1.0 - i * 0.25)))

# ---- altares de luz (progresso) ----
# Seis altares de cada lado do altar principal, um por categoria de Lei (a cor do
# pilar de luz é a cor da categoria). O progresso é geral (Cartas + Leis juntas) e
# os dois lados são espelhados: acendem do centro para fora. Cada desbloqueio enche
# um pouco do altar da vez (o pilar dele cresce). Tudo desbloqueado: os doze acesos
# e uma coluna dourada liga o altar principal ao núcleo.
const ALTARS_PER_SIDE: int = 6
const ALTAR_CATS: Array[int] = [
	RuleCard.Category.MOVEMENT, RuleCard.Category.CAPTURE, RuleCard.Category.PROMOTION,
	RuleCard.Category.TURN, RuleCard.Category.BOARD, RuleCard.Category.COMBO]
static var _lvl_shown: float = -1.0   # nível exibido da última vez (0..ALTARS_PER_SIDE)
var _lvl: float = 0.0
var _lvl_target: float = 0.0
var _lvl_delay: float = 0.0
var _altar_flash: Array[float] = []

func _altar_col(idx: int) -> Color:
	return RuleCard.get_category_color(ALTAR_CATS[idx])

func _unlock_frac() -> float:
	var left: int = cards_left + rules_left
	if left <= 0:
		return 1.0
	if total_items <= 0:
		return 0.0
	return clampf(1.0 - float(left) / float(maxi(total_items, left)), 0.0, 1.0)

func _init_altars() -> void:
	_altar_flash.clear()
	for i in range(ALTARS_PER_SIDE):
		_altar_flash.append(0.0)
	_lvl_target = float(ALTARS_PER_SIDE) * _unlock_frac()
	if _lvl_shown < 0.0 or _lvl_shown >= _lvl_target - 0.001:
		_lvl = _lvl_target
	else:
		_lvl = _lvl_shown            # desbloqueou algo: o nível sobe devagar, com clarão
		_lvl_delay = 1.0
	_lvl_shown = _lvl_target

func _update_altars(dt: float) -> void:
	for i in range(_altar_flash.size()):
		_altar_flash[i] = maxf(_altar_flash[i] - dt * 1.2, 0.0)
	if _st != St.IDLE:
		return
	if _lvl_delay > 0.0:
		_lvl_delay -= dt
		return
	if _lvl < _lvl_target:
		var nl: float = minf(_lvl + dt * 1.2, _lvl_target)
		for k in range(ALTARS_PER_SIDE):
			if _lvl < float(k + 1) and nl >= float(k + 1) - 0.0001:
				_altar_flash[k] = 1.0
		_lvl = nl

func _altar_x(c: Vector2, side: int, idx: int) -> float:
	var wt: float = 380.0 * _sc * 0.8
	var start: float = wt * 0.65 + 38.0
	var avail: float = size.x * 0.5 - 24.0 - start
	var sp: float = clampf(avail / (float(ALTARS_PER_SIDE) - 0.5), 40.0, 58.0)
	var sgn: float = -1.0 if side == 0 else 1.0
	return c.x + sgn * (start + float(idx) * sp)

func _draw_mini_altars(c: Vector2, ped_y: float) -> void:
	var P: float = float(PED_PX)
	var plum_d := Color("#3a2b41")
	var plum_m := Color("#5a4561")
	var gold_d := Color("#9a6f2a")
	var ink := Color("#241a2b")
	var floor_y: float = ped_y + 116.0
	for side in range(2):
		for idx in range(ALTARS_PER_SIDE):
			var col: Color = _altar_col(idx)
			var a: float = clampf(_lvl - float(idx), 0.0, 1.0)
			var cx: float = _altar_x(c, side, idx)
			var trim: Color = gold_d.lerp(col, a)
			# pedestal de braseiro: base larga, coluna fina e taça no topo
			_block(cx, floor_y - 14.0, 50.0, 14.0, plum_d, gold_d, P)
			_block(cx, floor_y - 38.0, 22.0, 24.0, plum_m.darkened(0.1), trim, P)
			_block(cx, floor_y - 50.0, 40.0, 12.0, plum_m, trim, P)
			# glifo na coluna: acende junto
			var gc: Color = Color(col, 0.4 + 0.6 * a) if a > 0.0 else gold_d
			var gx: float = roundf(cx / P) * P
			draw_rect(Rect2(gx - P, floor_y - 31.0, P * 2.0, P * 5.0), gc)
			draw_rect(Rect2(gx - P * 3.0, floor_y - 28.0, P * 6.0, P * 2.0), gc)
			# engaste da luz: apagado = cavidade escura; aceso = esfera na cor da categoria
			var oc := Vector2(cx, floor_y - 61.0)
			PixelBeam.disc(self, oc, 10.0, ink, P)
			if a > 0.0:
				PixelBeam.disc(self, oc, 5.0 + 4.0 * a, Color(col, 0.55 + 0.4 * a).lerp(Color.WHITE, 0.25 * a), P)
				if a > 0.6:
					PixelBeam.disc(self, oc, 3.0, Color(1, 1, 1, 0.9), P)
			else:
				PixelBeam.disc(self, oc, 5.0, plum_d, P)

func _draw_altar_glow(g: Control, c: Vector2, ped_y: float) -> void:
	var P: float = float(PED_PX)
	var floor_y: float = ped_y + 116.0
	for side in range(2):
		for idx in range(ALTARS_PER_SIDE):
			var col: Color = _altar_col(idx)
			var a: float = clampf(_lvl - float(idx), 0.0, 1.0)
			var fl: float = _altar_flash[idx] if idx < _altar_flash.size() else 0.0
			if a <= 0.0 and fl <= 0.0:
				continue
			var cx: float = _altar_x(c, side, idx)
			var oy: float = floor_y - 61.0
			var pulse: float = 0.85 + 0.15 * sin(_time * 2.2 + float(idx) * 0.8 + float(side) * 1.7)
			var h: float = lerpf(60.0, 330.0, a) * (1.0 + 0.4 * fl)
			var step: float = 6.0
			var n: int = int(h / step)
			var bx: float = roundf(cx / P) * P
			for sl in range(n):
				var t: float = float(sl) / float(n)
				var y: float = oy - 10.0 - float(sl) * step
				var fade: float = pow(1.0 - t, 1.6)
				var al: float = (0.16 + 0.5 * a) * pulse * fade + 0.35 * fl * fade
				var hw: float = lerpf(18.0, 6.0, t)
				g.draw_rect(Rect2(bx - hw, y, hw * 2.0, step), Color(col, al * 0.35))
				var cw: float = lerpf(6.0, 2.5, t)
				g.draw_rect(Rect2(bx - cw, y, cw * 2.0, step), Color(col.lerp(Color.WHITE, 0.4), al))
			# brilho da esfera
			PixelBeam.disc(g, Vector2(cx, oy), 14.0 + 8.0 * a + 14.0 * fl, Color(col, (0.12 + 0.25 * a) * pulse + 0.3 * fl), P * 2.0)
			# faíscas subindo pelo pilar
			for k in range(3):
				var ph: float = fmod(_time * 0.55 + float(k) * 0.33 + float(idx) * 0.17 + float(side) * 0.5, 1.0)
				var sx: float = cx + sin(float(idx * 7 + k) * 1.3) * 6.0
				var sz: float = P * (2.0 - ph)
				g.draw_rect(Rect2(roundf(sx / P) * P, oy - 10.0 - ph * h, sz, sz), Color(col.lerp(Color.WHITE, 0.5), (1.0 - ph) * a * 0.9))
	# tudo aceso: coluna dourada do altar até o núcleo
	var full: bool = _lvl >= float(ALTARS_PER_SIDE) - 0.001
	if full and _st == St.IDLE:
		var top: float = c.y + 30.0
		var cp: float = 0.8 + 0.2 * sin(_time * 2.0)
		var y2: float = ped_y - 4.0
		while y2 > top:
			var t2: float = (ped_y - y2) / maxf(ped_y - top, 1.0)
			g.draw_rect(Rect2(c.x - 11.0, y2, 22.0, 6.0), Color(GOLD, 0.16 * cp * (1.0 - t2 * 0.5)))
			g.draw_rect(Rect2(c.x - 3.0, y2, 6.0, 6.0), Color(1.0, 0.95, 0.75, 0.45 * cp * (1.0 - t2 * 0.5)))
			y2 -= 6.0

func _draw_altar_labels(g: Control, c: Vector2, ped_y: float) -> void:
	if _st != St.IDLE or total_items <= 0:
		return
	var left: int = cards_left + rules_left
	var txt: String = "DESBLOQUEADO  %d/%d" % [maxi(total_items - left, 0), total_items]
	var f := get_theme_default_font()
	var fs: int = 22
	var floor_y: float = ped_y + 116.0
	var tw: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tp := Vector2(c.x - tw.x * 0.5, floor_y + 22.0)
	var col := Color("#efe6cf")
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		g.draw_string(f, tp + o * 1.5, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.06, 0.14, 0.9))
	g.draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.85))

# ---- rachaduras do altar ----
func _target_open() -> int:
	var rem: int = cards_left + rules_left
	if rem <= 0:
		return 0
	var tot: int = maxi(total_items, rem)
	return clampi(int(ceil(float(CRACK_N) * float(rem) / float(tot))), 1, CRACK_N)

func _init_cracks() -> void:
	_gen_cracks()
	var target: int = _target_open()
	var shown: int = _cracks_shown
	_crack_open.clear()
	var start_open: int = target if (shown < 0 or shown <= target) else shown
	for i in range(CRACK_N):
		_crack_open.append(1.0 if i < start_open else 0.0)
	_heal_queue.clear()
	_healing.clear()
	if start_open > target:
		# desbloqueou algo desde a última vez: as rachaduras que sobraram fecham, uma a uma
		for i in range(start_open - 1, target - 1, -1):
			_heal_queue.append(i)
		_heal_delay = 1.0
	_cracks_shown = target

# Rachaduras em coordenadas do altar: x em fração da largura do bloco de cima,
# y em pixels (0 = topo do altar, 116 = base). Fixas (semente) pra serem sempre as mesmas.
func _gen_cracks() -> void:
	if not _crack_defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var raw: Array = []
	# a grande: desce pelos três blocos, perto da quina (longe do texto)
	var big := PackedVector2Array()
	var bx: float = 0.34
	var by: float = 0.0
	while by < 106.0:
		big.append(Vector2(bx, by))
		by += rng.randf_range(6.0, 10.0)
		bx += rng.randf_range(-0.035, 0.035)
	raw.append(big)
	var big2 := PackedVector2Array()
	var b2x: float = -0.36
	var b2y: float = 0.0
	while b2y < 106.0:
		big2.append(Vector2(b2x, b2y))
		b2y += rng.randf_range(6.0, 10.0)
		b2x += rng.randf_range(-0.04, 0.04)
	raw.append(big2)
	for i in range(CRACK_N * 4):
		if raw.size() >= CRACK_N:
			break
		# pontos de partida bem espalhados (sequência R2), pra não amontoar
		var y0: float = fposmod(0.5 + float(i) * 0.7548776662, 1.0) * 98.0
		var half: float = _block_half(y0) - 0.04
		var x0: float = (fposmod(0.5 + float(i) * 0.5698402909, 1.0) - 0.5) * 2.0 * half
		var pts := PackedVector2Array()
		var steps: int = rng.randi_range(3, 9)
		var dir: float = rng.randf_range(-0.6, 0.6)
		var cx: float = x0
		var cy: float = y0
		for st in range(steps):
			if cy > 108.0 or absf(cx) > _block_half(cy):
				break
			pts.append(Vector2(cx, cy))
			cy += rng.randf_range(5.0, 10.0)
			cx += dir * 0.035 + rng.randf_range(-0.035, 0.035)
			if rng.randf() < 0.25:
				dir = -dir
		if pts.size() >= 3:
			raw.append(pts)
	# ordem: maiores primeiro (as últimas a fechar são as mais dramáticas)
	raw.sort_custom(func(a, b): return _poly_len(a) > _poly_len(b))
	for r in raw:
		_crack_defs.append(r)
	while _crack_defs.size() > CRACK_N:
		_crack_defs.pop_back()

func _block_half(y: float) -> float:
	# metade da largura (em fração de wt) do bloco na altura y
	if y < 56.0:
		return 0.5
	if y < 86.0:
		return 0.575
	return 0.65

func _poly_len(pts: PackedVector2Array) -> float:
	var n: float = 0.0
	for i in range(pts.size() - 1):
		n += absf(pts[i + 1].y - pts[i].y) + absf(pts[i + 1].x - pts[i].x) * 400.0
	return n

func _crack_pixels(wt: float) -> void:
	if absf(wt - _crack_px_wt) < 0.5 and _crack_px.size() == _crack_defs.size():
		return
	_crack_px_wt = wt
	_crack_px.clear()
	var P: float = float(PED_PX)
	for pts in _crack_defs:
		var out := PackedVector2Array()
		var last := Vector2(INF, INF)
		for i in range(pts.size() - 1):
			var pa := Vector2(pts[i].x * wt, pts[i].y)
			var pb := Vector2(pts[i + 1].x * wt, pts[i + 1].y)
			var n: int = maxi(int(ceil(pa.distance_to(pb) / P)), 1)
			for st in range(n):
				var q: Vector2 = pa.lerp(pb, float(st) / float(n))
				q = Vector2(roundf(q.x / P) * P, roundf(q.y / P) * P)
				if q == last:
					continue
				# zona do texto do altar: sem rachadura por baixo das letras
				if absf(q.x) < wt * 0.26 and q.y > 16.0 and q.y < 46.0:
					continue
				out.append(q)
				last = q
		_crack_px.append(out)

func _update_cracks(dt: float) -> void:
	_heal_flash = maxf(_heal_flash - dt * 2.5, 0.0)
	if _st != St.IDLE:
		return
	if _heal_delay > 0.0:
		_heal_delay -= dt
		return
	_heal_gap -= dt
	if _heal_gap <= 0.0 and not _heal_queue.is_empty():
		_healing.append(_heal_queue.pop_front())
		_heal_gap = CRACK_HEAL_GAP
	var still: Array[int] = []
	for i in _healing:
		_crack_open[i] = maxf(_crack_open[i] - dt / CRACK_HEAL_TIME, 0.0)
		if _crack_open[i] <= 0.0:
			_heal_flash = 1.0
		else:
			still.append(i)
	_healing = still

# largura do miolo da rachadura: grossa no começo, afina até a ponta
func _crack_w(j: int, n: int) -> float:
	var f: float = float(j) / float(maxi(n, 1))
	var P: float = float(PED_PX)
	if f < 0.3:
		return P * 2.0
	return P

func _draw_cracks_body(c: Vector2, ped_y: float) -> void:
	if _crack_defs.is_empty() or _crack_open.size() != _crack_defs.size():
		return
	var P: float = float(PED_PX)
	var wt: float = 380.0 * _sc * 0.8
	_crack_pixels(wt)
	var core := Color("#241a2b")     # mesmo "ink" do contorno dos blocos
	var lit := Color("#6f5878")      # luz da pedra pegando no lábio da fenda (luz vem de cima/esquerda)
	var scar := Color("#9a6f2a")     # mesmo dourado escuro dos filetes
	# 1) cicatrizes douradas (o que já fechou)
	for i in range(_crack_px.size()):
		var px: PackedVector2Array = _crack_px[i]
		var vis: int = int(ceil(_crack_open[i] * float(px.size())))
		for j in range(vis, px.size()):
			var q: Vector2 = px[j]
			draw_rect(Rect2(c.x + q.x, ped_y + q.y, P, P), Color(scar, 0.7))
	# 2) lábio iluminado (embaixo/direita da fenda), depois o miolo escuro
	for pass_i in range(2):
		for i in range(_crack_px.size()):
			var px2: PackedVector2Array = _crack_px[i]
			var vis2: int = int(ceil(_crack_open[i] * float(px2.size())))
			for j in range(vis2):
				var q2: Vector2 = px2[j]
				var cs: float = _crack_w(j, px2.size())
				if pass_i == 0:
					draw_rect(Rect2(c.x + q2.x + P, ped_y + q2.y + P, cs, cs), lit)
				else:
					draw_rect(Rect2(c.x + q2.x, ped_y + q2.y, cs, cs), core)

func _draw_cracks_glow(g: Control, c: Vector2, ped_y: float, k: float) -> void:
	if _crack_defs.is_empty() or _crack_open.size() != _crack_defs.size() or _crack_px.size() != _crack_defs.size():
		return
	var P: float = float(PED_PX)
	var kk: float = clampf(k, 0.0, 1.0)
	var seam_b := Color(1.0, 0.82, 0.4)     # dourado do altar (cresce com a energia)
	var seam: Color = Color("#d9a441").lerp(seam_b, kk)
	for i in range(_crack_px.size()):
		var px: PackedVector2Array = _crack_px[i]
		var n: int = px.size()
		var vis: int = int(ceil(_crack_open[i] * float(n)))
		var pulse: float = 0.8 + 0.2 * sin(_time * 1.7 + float(i) * 0.9)
		var a: float = (0.1 + 0.4 * kk) * pulse   # parado: só um fio de luz; carregando: acende
		for j in range(vis):
			var q: Vector2 = px[j]
			var cs: float = _crack_w(j, n)
			g.draw_rect(Rect2(c.x + q.x + cs * 0.25, ped_y + q.y + cs * 0.25, maxf(cs * 0.5, P * 0.5), maxf(cs * 0.5, P * 0.5)), Color(seam, a))
		# onda de luz dourada selando a ponta: some deixando a cicatriz
		if _healing.has(i):
			var t: float = 1.0 - _crack_open[i]
			for j in range(vis, mini(vis + 10, n)):
				var q2: Vector2 = px[j]
				var fa: float = 1.0 - float(j - vis) / 10.0
				g.draw_rect(Rect2(c.x + q2.x, ped_y + q2.y, P * 2.0, P * 2.0), Color(seam_b, 0.5 * fa))
			if vis > 0 and vis <= n:
				var qf: Vector2 = px[vis - 1]
				g.draw_rect(Rect2(c.x + qf.x - P * 0.5, ped_y + qf.y - P * 0.5, P * 3.0, P * 3.0), Color(1.0, 0.95, 0.75, 0.85 * (1.0 - t * 0.4)))
	# clarão dourado percorrendo o altar quando uma rachadura termina de fechar
	if _heal_flash > 0.0:
		var wt: float = 380.0 * _sc * 0.8
		g.draw_rect(Rect2(c.x - wt * 0.5, ped_y, wt, P * 2.0), Color(seam_b, 0.45 * _heal_flash))

# ---- coroas voando até o núcleo enquanto segura ----
func _spawn_crown() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var src: Vector2 = Vector2(size.x * 0.92, 20.0)
	if crown_source.is_valid():
		src = inv * Vector2(crown_source.call())
	src += Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
	var tgt: Vector2 = _center()
	var mid: Vector2 = src.lerp(tgt, 0.5)
	var perp: Vector2 = (tgt - src).orthogonal().normalized()
	var ctrl: Vector2 = mid + perp * randf_range(-220.0, 220.0) - Vector2(0, randf_range(40.0, 160.0))
	_crowns.append({"a": src, "c": ctrl, "t": 0.0, "dur": randf_range(0.55, 0.85), "pos": src, "trail": []})

func _update_crowns(dt: float) -> void:
	if _crowns.is_empty():
		return
	var tgt: Vector2 = _center()
	var keep: Array[Dictionary] = []
	for cr in _crowns:
		cr["t"] = float(cr["t"]) + dt
		var u: float = clampf(float(cr["t"]) / float(cr["dur"]), 0.0, 1.0)
		var e: float = u * u * (3.0 - 2.0 * u) * 0.35 + u * u * 0.65   # acelera ao chegar
		var a: Vector2 = cr["a"]
		var c1: Vector2 = cr["c"]
		var pos: Vector2 = a * pow(1.0 - e, 2.0) + c1 * 2.0 * (1.0 - e) * e + tgt * e * e
		var trail_pts: Array = cr["trail"]
		trail_pts.push_front(Vector2(cr["pos"]))
		if trail_pts.size() > 4:
			trail_pts.pop_back()
		cr["pos"] = pos
		if u >= 1.0:
			_flash = maxf(_flash, 0.12)
			for i in range(3):
				var ang: float = randf() * TAU
				_parts.append({"pos": tgt, "vel": Vector2(cos(ang), sin(ang)) * randf_range(80.0, 220.0), "life": 0.4, "max": 0.4,
					"col": GOLD, "sz": 3.0, "spark": false, "grav": 0.0})
			Sfx.play("coroa_conta", -11.0)
		else:
			keep.append(cr)
	_crowns = keep

func _draw_crowns(g: Control) -> void:
	if _crowns.is_empty():
		return
	if _crown_tex == null:
		_crown_tex = PixelUI.hud_texture("icone_coroa", 1)
	for cr in _crowns:
		var u: float = clampf(float(cr["t"]) / float(cr["dur"]), 0.0, 1.0)
		var sz: float = lerpf(46.0, 24.0, u * u)
		var al: float = 1.0 - maxf(u - 0.85, 0.0) / 0.15
		var trail_pts: Array = cr["trail"]
		for i in range(trail_pts.size()):
			var tp: Vector2 = trail_pts[i]
			var q: float = 4.0 - i
			g.draw_rect(Rect2(roundf(tp.x / 2.0) * 2.0 - q, roundf(tp.y / 2.0) * 2.0 - q, q * 2.0, q * 2.0), Color(GOLD, 0.35 * al * (1.0 - i * 0.2)))
		var p: Vector2 = cr["pos"]
		p = Vector2(roundf(p.x / 2.0) * 2.0, roundf(p.y / 2.0) * 2.0)
		if _crown_tex != null:
			g.draw_texture_rect(_crown_tex, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, al))
		else:
			g.draw_rect(Rect2(p - Vector2(sz, sz) * 0.3, Vector2(sz, sz) * 0.6), Color(GOLD, al))

# Sprite redimensionado UMA vez (Lanczos) para um tamanho inteiro e desenhado 1:1,
# em degraus de 2 px: sem reamostragem a cada quadro, então nada de pixels quebrados.
var _baked_cache: Dictionary = {}
func _baked(tex: Texture2D, want: Vector2) -> Texture2D:
	var w: int = maxi(8, int(roundf(want.x / 2.0)) * 2)
	var h: int = maxi(8, int(roundf(want.y / want.x * float(w))))
	var key: String = "%s_%d_%d" % [tex.resource_path, w, h]
	if _baked_cache.has(key):
		return _baked_cache[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var t := ImageTexture.create_from_image(img)
	_baked_cache[key] = t
	return t
