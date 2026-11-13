class_name CardCounterstrike
extends ActionCard

# Contragolpe: suas peças ganham espinhos durante os próximos 2 turnos do
# adversário. Quem capturar uma delas é destruído no pouso (a captura acontece,
# mas o atacante morre e a sequência de saltos termina). Ver Board.counterstrike_turns.
const DURATION_TURNS: int = 2

func _init() -> void:
	id = "counterstrike"
	icon_path = "res://assets/sprites/cards/icons/counterstrike.png"
	name = "Contragolpe"
	description = "Nos próximos 2 turnos do inimigo, toda peça que capturar uma peça sua é destruída ao pousar."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.NONE

func can_play(board: Board, team: int, _context: Dictionary = {}) -> bool:
	return board.counterstrike_turns.get(team, 0) <= 0

func execute(board: Board, _target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	board.counterstrike_turns[team] = DURATION_TURNS
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("lei")
		var k: int = 0
		for r in range(board.rows):
			for c in range(board.cols):
				var p: BoardPiece = board.grid[r][c]
				if p != Board.EMPTY and not p.is_tree and p.owner_team == team:
					var pos := Vector2i(c, r)
					Juice.ring(main, CardFx.center_of(main, pos), main.cell_size * 0.6, Color(1.0, 0.4, 0.45), 4.0, 0.35 + 0.02 * k)
					k += 1
	_pop_banner(context, "CONTRAGOLPE ARMADO!", Color(1.0, 0.45, 0.5))
