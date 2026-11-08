class_name Sfx
extends Node
# Efeitos sonoros do jogo. Cada "grupo" tem várias variações; a cada toque
# sorteia uma diferente da última (e varia um pouco o tom) para não cansar.
# NÃO precisa registrar em Autoload: a primeira chamada cria o nó sozinha.
# Uso: Sfx.play("mover"), Sfx.play("captura"), Sfx.play("carta").

const BUS := "SFX"
const DIR := "res://assets/audio/sfx/"
const GROUPS := {
	# Duelo
	"mover": {"count": 6, "db": -17.0, "pitch": 0.06},
	"captura": {"count": 5, "db": -2.0, "pitch": 0.05},
	"carta": {"count": 4, "db": -8.0, "pitch": 0.05},          # comprar carta
	"carta_pegar": {"count": 2, "db": -12.0, "pitch": 0.04},   # selecionar/arrastar carta
	"carta_jogar": {"count": 3, "db": -7.0, "pitch": 0.04},    # carta jogada (jogador e IA)
	"coroar": {"count": 1, "db": -6.0, "pitch": 0.0},
	"moeda_girar": {"count": 2, "db": -12.0, "pitch": 0.0},    # moeda sendo lançada (1,4 s, um tic por virada)
	"moeda_girar_longa": {"count": 1, "db": -12.0, "pitch": 0.0},  # moeda do Guia/Irmão (1,9 s)
	"irmao_pressentimento": {"count": 1, "db": -8.0, "pitch": 0.0},
	"irmao_impacto": {"count": 1, "db": -4.0, "pitch": 0.0},
	"boss_intro_floresta": {"count": 1, "db": -6.0, "pitch": 0.0},
	"boss_intro_deserto": {"count": 1, "db": -6.0, "pitch": 0.0},
	"boss_encolhe": {"count": 1, "db": -9.0, "pitch": 0.0},
	"acerto": {"count": 1, "db": -8.0, "pitch": 0.0},          # moeda favorável
	"erro": {"count": 1, "db": -8.0, "pitch": 0.0},            # moeda desfavorável
	"lei": {"count": 2, "db": -9.0, "pitch": 0.03},            # Lei disparou
	"bloqueio": {"count": 2, "db": -7.0, "pitch": 0.03},       # captura bloqueada
	"morte_subita": {"count": 1, "db": -4.0, "pitch": 0.0},
	"vitoria": {"count": 1, "db": -5.0, "pitch": 0.0},
	"derrota": {"count": 1, "db": -5.0, "pitch": 0.0},
	"nascer": {"count": 3, "db": -8.0, "pitch": 0.05},          # peça gerada/renascida
	"brotar": {"count": 2, "db": -8.0, "pitch": 0.04},         # árvore/cacto/sarcófago surgindo
	# Mapa / loja / eventos / transições
	"salto": {"count": 3, "db": -8.0, "pitch": 0.04},          # peão pulando no mapa
	"carta_virar": {"count": 2, "db": -10.0, "pitch": 0.05},   # carta/lei virando
	"item": {"count": 2, "db": -7.0, "pitch": 0.03},           # carta/lei ganha ou comprada
	"transicao_in": {"count": 1, "db": -28.0, "pitch": 0.0},    # tela fechando
	"transicao_out": {"count": 1, "db": -28.0, "pitch": 0.0},   # tela abrindo
	# Sons novos, só do cassino (Mesa de Apostas e Roleta)
	"cassino_girar": {"count": 2, "db": -12.0, "pitch": 0.0},
	"cassino_pousa": {"count": 2, "db": -10.0, "pitch": 0.03},
	"cassino_acerto": {"count": 1, "db": -11.0, "pitch": 0.0},
	"cassino_erro": {"count": 1, "db": -8.0, "pitch": 0.0},
	"roleta_giro": {"count": 1, "db": -8.0, "pitch": 0.0},
	"roleta_tick": {"count": 2, "db": -12.0, "pitch": 0.04},
	"roleta_fim": {"count": 1, "db": -9.0, "pitch": 0.0},
	# Vozes dos NPCs (um "blip" por letra, estilo Undertale) e contador de moedas
	"voz_guia": {"count": 3, "db": -14.0, "pitch": 0.12},
	"voz_irmao": {"count": 3, "db": -13.0, "pitch": 0.12},
	"voz_musgo": {"count": 3, "db": -13.0, "pitch": 0.14},
	"voz_farao": {"count": 3, "db": -13.0, "pitch": 0.12},
	"moeda_pousa": {"count": 2, "db": -10.0, "pitch": 0.03},   # moeda caindo na mesa e parando
	"coroa_conta": {"count": 1, "db": -10.0, "pitch": 0.0},    # contador de Coroas (fim de run)
	"coroa_final": {"count": 1, "db": -8.0, "pitch": 0.0},
	"moeda_conta": {"count": 1, "db": -10.0, "pitch": 0.0},
	# Máquina do Grimório
	"maquina_carga": {"count": 1, "db": -7.0, "pitch": 0.0},
	"maquina_revela": {"count": 4, "db": -8.0, "pitch": 0.0},   # "tun" do desbloqueio, um por raridade
	"maquina_vortex": {"count": 1, "db": -6.0, "pitch": 0.0},
	"maquina_crack": {"count": 1, "db": -7.0, "pitch": 0.02},
	"maquina_boom": {"count": 4, "db": -4.0, "pitch": 0.0},    # uma variação por raridade
	"contagem": {"count": 1, "db": -10.0, "pitch": 0.0},       # contagem de peças (Morte Súbita)
	"contagem_dama": {"count": 1, "db": -7.0, "pitch": 0.0},
	"placar": {"count": 1, "db": -8.0, "pitch": 0.0},          # fim da contagem
	# Interface / economia
	"clique": {"count": 3, "db": -12.0, "pitch": 0.04},
	"hover": {"count": 2, "db": -20.0, "pitch": 0.03},
	"moeda": {"count": 3, "db": -8.0, "pitch": 0.05},          # ganhou ouro
	"compra": {"count": 2, "db": -8.0, "pitch": 0.03},         # comprou algo
	"negado": {"count": 2, "db": -10.0, "pitch": 0.02},        # ação recusada
}
# Intervalo mínimo (s) entre dois toques do mesmo grupo, p/ não empilhar.
const MIN_GAP := {"coroa_conta": 0.025, "voz_guia": 0.045, "voz_irmao": 0.045, "voz_musgo": 0.05, "voz_farao": 0.05, "moeda_conta": 0.025, "item": 0.15, "carta_virar": 0.04, "roleta_tick": 0.03, "salto": 0.05, "hover": 0.05, "clique": 0.05, "moeda": 0.06, "moeda_girar": 0.5, "cassino_girar": 0.5}
const POOL_SIZE := 14

