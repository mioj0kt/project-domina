class_name BoardTileHoverView
extends Control

# Detecta o mouse sobre casas especiais do tabuleiro (bloqueadas por
# Fortificar, ou as 4 casas centrais quando Zona Sagrada/Casas de Poder
# estão ativas) e mostra um tooltip explicando o efeito e quem ele afeta
# (com o ícone da peça da cor certa).
#
# Usa polling em _process (em vez dos sinais de hover do Control) porque o
# tabuleiro é desenhado via _draw() em BoardRenderer, não são Controls
# individuais por casa — não há "mouse_entered" nativo por casa.

var host: Node2D
var tooltip: BoardTileTooltip
var _last_tile: Vector2i = Vector2i(-999, -999)

func setup(p_host: Node2D) -> void:
	host = p_host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip = BoardTileTooltip.new()
	add_child(tooltip)
	set_process(true)

func _process(_delta: float) -> void:
	if host == null or host.board == null:
		tooltip.hide_tooltip()
		return

	var board: Board = host.board
	var mouse_pos = get_global_mouse_position()
	var local_pos = mouse_pos - host.board_offset
	var col = int(floor(local_pos.x / host.cell_size))
	var row = int(floor(local_pos.y / host.cell_size))

	if row < 0 or row >= board.rows or col < 0 or col >= board.cols:
		_last_tile = Vector2i(-999, -999)
		tooltip.hide_tooltip()
		return

	var tile = Vector2i(col, row)
	if tile == _last_tile:
		return
	_last_tile = tile

	var effects = _get_tile_effects(board, row, col)
	if effects.is_empty():
		tooltip.hide_tooltip()
	else:
		tooltip.show_effects(effects, mouse_pos, host.human_team, host.ai_team)

func _get_tile_effects(board: Board, row: int, col: int) -> Array:
	var pos = Vector2i(col, row)
	var effects: Array = []

	if board.scorched_tiles.has(pos) and board.sand_tiles.has(pos):
		var sturns: int = board.scorched_tiles[pos]
		effects.append({
			"title": "AREIA SOTERRADA",
			"desc": "Casa coberta de areia %s — nenhuma peça pode passar ou pousar aqui." % ("para sempre" if sturns > 500 else "por %d turno(s)" % sturns),
			"affects": "both",
			"title_color": Color(0.9, 0.75, 0.45)
		})
	elif board.scorched_tiles.has(pos):
		var turns: int = board.scorched_tiles[pos]
		effects.append({
			"title": "FORTIFICAR",
			"desc": "Casa bloqueada por %d turno(s) — nenhuma peca pode passar ou pousar aqui." % turns,
			"affects": "both",
			"title_color": Color(1.0, 0.6, 0.2)
		})

	if board.fire_tiles.has(pos):
		effects.append({
			"title": "TERRA QUEIMADA",
			"desc": "Em chamas por %d turno(s) — qualquer peca que POUSE aqui e destruida." % board.fire_tiles[pos],
			"affects": "both",
			"title_color": Color(1.0, 0.5, 0.15)
		})

	if board.quicksand_tiles.has(pos):
		effects.append({
			"title": "AREIA MOVEDIÇA",
			"desc": "Quem POUSA aqui fica preso e perde a próxima jogada (peças suas e do chefe). Muda de lugar a cada 4 rodadas.",
			"affects": "both",
			"title_color": Color(0.85, 0.65, 0.35)
		})

	# Leis do Chefe da Floresta que vivem nas casas CLARAS.
	if board.vine_tiles.has(pos):
		effects.append({
			"title": "CIPÓ",
			"desc": "Peças ao lado do cipó podem atravessá-lo: andam 2 casas em linha reta até o outro lado, se a casa estiver livre. Recuar por ele só vale para quem pode andar para trás. Muda de lugar a cada 4 rodadas.",
			"affects": "both",
			"title_color": Color(0.45, 0.9, 0.4)
		})
	if board.bridge_tiles.has(pos):
		var br: Dictionary = board.bridge_tiles[pos]
		effects.append({
			"title": "PONTE %s" % ("VERTICAL" if br["vertical"] else "LATERAL"),
			"desc": "As pecas dos dois lados ao lado da ponte atravessam para o outro lado: andam 2 casas em linha reta (%s), se a casa de destino estiver livre. Some em %d rodada(s)." % ["cima/baixo" if br["vertical"] else "esquerda/direita", br["turns"]],
			"affects": "both",
			"title_color": Color(0.85, 0.63, 0.25)
		})
	if board.lit_tiles.has(pos):
		effects.append({
			"title": "CASA ACESA",
			"desc": "Acesa por %d turno(s): as pecas de quem a acendeu nas 4 casas de lado nao podem ser capturadas." % board.lit_tiles[pos]["turns"],
			"affects": "player",
			"title_color": Color(1.0, 0.9, 0.45)
		})
	if board.firefly_tiles.has(pos):
		effects.append({
			"title": "VAGA-LUME",
			"desc": "Peças ao lado desta luz (nos 4 lados) não podem ser capturadas. Ela voa 1 casa por rodada; o próximo passo aparece marcado.",
			"affects": "both",
			"title_color": Color(0.95, 1.0, 0.5)
		})
	if board.is_firefly_protected(pos) and board.grid[row][col] != Board.EMPTY and not board.grid[row][col].is_tree:
		effects.append({
			"title": "PROTEGIDA PELA LUZ",
			"desc": "Há uma luz ao lado (vaga-lume ou casa acesa): esta peça não pode ser capturada enquanto ela durar.",
			"affects": "both",
			"title_color": Color(0.95, 1.0, 0.5)
		})
	if board.hungry_roots_team != 0 and board.grid[row][col] != Board.EMPTY and board.grid[row][col].rooted_turns > 0:
		effects.append({
			"title": "ENRAIZADA",
			"desc": "Presa pelas Raízes Famintas: não pode se mover por mais %d turno(s)." % board.grid[row][col].rooted_turns,
			"affects": "player",
			"title_color": Color(0.45, 0.85, 0.35)
		})

	if board.is_center_tile(row, col) and board.rule_pipeline != null:
		if board.rule_pipeline.has_rule("sacred_zone"):
			effects.append({
				"title": "ZONA SAGRADA",
				"desc": "Pecas comuns sao promovidas a Dama ao entrar aqui.",
				"affects": _get_rule_affects(board, "sacred_zone"),
				"title_color": Color(0.85, 0.55, 1.0)
			})
		if board.rule_pipeline.has_rule("power_center"):
			effects.append({
				"title": "CASAS DE PODER",
				"desc": "Pecas paradas aqui nao podem ser capturadas por pecas comuns inimigas.",
				"affects": "player",
				"title_color": Color(1.0, 0.85, 0.3)
			})

	return effects

func _get_rule_affects(board: Board, rule_id: String) -> String:
	for r in board.rule_pipeline.active_rules:
		if r.id == rule_id:
			match r.scope:
				RuleCard.Scope.PLAYER_ONLY:
					return "player"
				RuleCard.Scope.AI_ONLY:
					return "enemy"
				RuleCard.Scope.BOTH:
					return "both"
	return "both"
