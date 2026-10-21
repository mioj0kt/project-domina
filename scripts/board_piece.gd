class_name BoardPiece
extends RefCounted

const TEXTURE_WHITE_PATH: String = "res://assets/sprites/pieces/white.png"
const TEXTURE_BLACK_PATH: String = "res://assets/sprites/pieces/black.png"
const TEXTURE_WHITE_KING_PATH: String = "res://assets/sprites/pieces/white-king.png"
const TEXTURE_BLACK_KING_PATH: String = "res://assets/sprites/pieces/black-king.png"
const TEXTURE_MUMMY_PATH: String = "res://assets/sprites/pieces/mumia.png"
const TEXTURE_MUMMY_KING_PATH: String = "res://assets/sprites/pieces/mumia-king.png"

var owner_team: int = Board.WHITE
var is_king: bool = false
var color_override: Color = Color.TRANSPARENT
# Árvore da floresta (chefe): peça neutra (owner_team = Board.NEUTRAL) que não
# anda, bloqueia a casa e pode ser capturada por qualquer lado (opcionalmente).
var is_tree: bool = false
# Sarcófago do Deserto (chefe): é uma "árvore" (neutro, bloqueia, derrubável
# pulando por cima) que, ao ser derrubada, libera uma múmia do chefe.
var is_sarcophagus: bool = false
# Cacto do Deserto (chefe): também é uma "árvore" neutra; quem o derruba pulando
# por cima se espeta e perde a próxima jogada.
var is_cactus: bool = false
# Múmia (Sarcófagos): peça comum do chefe com sprite próprio.
var is_mummy: bool = false
# Emboscada: turnos (do dono da peça) em que ela NÃO pode se mover/capturar.
var rooted_turns: int = 0
# Herdeiro: turnos (do dono) restantes como Dama temporária; 0 = Dama normal ou comum.
var temp_king_turns: int = 0
# Lei do Luto: turnos (do dono) com escudo — a próxima captura contra a peça falha.
var shield_turns: int = 0
# Lei da Guarda Real: Dama inicial que NÃO conta para ativar a Morte Súbita.
var sd_exempt: bool = false

static func make_tree() -> BoardPiece:
	var t = BoardPiece.new(Board.NEUTRAL, false)
	t.is_tree = true
	return t

static func make_sarcophagus() -> BoardPiece:
	var t = BoardPiece.new(Board.NEUTRAL, false)
	t.is_tree = true
	t.is_sarcophagus = true
	return t

static func make_cactus() -> BoardPiece:
	var t = BoardPiece.new(Board.NEUTRAL, false)
	t.is_tree = true
	t.is_cactus = true
	return t

func _init(p_owner: int = Board.WHITE, p_is_king: bool = false) -> void:
	owner_team = p_owner
	is_king = p_is_king

func get_texture() -> String:
	if is_mummy:
		return TEXTURE_MUMMY_KING_PATH if is_king else TEXTURE_MUMMY_PATH
	if owner_team == Board.WHITE:
		return TEXTURE_WHITE_KING_PATH if is_king else TEXTURE_WHITE_PATH
	elif owner_team == Board.BLACK:
		return TEXTURE_BLACK_KING_PATH if is_king else TEXTURE_BLACK_PATH
	return ""

func clone() -> BoardPiece:
	var copy = BoardPiece.new(owner_team, is_king)
	copy.color_override = color_override
	copy.is_tree = is_tree
	copy.is_sarcophagus = is_sarcophagus
	copy.is_cactus = is_cactus
	copy.is_mummy = is_mummy
	copy.rooted_turns = rooted_turns
	copy.temp_king_turns = temp_king_turns
	copy.shield_turns = shield_turns
	copy.sd_exempt = sd_exempt
	return copy