var _streams: Dictionary = {}
var _last: Dictionary = {}
var _last_time: Dictionary = {}
var _player_group: Dictionary = {}   # player -> grupo que ele está tocando
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	for g in GROUPS:
		var list: Array[AudioStream] = []
		for i in range(int(GROUPS[g]["count"])):
			var path := "%s%s_%d.wav" % [DIR, g, i + 1]
			if ResourceLoader.exists(path):
				list.append(load(path))
			else:
				push_warning("Sfx: som não importado/ausente: " + path)
		_streams[g] = list

static var _inst: Sfx = null

# Cria os canais "SFX" e "Music" (saem no Master) se ainda não existirem.
static func ensure_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

# Volume linear (0..1) -> dB; 0 silencia o canal.
static func set_bus_volume(bus_name: String, linear: float) -> void:
	ensure_buses()
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))

# Chamado uma vez pelo menu de configurações (autoload): liga o clique e o
# hover sonoros em TODO botão que entrar na árvore, sem mexer nas cenas.
static func boot() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	if _inst == null or not is_instance_valid(_inst):
		_inst = Sfx.new()
		(loop as SceneTree).root.add_child.call_deferred(_inst)
		(loop as SceneTree).node_added.connect(_inst._on_node_added)

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func(): Sfx.play("clique"))
		b.mouse_entered.connect(func():
			if not b.disabled:
				Sfx.play("hover"))

static func play(group: String, extra_db: float = 0.0, pitch_mul: float = 1.0) -> void:
	if _inst == null or not is_instance_valid(_inst):
		var loop := Engine.get_main_loop()
		if not (loop is SceneTree):
			return
		_inst = Sfx.new()
		(loop as SceneTree).root.add_child(_inst)
	_inst._play(group, extra_db, pitch_mul)

# Corta na hora os sons de um grupo que ainda estão tocando (ex.: pular a animação).
static func stop(group: String) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	for p in _inst._players:
		if p.playing and _inst._player_group.get(p, "") == group:
			p.stop()

# Toca uma variação ESPECÍFICA do grupo (ex.: o som certo para cada raridade).
static func play_variant(group: String, idx: int, extra_db: float = 0.0, pitch_mul: float = 1.0) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	_inst._play(group, extra_db, pitch_mul, idx)

func _play(group: String, extra_db: float, pitch_mul: float = 1.0, forced_idx: int = -1) -> void:
	var list: Array = _streams.get(group, [])
	if list.is_empty() or not GROUPS.has(group):
		return
	var i := randi() % list.size()
	if list.size() > 1 and i == _last.get(group, -1):
		i = (i + 1 + randi() % (list.size() - 1)) % list.size()
	if forced_idx >= 0:
		i = mini(forced_idx, list.size() - 1)
	_last[group] = i
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_time.get(group, -9.0)) < float(MIN_GAP.get(group, 0.0)):
		return
	_last_time[group] = now
	var cfg: Dictionary = GROUPS[group]
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
	player.stream = list[i]
	_player_group[player] = group
	player.volume_db = float(cfg["db"]) + extra_db
	player.pitch_scale = pitch_mul * (1.0 + randf_range(-float(cfg["pitch"]), float(cfg["pitch"])))
	player.play()
