class_name AiDifficulty
extends RefCounted

# Perfil de força da IA por duelo. Devolve um Dictionary lido por CheckersAI:
#   depth     : plies do minimax (tabuleiros grandes ainda reduzem 1, ver controller)
#   tolerance : a IA sorteia entre jogadas até `tolerance` pontos piores que a melhor
#               (10 = valor de uma peça comum), deixando-a menos previsível
#   blunder   : chance por turno de ampliar essa folga (jogada "distraída")
#   cards     : se a IA joga cartas de ação neste duelo
# Floresta é o primeiro bioma: os primeiros duelos comuns são leves de propósito.
static func for_duel(node_type: int, biome: String, layer: int, tutorial: bool) -> Dictionary:
	if tutorial:
		return {"depth": 2, "tolerance": 8.0, "blunder": 0.3, "cards": false}
	match node_type:
		MapNode.NodeType.Chefe:
			return {"depth": 4, "tolerance": 0.25, "blunder": 0.0, "cards": true}
		MapNode.NodeType.DueloForte:
			if biome == "floresta":
				return {"depth": 3, "tolerance": 1.5, "blunder": 0.0, "cards": true}
			return {"depth": 4, "tolerance": 0.5, "blunder": 0.0, "cards": true}
	# Duelo comum
	if biome == "floresta":
		if layer <= 2:
			return {"depth": 2, "tolerance": 8.0, "blunder": 0.25, "cards": true}
		return {"depth": 3, "tolerance": 3.0, "blunder": 0.1, "cards": true}
	return {"depth": 4, "tolerance": 1.0, "blunder": 0.0, "cards": true}
