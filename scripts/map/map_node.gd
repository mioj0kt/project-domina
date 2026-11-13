class_name MapNode
extends RefCounted

enum NodeType {
	Começo,
	Duelo,
	DueloForte,
	Evento,
	Loja,
	Chefe,
	Aposta,
	Altar,
	Arcano   # acervo de Cartas (escolhe 1 de 3 / 2 de 5 / 1 dupla de 3)
}

var id: Vector2i
var type: NodeType = NodeType.Duelo
var position: Vector2 = Vector2.ZERO
var parents: Array[MapNode] = []
var children: Array[MapNode] = []

# Armazena Vector2i(linhas, colunas)
var board_size: Vector2i = Vector2i(8, 8)

# Mina dos Cristais: nodo escondido por uma área coberta até a peça entrar.
var covered: bool = false
var revealed: bool = false
var cave_id: int = -1          # gruta a que o nodo pertence (vários nodos podem dividir uma)
var cave_order: int = 0        # 0 e 1 = nodos ligados pelo túnel; 2 = nodo "de carona"
var cave_edge: bool = false    # a gruta tem túnel entre os dois primeiros

# Deserto das Torres: duelo coberto por uma tempestade de areia (o duelo ganha um efeito).
var storm: bool = false
var storm_id: int = -1

# Disposição inicial das peças (ver Board.layout_cells); só duelos comuns/fortes sorteiam.
var board_layout: String = Board.LAYOUT_CLASSIC

func has_special_layout() -> bool:
	return board_layout != Board.LAYOUT_CLASSIC

func get_layout_text() -> String:
	return Board.layout_name(board_layout) if has_special_layout() else ""

func get_size_text() -> String:
	return "%dx%d" % [board_size.x, board_size.y]
