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
# O tooltip só abre depois do mouse parar um instante numa casa (passar o
# mouse por cima do tabuleiro não fica piscando tooltip).
const HOVER_DELAY: float = 0.35
var _rest: float = 0.0
var _shown_tile: Vector2i = Vector2i(-999, -999)
# Gelo Fino intacto cobre o miolo inteiro do tabuleiro: a explicação dele só
# aparece UMA vez por duelo. Depois só as casas trincadas mostram tooltip.
var _thin_ice_explained: bool = false
var _showing_thin_ice: bool = false

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
		_shown_tile = Vector2i(-999, -999)
		tooltip.hide_tooltip()
		return

	var tile = Vector2i(col, row)
	if tile != _last_tile:
		_last_tile = tile
		_rest = 0.0
		_shown_tile = Vector2i(-999, -999)
		tooltip.hide_tooltip()
		return
	if _shown_tile == tile:
		return
	_rest += _delta
	if _rest < HOVER_DELAY:
		return
	_shown_tile = tile

	_showing_thin_ice = false
	var effects = _get_tile_effects(board, row, col)
	if effects.is_empty():
		tooltip.hide_tooltip()
	else:
		tooltip.show_effects(effects, mouse_pos, host.human_team, host.ai_team)
		if _showing_thin_ice:
			_thin_ice_explained = true

func _get_tile_effects(board: Board, row: int, col: int) -> Array:
	var pos = Vector2i(col, row)
	var effects: Array = []

	if board.crystal_tiles.has(pos) and board.scorched_tiles.has(pos):
		var cturns: int = board.scorched_tiles[pos]
		effects.append({
			"title": "CRISTAL ESPELHO",
			"desc": "Ninguém para nesta casa%s. Uma captura que pousaria aqui ricocheteia para a diagonal espelhada." % ("" if cturns > 500 else " por %d turno(s)" % cturns),
			"affects": "both",
			"title_color": Color(0.75, 0.65, 1.0)
		})
	elif board.scorched_tiles.has(pos) and board.water_tiles.has(pos):
		effects.append({
			"title": "GELO AFUNDADO",
			"desc": "O gelo cedeu aqui: nenhuma peça passa ou pousa até o fim do duelo.",
			"affects": "both",
			"title_color": Color(0.7, 0.9, 1.0)
		})
	elif board.scorched_tiles.has(pos) and board.snow_tiles.has(pos):
		effects.append({
			"title": "MONTE DE NEVE",
			"desc": "A avalanche deixou neve aqui: nenhuma peça passa ou pousa por %d rodada(s)." % int(board.scorched_tiles[pos]),
			"affects": "both",
			"title_color": Color(0.85, 0.95, 1.0)
		})
	elif board.scorched_tiles.has(pos) and board.sand_tiles.has(pos):
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

	# Leis do Chefe do Cume.
	if board.thin_ice and row >= 1 and row <= board.rows - 2 and not board.water_tiles.has(pos):
		if board.cracked_tiles.has(pos):
			effects.append({
				"title": "GELO TRINCADO",
				"desc": "Uma peça já saiu daqui. A PRÓXIMA peça que sair desta casa afunda o gelo e a casa fica bloqueada até o fim do duelo (%d de %d buracos)." % [board.water_tiles.size(), board.thin_ice_hole_cap()],
				"affects": "both",
				"title_color": Color(0.7, 0.9, 1.0)
			})
		elif not _thin_ice_explained:
			_showing_thin_ice = true
			effects.append({
				"title": "GELO FINO",
				"desc": "A primeira peça que sair desta casa deixa o gelo trincado; a segunda afunda a casa.",
				"affects": "both",
				"title_color": Color(0.7, 0.9, 1.0)
			})
	if board.ice_tiles.has(pos):
		effects.append({
			"title": "GELO",
			"desc": "Quem PARA aqui com um movimento simples escorrega mais uma casa na mesma direção, se ela estiver livre (nunca até a fileira de coroação). Capturas não escorregam.",
			"affects": "both",
			"title_color": Color(0.7, 0.9, 1.0)
		})
	var cp: BoardPiece = board.grid[row][col]
	if cp != Board.EMPTY and not cp.is_tree:
		if cp.frozen:
			effects.append({
				"title": "CONGELADA",
				"desc": "Não anda nem captura (mas pode ser capturada). Descongela quando uma peça aliada parar colada nela na diagonal.",
				"affects": "both",
				"title_color": Color(0.7, 0.9, 1.0)
			})
		elif cp.frost > 0:
			effects.append({
				"title": "GEADA %d/%d" % [cp.frost, DuelBossCume.FROST_LIMIT],
				"desc": "Parada e sozinha: com %d turnos do dono assim, congela. Mexa a peça ou encoste uma aliada nela." % DuelBossCume.FROST_LIMIT,
				"affects": "both",
				"title_color": Color(0.7, 0.9, 1.0)
			})
		if cp.winded and cp.rooted_turns > 0:
			effects.append({
				"title": "SEM FÔLEGO",
				"desc": "Chegou perto do cume: fica a próxima jogada parada, recuperando o ar.",
				"affects": "both",
				"title_color": Color(0.8, 0.92, 1.0)
			})
		if cp.polar_shield:
			effects.append({
				"title": "ESCUDO DA AURORA",
				"desc": "A próxima captura contra esta peça falha (quem pulou pousa, ela fica). Some no próximo turno do chefe.",
				"affects": "both",
				"title_color": Color(0.55, 1.0, 0.8)
			})
		for pair in board.rope_pairs:
			if pair.has(cp):
				effects.append({
					"title": "CORDADA",
					"desc": "Amarrada a outra peça do chefe. Se uma for capturada, a outra é puxada para a casa dela (se estiver a até %d casas). O chefe troca as duplas a cada 4 turnos dele." % Board.ROPE_REACH,
					"affects": "both",
					"title_color": Color(0.95, 0.8, 0.55)
				})
				break

	if board.fire_tiles.has(pos):
		effects.append({
			"title": "TERRA QUEIMADA",
			"desc": "Em chamas por %d turno(s) — qualquer peca que POUSE aqui e destruida." % board.fire_tiles[pos],
			"affects": "both",
			"title_color": Color(1.0, 0.5, 0.15)
		})

	if board.trap_tiles.has(pos) and int(board.trap_tiles[pos]["team"]) == board.human_team_color:
		effects.append({
			"title": "MÃO SOMBRIA",
			"desc": "Uma mão de sombra espreita por %d turno(s) — a primeira peça inimiga que pousar aqui é agarrada e perde a próxima jogada." % board.trap_tiles[pos]["turns"],
			"affects": "both",
			"title_color": Color(0.75, 0.55, 0.95)
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
	if board.hungry_roots_team == 0 and board.grid[row][col] != Board.EMPTY and board.grid[row][col].rooted_turns > 0 and not board.grid[row][col].is_tree:
		effects.append({
			"title": "PRESA",
			"desc": "Não pode se mover nem capturar por mais %d turno(s) do dono." % board.grid[row][col].rooted_turns,
			"affects": "both",
			"title_color": Color(0.7, 0.5, 0.9)
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
