class_name Music
extends Node
# Trilha sonora do jogo. Um nó próprio (criado na primeira chamada, filho da raiz,
# então sobrevive à troca de cenas) toca no canal "Music" com fade cruzado.
# Uso: Music.play("menu") | Music.play("floresta") | Music.play("") = fade out.
# Se a faixa pedida já está tocando, não reinicia (menu -> meta -> menu continua).
# Duelos: Music.play_duel("floresta") toca seções de 8 compassos sorteadas (sem repetir a
# anterior), cada uma em 2 camadas sincronizadas (base + tensão). Music.set_tension(0..1)
# faz a camada de tensão subir/descer; Music.muffle(true/false) abafa tudo (moeda girando).
# As faixas são geradas por tools/music_gen.py e tools/music_duel.py.

const TRACKS := {
	"menu": "res://assets/audio/musica/mapa/menu.ogg",
	"floresta": "res://assets/audio/musica/mapa/floresta.ogg",
	"deserto": "res://assets/audio/musica/mapa/deserto.ogg",
	"mina": "res://assets/audio/musica/mapa/mina.ogg",
}
# (+6 dB em relação à versão antiga: a trilha estava baixa mesmo no 100%)
const TRACK_DB := {"menu": -1.0, "floresta": -2.0, "deserto": -2.0, "mina": -2.0}
const SILENT_DB := -60.0
# Seções de duelo: musica/duelo/<bioma>/ e musica/duelo/chefe_<bioma>/ (os nomes dos
# arquivos continuam os que tools/music_*.py geram).
const DUEL_DIR := "res://assets/audio/musica/duelo/"

const DUEL_SECTIONS := {"floresta": 6, "deserto": 6, "mina": 6, "boss_floresta": 6, "boss_deserto": 6, "boss_mina": 6}
const DUEL_SD_SECTIONS := {"floresta": 2, "deserto": 2, "mina": 2, "boss_floresta": 2, "boss_deserto": 2, "boss_mina": 2}   # Morte Súbita: andamento maior, mais seco e urgente
const DUEL_BASE_DB := -3.0
const DUEL_TENSION_DB := -2.0
const MUFFLE_HZ := 900.0
const OPEN_HZ := 20500.0

static var _inst: Music = null
# --- duelo
var _duel_biome: String = ""
var _duel_on: bool = false
var _duel_master: float = 0.0       # 0..1 (fade geral do duelo)
var _duel_master_target: float = 0.0
var _tension: float = 0.0
var _tension_target: float = 0.0
var _slots: Array = []              # 2 slots: {"base": player, "tens": player, "len": float, "live": bool}
var _slot_cur: int = 0
var _last_section: int = -1
var _sd_on: bool = false
var _last_sd: int = -1
var _lpf: AudioEffectLowPassFilter = null
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer = null
var _current: String = ""
var _tween: Tween = null

func _duel_folder() -> String:
	return _duel_biome.replace("boss_", "chefe_")

static func play(track: String, fade: float = 1.6) -> void:
	if _inst == null or not is_instance_valid(_inst):
		var loop := Engine.get_main_loop()
		if not (loop is SceneTree):
			return
		_inst = Music.new()
		(loop as SceneTree).root.add_child.call_deferred(_inst)
	# adiado: a raiz pode estar "ocupada" montando a cena que chamou isto
	_inst._go.call_deferred(track, fade)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.ensure_buses()
	_a = _make_player()
	_b = _make_player()
	for i in range(2):
		_slots.append({"base": _make_player(), "tens": _make_player(), "len": 0.0, "live": false, "gain": 1.0, "gain_t": 1.0})
	var bus := AudioServer.get_bus_index("Music")
	if bus != -1:
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = OPEN_HZ
		AudioServer.add_bus_effect(bus, _lpf)

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = SILENT_DB
	add_child(p)
	return p

func _go(track: String, fade: float) -> void:
	var was_duel := _duel_on
	_muffle(false, 0.2)   # nunca deixa o filtro preso (ex.: moeda interrompida por troca de cena)
	if was_duel:
		_duel_stop(fade)
	if track == _current and not was_duel:
		return
	_current = track
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var old := _active
	if old != null:
		var tw_out := create_tween()
		tw_out.tween_property(old, "volume_db", SILENT_DB, fade)
		tw_out.tween_callback(old.stop)
	if track == "" or not TRACKS.has(track):
		_active = null
		return
	var stream: AudioStream = load(TRACKS[track])
	if stream == null:
		_active = null
		return
	if "loop" in stream:
		stream.loop = true
	var nxt: AudioStreamPlayer = _b if old == _a else _a
	nxt.stream = stream
	nxt.volume_db = SILENT_DB
	nxt.play()
	_active = nxt
	_tween = create_tween()
	_tween.tween_property(nxt, "volume_db", float(TRACK_DB.get(track, -8.0)), fade)

# ----------------------------------------------------------------- duelos ---
static func play_duel(biome: String, fade: float = 1.5) -> void:
	_ensure_inst()
	_inst._duel_start.call_deferred(biome, fade)

# Morte Súbita: troca (com fade rápido) para as seções próprias, mais rápidas e urgentes.
static func sudden_death() -> void:
	_ensure_inst()
	_inst._sd_start.call_deferred()

static func set_tension(v: float, _time: float = 1.2) -> void:
	_ensure_inst()
	_inst._tension_target = clampf(v, 0.0, 1.0)

