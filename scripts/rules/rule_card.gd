class_name RuleCard
extends RefCounted

enum Category {
	MOVEMENT,
	CAPTURE,
	PROMOTION,
	TURN,
	BOARD,
	COMBO,
	BOSS   # leis de chefe (especiais): não entram em loja/altar
}

enum Scope {
	PLAYER_ONLY,
	AI_ONLY,
	BOTH
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MOVEMENT
@export var scope: Scope = Scope.PLAYER_ONLY
@export var rarity: Rarity = Rarity.COMMON
@export var priority: int = 10
# Preço na Loja: sai da raridade (ver get_cost_by_rarity), como nas Cartas de
# Ação. Uma Lei só foge disso se atribuir `cost` explicitamente (ex: Leis do
# chefe, que nunca são vendidas).
var _cost_override: int = -1
@export var cost: int:
	get:
		return _cost_override if _cost_override >= 0 else get_cost_by_rarity(rarity)
	set(value):
		_cost_override = value
@export var incompatible_with: Array[String] = []
# Lei exclusiva de Chefe: ganha o efeito BossLawFx (brilho, varredura e faíscas)
# na carta e destaque no tooltip.
var boss_law: bool = false

func applies_to_team(piece_team: int, human_team: int) -> bool:
	match scope:
		Scope.PLAYER_ONLY:
			return piece_team == human_team
		Scope.AI_ONLY:
			return piece_team != human_team
		Scope.BOTH:
			return true
	return false

func modify_move_directions(_piece: BoardPiece, current_dirs: Array[Vector2i], _human_team: int, _board: RefCounted) -> Array[Vector2i]:
	return current_dirs

func modify_step_distance(_piece: BoardPiece, base_distance: int, _board: RefCounted) -> int:
	return base_distance

func evaluate_mandatory_capture(_team: int, default_mandatory: bool) -> bool:
	return default_mandatory

func check_custom_promotion(_piece: BoardPiece, _to_pos: Vector2i, _board: RefCounted) -> bool:
	return false

func on_game_event(_event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	pass

# Padrão: não muda o alcance de captura. Só quem realmente mexe nisso
# (rule_blood.gd, rule_vengeful_fury.gd) precisa sobrescrever.
func modify_capture_reach(_piece: BoardPiece, base_reach: int, _board: RefCounted) -> int:
	return base_reach

# Padrão: nunca previne a captura. Só quem realmente tem esse efeito
# (rule_shield.gd) precisa sobrescrever.
func try_prevent_capture(_victim: BoardPiece, _board: RefCounted) -> bool:
	return false

# Alcance máximo (em casas) do passo simples das Damas; 0 = ilimitado.
# Só quem limita (Lei do Peso) precisa sobrescrever.
func modify_king_range(_piece: BoardPiece, base_range: int) -> int:
	return base_range

# true = a Dama pode capturar de longe mesmo sem casa livre atrás da vítima,
# pousando na casa logo ANTES dela (Lei do Peso).
func king_lands_before_victim(_piece: BoardPiece) -> bool:
	return false

# Passo extra (ex: Segundo Movimento): devolve true se a regra concede um
# passo extra agora e já o consome. Padrão: não concede.
func try_consume_extra_step() -> bool:
	return false

# Banner de "gatilho" exibido quando a regra influenciou um movimento simples
# ({"text": String, "color": Color}) ou uma promoção. Vazio = sem banner.
func get_move_trigger_banner(_piece: BoardPiece, _from_pos: Vector2i, _to_pos: Vector2i, _was_capture: bool) -> Dictionary:
	return {}

func get_promotion_trigger_banner(_to_pos: Vector2i) -> Dictionary:
	return {}

static func get_category_color(cat: int) -> Color:
	match cat:
		Category.MOVEMENT:  return Color(0.25, 0.60, 1.0)
		Category.CAPTURE:   return Color(0.95, 0.25, 0.25)
		Category.PROMOTION: return Color(1.00, 0.82, 0.20)
		Category.TURN:      return Color(0.70, 0.35, 0.95)
		Category.BOARD:     return Color(0.25, 0.85, 0.45)
		Category.BOSS:      return Color(0.90, 0.20, 0.55)
		_:                  return Color(1.00, 0.55, 0.15)

static func get_category_name(cat: int) -> String:
	match cat:
		Category.MOVEMENT:  return "MOVIMENTO"
		Category.CAPTURE:   return "CAPTURA"
		Category.PROMOTION: return "PROMOÇÃO"
		Category.TURN:      return "TURNO"
		Category.BOARD:     return "TABULEIRO"
		Category.BOSS:      return "CHEFE"
		_:                  return "COMBO"

static func get_category_slug(cat: int) -> String:
	match cat:
		Category.MOVEMENT:  return "blue"
		Category.CAPTURE:   return "red"
		Category.PROMOTION: return "yellow"
		Category.TURN:      return "purple"
		Category.BOARD:     return "green"
		Category.BOSS:      return "boss"
		_:                  return "orange"

# Leis valem mais que Cartas da mesma raridade: ficam ativas na run inteira.
static func get_cost_by_rarity(r: Rarity) -> int:
	match r:
		Rarity.COMMON:    return 25
		Rarity.RARE:      return 32
		Rarity.EPIC:      return 40
		Rarity.LEGENDARY: return 50
	return 25

static func get_rarity_weight(r: Rarity) -> int:
	match r:
		Rarity.COMMON:    return 60
		Rarity.RARE:      return 28
		Rarity.EPIC:      return 10
		Rarity.LEGENDARY: return 2
	return 50

static func get_rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON:    return "COMUM"
		Rarity.RARE:      return "RARA"
		Rarity.EPIC:      return "ÉPICA"
		Rarity.LEGENDARY: return "LENDÁRIA"
	return "COMUM"
