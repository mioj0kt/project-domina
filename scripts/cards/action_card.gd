class_name ActionCard
extends Resource

enum TargetType {
	NONE,
	ALLY_PIECE,
	ENEMY_PIECE,
	EMPTY_TILE
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String = ""
@export var name: String = ""
# Ícone da carta (um PNG por carta, 64x64). Vazio/inexistente = quadro vazio com "?".
@export_file("*.png") var icon_path: String = ""
@export_multiline var description: String = ""
@export var target_type: TargetType = TargetType.NONE

@export var rarity: Rarity = Rarity.COMMON:
	set(value):
		rarity = value
		_cost_gold = get_cost_by_rarity(value)

var _cost_gold: int = 4
@export var cost_gold: int:
	get:
		return get_cost_by_rarity(rarity)
	set(value):
		_cost_gold = value

static func get_cost_by_rarity(r: Rarity) -> int:
	match r:
		Rarity.COMMON:    return 15
		Rarity.RARE:      return 20
		Rarity.EPIC:      return 25
		Rarity.LEGENDARY: return 35
	return 4

func can_play(_board: Board, _human_team: int, _context: Dictionary = {}) -> bool:
	return true

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> bool:
	if not board.is_valid_pos(target_pos.y, target_pos.x):
		return false

	match target_type:
		TargetType.NONE:
			return true
		TargetType.ALLY_PIECE:
			var p = board.grid[target_pos.y][target_pos.x]
			return p != Board.EMPTY and p.owner_team == human_team
		TargetType.ENEMY_PIECE:
			var p = board.grid[target_pos.y][target_pos.x]
			return p != Board.EMPTY and p.owner_team != human_team and not p.is_tree
		TargetType.EMPTY_TILE:
			var is_dark_tile = (target_pos.y + target_pos.x) % 2 == 1
			var is_empty = board.grid[target_pos.y][target_pos.x] == Board.EMPTY
			var is_scorched = board.scorched_tiles.has(target_pos)
			return is_dark_tile and is_empty and not is_scorched
	return false

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> void:
	pass

# Segundo alvo (opcional). Cartas que precisam de duas escolhas (Troca de Lugar:
# qual peça inimiga; Empurrão/Marcha Forçada: para qual casa) devolvem aqui as
# opções depois do primeiro clique. Com 2+ opções o jogador escolhe uma; com 1 ela
# vai direto. A escolhida chega em execute() como context["second"].
func get_second_targets(_board: Board, _first: Vector2i, _team: int, _context: Dictionary = {}) -> Array:
	return []

# Ajuda para cartas com alvo: existe pelo menos uma casa válida no tabuleiro?
func has_any_target(board: Board, team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), team, context):
				return true
	return false

# Aviso flutuante sobre o tabuleiro (reusa o RuleBannerView do host). Sem host
# (testes/simulação) simplesmente não faz nada.
func _pop_banner(context: Dictionary, text: String, color: Color, cell: Vector2i = Vector2i(-1, -1)) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("rule_banner_view" in main_node) or main_node.rule_banner_view == null:
		return
	var at: Vector2
	if cell.x >= 0:
		at = main_node.board_offset + Vector2(cell.x * main_node.cell_size + main_node.cell_size / 2.0, cell.y * main_node.cell_size + main_node.cell_size / 2.0)
	else:
		at = main_node.board_offset + Vector2(main_node.board.cols * main_node.cell_size / 2.0, main_node.board.rows * main_node.cell_size / 2.0)
	main_node.rule_banner_view.pop_rule_trigger(at, text, color)

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