# Abafa a música (filtro passa-baixa) enquanto algo importante acontece; false = solta.
static func muffle(on: bool, time: float = 0.3) -> void:
	_ensure_inst()
	_inst._muffle.call_deferred(on, time)

static func _ensure_inst() -> void:
	if _inst == null or not is_instance_valid(_inst):
		var loop := Engine.get_main_loop()
		if not (loop is SceneTree):
			return
		_inst = Music.new()
		(loop as SceneTree).root.add_child.call_deferred(_inst)

func _muffle(on: bool, time: float) -> void:
	if _lpf == null:
		return
	var tw := create_tween()
	tw.tween_property(_lpf, "cutoff_hz", MUFFLE_HZ if on else OPEN_HZ, time)

func _duel_start(biome: String, fade: float) -> void:
	if not DUEL_SECTIONS.has(biome):
		return
	if _duel_on and _duel_biome == biome:
		return
	_muffle(false, 0.2)
	# tira a trilha comum (menu/mapa) em fade
	if _current != "":
		_current = ""
		if _active != null:
			var old := _active
			var tw := create_tween()
			tw.tween_property(old, "volume_db", SILENT_DB, fade)
			tw.tween_callback(old.stop)
			_active = null
	_duel_biome = biome
	_duel_on = true
	_duel_master_target = 1.0
	_tension = 0.0
	_tension_target = 0.0
	_sd_on = false
	for sl in _slots:
		sl["live"] = false
	_start_section(0, false)

func _sd_start() -> void:
	if not _duel_on or _sd_on or not DUEL_SD_SECTIONS.has(_duel_biome):
		return
	_sd_on = true
	var old := _slot_cur
	_slots[old]["gain_t"] = 0.0
	_start_section(1 - old, true)

func _duel_stop(_fade: float) -> void:
	_duel_master_target = 0.0
	_duel_on = false      # _process termina o fade e para os players

func _pick_section() -> int:
	var n: int = int(DUEL_SECTIONS[_duel_biome])
	var s := randi() % n + 1
	if n > 1 and s == _last_section:
		s = s % n + 1
	_last_section = s
	return s

func _start_section(slot_i: int, fade_in: bool) -> void:
	var sl: Dictionary = _slots[slot_i]
	var base_path: String
	var tens_path: String
	if _sd_on:
		var n: int = int(DUEL_SD_SECTIONS[_duel_biome])
		var k := randi() % n + 1
		if n > 1 and k == _last_sd:
			k = k % n + 1
		_last_sd = k
		base_path = DUEL_DIR + "%s/duel_%s_sd%d.ogg" % [_duel_folder(), _duel_biome, k]
		tens_path = ""
	else:
		var sec := _pick_section()
		base_path = DUEL_DIR + "%s/duel_%s_s%d_base.ogg" % [_duel_folder(), _duel_biome, sec]
		tens_path = DUEL_DIR + "%s/duel_%s_s%d_tensao.ogg" % [_duel_folder(), _duel_biome, sec]
	if not ResourceLoader.exists(base_path):
		return
	var bs: AudioStream = load(base_path)
	var ts: AudioStream = load(tens_path) if (tens_path != "" and ResourceLoader.exists(tens_path)) else null
	sl["base"].stream = bs
	sl["tens"].stream = ts
	sl["len"] = bs.get_length()
	sl["live"] = true
	sl["gain"] = 0.0 if fade_in else 1.0
	sl["gain_t"] = 1.0
	sl["base"].play()
	if ts != null:
		sl["tens"].play()
	_slot_cur = slot_i

func _process(delta: float) -> void:
	if _inst != self:
		return
	# fade geral
	_duel_master = move_toward(_duel_master, _duel_master_target, delta / 1.5)
	_tension = move_toward(_tension, _tension_target, delta / 2.0)
	var mdb: float = linear_to_db(maxf(_duel_master, 0.0001))
	var tdb: float = linear_to_db(maxf(_tension, 0.0001)) * 0.6   # sobe suave, sem salto
	for sl in _slots:
		if not sl["live"]:
			continue
		sl["gain"] = move_toward(float(sl["gain"]), float(sl["gain_t"]), delta * 3.0)
		var gdb: float = linear_to_db(maxf(float(sl["gain"]), 0.0001))
		sl["base"].volume_db = DUEL_BASE_DB + mdb + gdb
		sl["tens"].volume_db = DUEL_TENSION_DB + mdb + maxf(tdb, -50.0) + gdb
		if float(sl["gain_t"]) <= 0.0 and float(sl["gain"]) <= 0.001:
			sl["base"].stop()
			sl["tens"].stop()
			sl["live"] = false
	if not _duel_on:
		if _duel_master <= 0.001:
			for sl in _slots:
				if sl["live"]:
					sl["base"].stop()
					sl["tens"].stop()
					sl["live"] = false
		return
	# encadeia a próxima seção um pouquinho antes do fim da atual (sem buraco)
	var cur: Dictionary = _slots[_slot_cur]
	if cur["live"] and cur["base"].playing and float(cur["len"]) - cur["base"].get_playback_position() < 0.10:
		var nxt := 1 - _slot_cur
		_start_section(nxt, false)
	for sl in _slots:
		if sl["live"] and not sl["base"].playing:
			sl["tens"].stop()
			sl["live"] = false
