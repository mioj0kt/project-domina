class_name PieceSkin
extends RefCounted

## Cores das peças. O jogador escolhe a SUA cor (e a estrela da sua Dama) em
## "MINHA PEÇA", no menu inicial; a lógica do jogo continua com os times Board.WHITE (quem
## começa) e Board.BLACK, e esta classe só decide com que cor cada time é
## DESENHADO: o time do jogador usa a cor dele, o outro usa a do adversário.
## Fora dos duelos, Board.WHITE é sempre o jogador.

const SKINS: Array = [
	{"name": "BRANCA", "col": Color8(230, 221, 196)},
	{"name": "PRETA", "col": Color8(46, 34, 44)},
	{"name": "VERMELHA", "col": Color8(198, 66, 68)},
	{"name": "LARANJA", "col": Color8(226, 132, 58)},
	{"name": "AMARELA", "col": Color8(234, 198, 84)},
	{"name": "VERDE", "col": Color8(98, 162, 90)},
	{"name": "CIANO", "col": Color8(88, 184, 186)},
	{"name": "AZUL", "col": Color8(76, 116, 198)},
	{"name": "ROXA", "col": Color8(134, 94, 184)},
	{"name": "ROSA", "col": Color8(228, 136, 174)},
	{"name": "MARROM", "col": Color8(146, 102, 70)},
	{"name": "CINZA", "col": Color8(142, 138, 154)},
]

# Adversários temáticos de cada bioma: [cor da peça, cor da estrela] (índices
# de SKINS e STARS). A maioria dos duelos continua com as clássicas preta e
# branca; ver roll_enemy().
const BIOME_ENEMIES: Dictionary = {
	"floresta": [[5, 0], [10, 4], [2, 2]],    # verde/dourada, marrom/verde, vermelha/prata (cogumelo)
	"deserto": [[4, 1], [3, 7], [10, 0]],     # amarela/vermelha, laranja/preta, marrom/dourada
	"mina": [[8, 3], [6, 5], [11, 4]],        # roxa/azul, ciano/roxa, cinza/verde (cristais)
}
const CLASSIC_BLACK_CHANCE: float = 0.38
const CLASSIC_WHITE_CHANCE: float = 0.30

# Cores da estrela da Dama.
const STARS: Array = [
	{"name": "DOURADA", "col": Color8(226, 172, 62)},
	{"name": "VERMELHA", "col": Color8(196, 62, 64)},
	{"name": "PRATA", "col": Color8(198, 204, 216)},
	{"name": "AZUL", "col": Color8(92, 156, 232)},
	{"name": "VERDE", "col": Color8(112, 200, 112)},
	{"name": "ROXA", "col": Color8(172, 112, 222)},
	{"name": "ROSA", "col": Color8(240, 142, 190)},
	{"name": "PRETA", "col": Color8(52, 40, 52)},
]
# Os quatro tons da estrela dourada original (base, contorno, brilho, sombra).
const STAR_SRC: Array = [Color8(226, 172, 62), Color8(112, 68, 20), Color8(250, 230, 160), Color8(150, 96, 28)]

const P_WHITE: String = "res://assets/sprites/pieces/white.png"
const P_BLACK: String = "res://assets/sprites/pieces/black.png"
const P_WHITE_KING: String = "res://assets/sprites/pieces/white-king.png"
const P_BLACK_KING: String = "res://assets/sprites/pieces/black-king.png"

# Os quatro tons da peça branca original (base, brilho, sombra, contorno).
const RAMP_SRC: Array = [Color8(230, 221, 196), Color8(244, 238, 221), Color8(194, 181, 147), Color8(158, 144, 112)]

static var player_idx: int = 0
static var enemy_idx: int = 1
static var player_star: int = 0
static var enemy_star: int = 1
# Time (Board.WHITE/BLACK) do jogador no duelo atual. Antes do sorteio e fora
# dos duelos vale Board.WHITE.
static var human_team: int = Board.WHITE
# Sobe a cada troca de cor: quem guarda texturas compostas usa para invalidar.
static var version: int = 0
static var _cache: Dictionary = {}

## Cor das peças do jogador. A do adversário não é escolha dele: é a preta
## de sempre (estrela vermelha), ou a branca (estrela dourada) se o jogador
## ficar com a preta.
static func set_player(i: int) -> void:
	player_idx = clampi(i, 0, SKINS.size() - 1)
	reset_enemy()

## Adversário padrão (fora dos duelos e no tutorial): preta, ou branca se a preta é do jogador.
static func reset_enemy() -> void:
	enemy_idx = 0 if player_idx == 1 else 1
	enemy_star = 0 if enemy_idx == 0 else 1
	version += 1

## Sorteia o visual do adversário de um duelo. Pretas e brancas são as mais
## comuns; o resto das vezes sai uma combinação do bioma. Nunca repete a cor
## do jogador.
static func roll_enemy(biome: String) -> void:
	var opts: Array = []     # [peso, cor, estrela]
	if player_idx != 1:
		opts.append([CLASSIC_BLACK_CHANCE, 1, 1])
	if player_idx != 0:
		opts.append([CLASSIC_WHITE_CHANCE, 0, 0])
	if opts.size() == 1:
		opts[0][0] = CLASSIC_BLACK_CHANCE + CLASSIC_WHITE_CHANCE   # a outra clássica é a do jogador
	var themed: Array = []
	for c in BIOME_ENEMIES.get(biome, []):
		if int(c[0]) != player_idx:
			themed.append(c)
	var rest: float = 1.0 - CLASSIC_BLACK_CHANCE - CLASSIC_WHITE_CHANCE
	for c in themed:
		opts.append([rest / float(themed.size()), int(c[0]), int(c[1])])
	if opts.is_empty():
		reset_enemy()
		return
	var total: float = 0.0
	for o in opts:
		total += float(o[0])
	var r: float = randf() * total
	for o in opts:
		r -= float(o[0])
		if r <= 0.0:
			enemy_idx = int(o[1])
			enemy_star = int(o[2])
			break
	version += 1

## Cor da estrela da Dama do jogador.
static func set_star(i: int) -> void:
	player_star = clampi(i, 0, STARS.size() - 1)
	version += 1

static func skin_of_team(team: int) -> int:
	return player_idx if team == human_team else enemy_idx

static func color_of(idx: int) -> Color:
	return SKINS[idx]["col"]

static func team_color(team: int) -> Color:
	return color_of(skin_of_team(team))

static func name_of(idx: int) -> String:
	return SKINS[idx]["name"]

## Nome da cor do time branco (true) ou preto (false) da lógica, como aparece na tela.
static func word(is_white: bool) -> String:
	return name_of(skin_of_team(Board.WHITE if is_white else Board.BLACK))

static func team_texture(team: int, king: bool) -> Texture2D:
	return texture(skin_of_team(team), king)

static func player_texture(king: bool = false) -> Texture2D:
	return texture(player_idx, king)

static func enemy_texture(king: bool = false) -> Texture2D:
	return texture(enemy_idx, king)

## Para quem ainda trabalha com o caminho do sprite: os quatro sprites padrão
## viram a cor do time correspondente; qualquer outro caminho é carregado direto.
static func resolve(path: String) -> Texture2D:
	match path:
		P_WHITE: return team_texture(Board.WHITE, false)
		P_WHITE_KING: return team_texture(Board.WHITE, true)
		P_BLACK: return team_texture(Board.BLACK, false)
		P_BLACK_KING: return team_texture(Board.BLACK, true)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func texture(idx: int, king: bool) -> Texture2D:
	return king_texture(idx, player_star if idx == player_idx else enemy_star) if king else _make(idx, -1)

## Dama da cor `idx` com a estrela `star` (usado também nas amostras das Configurações).
static func king_texture(idx: int, star: int) -> Texture2D:
	return _make(idx, star)

static func _body_ramp(idx: int) -> Array:
	if idx == 0:
		return RAMP_SRC
	if idx == 1:   # a peça preta original
		return [Color8(46, 34, 44), Color8(74, 58, 70), Color8(26, 18, 26), Color8(20, 14, 20)]
	var base: Color = color_of(idx)
	return [base, base.lightened(0.38), base.darkened(0.24), base.darkened(0.46)]

static func _star_ramp(star: int) -> Array:
	if star == 0:
		return STAR_SRC
	if star == 1:   # a estrela vermelha da Dama preta original
		return [Color8(196, 62, 64), Color8(70, 12, 20), Color8(240, 128, 116), Color8(120, 28, 36)]
	var base: Color = STARS[star]["col"]
	return [base, base.darkened(0.62), base.lightened(0.5), base.darkened(0.34)]

# Tudo nasce da peça branca (comum ou Dama): troca os quatro tons do corpo
# pela rampa da cor e, na Dama, os quatro tons da estrela pela rampa da estrela.
static func _make(idx: int, star: int) -> Texture2D:
	var key: int = idx * 100 + star + 1
	if _cache.has(key):
		return _cache[key]
	var src: Texture2D = load(P_WHITE_KING if star >= 0 else P_WHITE)
	var tex: Texture2D = src
	if src != null and (idx != 0 or star > 0):
		var img: Image = src.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var from: Array = RAMP_SRC + STAR_SRC
		var to: Array = _body_ramp(idx) + (_star_ramp(star) if star >= 0 else STAR_SRC)
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c: Color = img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				for k in range(from.size()):
					var s: Color = from[k]
					if absf(c.r - s.r) + absf(c.g - s.g) + absf(c.b - s.b) < 0.02:
						var n: Color = to[k]
						n.a = c.a
						img.set_pixel(x, y, n)
						break
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
