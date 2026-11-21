class_name ForestBackground
extends Node2D

# Fundo procedural do mapa da floresta: um tabuleiro de casas (alternando
# claras = terra/grama e escuras = terra escura/musgo) com moldura de madeira,
# árvores e detalhes espalhados (mais árvores nas bordas, nada em cima das
# trilhas) e uma clareira sob cada nó. Tudo é gerado a partir dos sprites de
# res://assets/sprites/biomas/floresta/ com uma semente derivada do próprio mapa,
# então o mesmo mapa sempre gera o mesmo fundo.

const DIR := "res://assets/sprites/biomas/floresta/"
const BOARD_DIR := "tabuleiro/"
const NATIVE_TILE: int = 26
const FRAME: int = 10
const FRAME_CORNER: int = 12
const FRAME_SRC_COLS: int = 9
const FRAME_SRC_ROWS: int = 13

# Arte do tabuleiro da floresta (cream/ameixa): casas + detalhes pequenos em
# res://assets/sprites/biomas/floresta/tabuleiro/<pasta>/<nome>.png
const LIGHT_TILES: Array[String] = [
	"casas/casa_clara_00_lisa", "casas/casa_clara_00_lisa", "casas/casa_clara_01_tufos",
	"casas/casa_clara_02_falhas", "casas/casa_clara_03_pedrinha", "casas/casa_clara_04_folha_seca",
	"casas/casa_clara_05_terra_batida", "casas/casa_clara_06_trevos", "casas/casa_clara_07_pedrinhas",
	"casas/casa_clara_08_folhas", "casas/casa_clara_09_terra_rachada", "casas/casa_clara_10_agulhas",
	"casas/casa_clara_11_trilha",
]
const DARK_TILES: Array[String] = [
	"casas/casa_escura_00_lisa", "casas/casa_escura_00_lisa", "casas/casa_escura_01_pedrinhas",
	"casas/casa_escura_02_raizes", "casas/casa_escura_03_musgo", "casas/casa_escura_04_folhas",
	"casas/casa_escura_05_revolvida", "casas/casa_escura_06_rachaduras",
]

# Árvores e arbustos (pixel art sem chão: servem em casa clara e escura).
const TREES: Array[String] = [
	"arvores/arvore_copa_1", "arvores/arvore_copa_2", "arvores/arvore_copa_3", "arvores/arvore_copa_4",
	"arvores/arvore_copa_5", "arvores/arvore_copa_6", "arvores/arvore_copa_7", "arvores/arvore_copa_8",
	"arvores/arvore_copa_9", "arvores/arvore_copa_10", "arvores/arvore_copa_11", "arvores/arvore_copa_12",
	"arvores/arvore_copa_13", "arvores/arvore_copa_14",
]
const TREES_LIGHT: Array[String] = TREES
const TREES_DARK: Array[String] = TREES
const BUSHES: Array[String] = [
	"arvores/arbusto_1", "arvores/arbusto_2", "arvores/arbusto_3", "arvores/arbusto_4", "arvores/arbusto_5",
	"arvores/arbusto_6", "arvores/arbusto_7", "arvores/arbusto_8", "arvores/arbusto_9",
]
const BUSHES_LIGHT: Array[String] = BUSHES
const BUSHES_DARK: Array[String] = BUSHES

# As árvores são grandes (copa de ~2 casas de largura): a base do tronco fica
# a TREE_GROUND_Y da altura da arte, e é ela que se ancora na casa sorteada.
const TREE_GROUND_Y: float = 0.97
const TREE_MIN_SPACING: float = 1.2   # em casas, entre troncos
const TREE_PATH_CLEAR: float = 0.6   # copa a pelo menos isto (em casas) das trilhas
const TREE_NODE_CLEAR: float = 0.85   # copa a pelo menos isto (em casas) dos nós

# Mato: sorteado à parte (e várias vezes por casa) pra casa ficar bem verde.
const GRASS_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/samambaia_clara", "vegetacao/moitinha_clara", "vegetacao/trevo",
	"vegetacao/grama_fresta", "vegetacao/flor_branca_clara",
]
const GRASS_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/samambaia", "vegetacao/moita_pequena",
	"vegetacao/flor_branca", "vegetacao/flor_vermelha",
]
const GRASS_ATTEMPTS: int = 6
const GRASS_CHANCE: float = 0.6

# Peças "grandes" (tocos, moitas, pedras): mais comuns perto da borda lateral.
# Separadas por cor da casa pra o contorno ficar tom sobre tom.
const BIG_LIGHT: Array[String] = [
	"madeira/toco_cortado_chao_claro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tora_deitada", "vegetacao/moita", "pedras/pedra_grande_2",
	"pedras/rocha", "pedras/pedra_musgo", "pedras/rochas_grupo", "pedras/pedra_media_1",
]
const BIG_DARK: Array[String] = [
	"madeira/toco_cortado_chao_escuro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tronco_caido", "vegetacao/moita_frutos", "pedras/pedra_grande_3",
	"pedras/pedra_rachada", "pedras/pedra_lisa", "pedras/pedra_media_2", "pedras/rochas_grupo",
]
const SMALL_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/flor_branca_clara", "vegetacao/samambaia_clara", "vegetacao/moitinha_clara",
	"pedras/pedrinha_clara", "pedras/seixos", "vegetacao/trevo", "folhas/folha_verde_clara", "folhas/folha_seca",
	"vegetacao/grama_fresta", "cogumelos/cogumelo", "madeira/galho_1", "madeira/no_madeira",
]
const SMALL_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/flor_branca", "vegetacao/flor_vermelha",
	"vegetacao/samambaia", "vegetacao/moita_pequena", "pedras/pedra", "pedras/pedrinha", "pedras/seixos",
	"folhas/folha_verde_1", "folhas/folha_verde_2", "folhas/folha_seca_2", "folhas/folhas_mistas",
	"cogumelos/cogumelos_duplo", "madeira/galho_2", "madeira/raiz", "madeira/rachadura",
	"madeira/toco_pequeno", "madeira/toco_em_pe",
]


# --- Deserto das Torres (res://assets/sprites/biomas/deserto/) ---------------
# Areia clara / arenito escuro. Os "grandes" do cenário são monólitos de pedra
# com hieróglifos de damas e torres de xadrez meio enterradas (no lugar das
# árvores). Moldura fina de pedra com areia acumulada nos cantos.
const DESERT_LIGHT_TILES: Array[String] = [
	"casas/casa_clara_areia", "casas/casa_clara_areia", "casas/casa_clara_ondulada",
	"casas/casa_clara_rachada", "casas/casa_clara_textura_1", "casas/casa_clara_textura_2",
	"casas/casa_clara_textura_3", "casas/casa_clara_textura_4", "casas/casa_clara_textura_5",
	"casas/casa_clara_textura_6",
]
const DESERT_DARK_TILES: Array[String] = [
	"casas/casa_escura", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4",
	"casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8",
	"casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
]
const DESERT_TREES_LIGHT: Array[String] = [
	"monolitos/monolito_1_chao_claro", "monolitos/monolito_3_chao_claro", "monolitos/monolito_6_chao_claro", "monolitos/monolito_7_chao_claro", "monolitos/monolito_9_chao_claro", "monolitos/monolito_11_chao_claro", "monolitos/monolito_13_chao_claro",
	"monolitos/monolito_1_chao_claro", "monolitos/monolito_3_chao_claro", "monolitos/monolito_6_chao_claro", "monolitos/monolito_7_chao_claro", "monolitos/monolito_9_chao_claro", "monolitos/monolito_11_chao_claro", "monolitos/monolito_13_chao_claro",
	"monolitos/monolito_1_chao_claro", "monolitos/monolito_3_chao_claro", "monolitos/monolito_6_chao_claro", "monolitos/monolito_7_chao_claro", "monolitos/monolito_9_chao_claro", "monolitos/monolito_11_chao_claro", "monolitos/monolito_13_chao_claro",
	"torres/torre_enterrada_1_chao_claro", "torres/torre_enterrada_3_chao_claro", "torres/torre_enterrada_6_chao_claro",
	"torres/torre_enterrada_1_chao_claro", "torres/torre_enterrada_3_chao_claro", "torres/torre_enterrada_6_chao_claro",
]
const DESERT_TREES_DARK: Array[String] = [
	"monolitos/monolito_2_chao_escuro", "monolitos/monolito_4_chao_escuro", "monolitos/monolito_5_chao_escuro", "monolitos/monolito_8_chao_escuro", "monolitos/monolito_10_chao_escuro", "monolitos/monolito_12_chao_escuro", "monolitos/monolito_14_chao_escuro",
	"monolitos/monolito_2_chao_escuro", "monolitos/monolito_4_chao_escuro", "monolitos/monolito_5_chao_escuro", "monolitos/monolito_8_chao_escuro", "monolitos/monolito_10_chao_escuro", "monolitos/monolito_12_chao_escuro", "monolitos/monolito_14_chao_escuro",
	"monolitos/monolito_2_chao_escuro", "monolitos/monolito_4_chao_escuro", "monolitos/monolito_5_chao_escuro", "monolitos/monolito_8_chao_escuro", "monolitos/monolito_10_chao_escuro", "monolitos/monolito_12_chao_escuro", "monolitos/monolito_14_chao_escuro",
	"torres/torre_enterrada_2_chao_escuro", "torres/torre_enterrada_4_chao_escuro", "torres/torre_enterrada_5_chao_escuro",
	"torres/torre_enterrada_2_chao_escuro", "torres/torre_enterrada_4_chao_escuro", "torres/torre_enterrada_5_chao_escuro",
]
const DESERT_BUSHES_LIGHT: Array[String] = [
	"vegetacao/arbusto_4_chao_claro", "vegetacao/arbusto_6_chao_claro",
	"vegetacao/arbusto_8_chao_claro", "vegetacao/arbusto_11_chao_claro",
]
const DESERT_BUSHES_DARK: Array[String] = [
	"vegetacao/arbusto_1_chao_escuro", "vegetacao/arbusto_2_chao_escuro",
	"vegetacao/arbusto_3_chao_escuro", "vegetacao/arbusto_5_chao_escuro",
	"vegetacao/arbusto_7_chao_escuro", "vegetacao/arbusto_9_chao_escuro",
	"vegetacao/arbusto_10_chao_escuro", "vegetacao/arbusto_12_chao_escuro",
]
const DESERT_GRASS: Array[String] = [
	"vegetacao/tufo_seco_1", "vegetacao/tufo_seco_2", "vegetacao/tufo_seco_3",
	"vegetacao/tufo_seco_alto", "vegetacao/capim_ralo", "vegetacao/grama_fresta",
	"vegetacao/ondinha_de_areia", "vegetacao/ondinha_de_areia", "vegetacao/cacto_mini",
	"vegetacao/flor_do_deserto", "vegetacao/flor_do_deserto_2",
]
const DESERT_BIG_LIGHT: Array[String] = [
	"ruinas/coluna_quebrada_chao_claro", "ruinas/laje_inclinada_chao_claro",
	"pedras/rocha", "pedras/rochas_grupo", "pedras/pedra_grande_2", "pedras/pedra_rachada",
	"pedras/rocha", "pedras/rochas_grupo",
]
const DESERT_BIG_DARK: Array[String] = [
	"ruinas/coluna_quebrada_chao_escuro", "ruinas/laje_inclinada_chao_escuro",
	"pedras/rocha", "pedras/rochas_grupo", "pedras/pedra_grande_3", "pedras/pedra_lisa",
	"pedras/rocha", "pedras/rochas_grupo",
]
const DESERT_SMALL: Array[String] = [
	"pedras/pedrinha", "pedras/pedrinha_clara", "pedras/pedra", "pedras/seixos", "pedras/pedra_media_1",
	"pedras/pedra_media_2", "folhas/folha_seca_1", "folhas/folha_seca_2", "folhas/folha_seca_clara",
	"ossos_e_restos/osso", "ossos_e_restos/caco_de_vaso", "ossos_e_restos/corda_velha",
	"ossos_e_restos/cranio_pequeno", "ossos_e_restos/escaravelho", "ossos_e_restos/peca_de_xadrez_quebrada",
	"ruinas/bloco_de_ruina", "ruinas/hieroglifo_no_chao",
	"poeira/areia_soprada_1", "poeira/areia_soprada_2", "poeira/areia_soprada_3",
]

# --- Mina dos Cristais (res://assets/sprites/biomas/mina/) ---------------------
# Calcário claro / rocha escura (o mesmo xadrez creme e ameixa dos outros
# biomas), com cristais violeta e azul-gelo no lugar das árvores, colunas de
# mina, carrinhos tombados e poeira de cristal. Moldura de pedra com vigas.
const MINE_LIGHT_TILES: Array[String] = [
	"casas/casa_clara_1", "casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3",
	"casas/casa_clara_4", "casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7",
	"casas/casa_clara_8",
]
const MINE_DARK_TILES: Array[String] = [
	"casas/casa_escura_1", "casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3",
	"casas/casa_escura_4", "casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7",
	"casas/casa_escura_8",
]
const MINE_TREES_LIGHT: Array[String] = [
	"cristais/cristal_1_violeta_alto_clara", "cristais/cristal_2_violeta_largo_clara",
	"cristais/cristal_4_gelo_alto_clara", "cristais/cristal_6_misto_clara",
	"cristais/cristal_1_violeta_alto_clara", "cristais/cristal_2_violeta_largo_clara",
	"cristais/cristal_4_gelo_alto_clara", "cristais/cristal_6_misto_clara",
	"cristais/cristal_5_esmeralda_clara",
	"colunas/coluna_1_coluna_viga_clara", "colunas/coluna_2_coluna_quebrada_clara",
	"colunas/coluna_3_portal_lanterna_clara", "colunas/coluna_4_coluna_cintada_clara",
]
const MINE_TREES_DARK: Array[String] = [
	"cristais/cristal_1_violeta_alto_escura", "cristais/cristal_2_violeta_largo_escura",
	"cristais/cristal_4_gelo_alto_escura", "cristais/cristal_6_misto_escura",
	"cristais/cristal_1_violeta_alto_escura", "cristais/cristal_2_violeta_largo_escura",
	"cristais/cristal_4_gelo_alto_escura", "cristais/cristal_6_misto_escura",
	"cristais/cristal_5_esmeralda_escura",
	"colunas/coluna_1_coluna_viga_escura", "colunas/coluna_2_coluna_quebrada_escura",
	"colunas/coluna_3_portal_lanterna_escura", "colunas/coluna_4_coluna_cintada_escura",
]
const MINE_BUSHES_LIGHT: Array[String] = ["cristais/cristal_3_gelo_pequeno_clara", "cristais/cristal_5_esmeralda_clara"]
const MINE_BUSHES_DARK: Array[String] = ["cristais/cristal_3_gelo_pequeno_escura", "cristais/cristal_5_esmeralda_escura"]
const MINE_GRASS: Array[String] = [
	"miudezas/18_cogumelo", "miudezas/19_cogumelos_duplos", "miudezas/20_liquen",
	"miudezas/20_liquen", "miudezas/10_poeira_10x6", "miudezas/11_poeira_8x5",
	"miudezas/12_poeira_6x4", "miudezas/12_poeira_6x4",
]
const MINE_BIG: Array[String] = [
	"props/prop_1_pedra_veios", "props/prop_2_carrinho_tombado", "props/prop_3_pilha_pedras",
	"props/prop_4_lasca_cristal", "props/prop_5_poste_torto", "props/prop_6_caixote_dinamite",
	"props/prop_7_carrinho_minerio", "props/prop_8_barril", "props/prop_9_pedra_veios_gelo",
	"props/prop_10_pedra_veios_esmeralda", "props/prop_11_pedra_pequena", "props/prop_12_lasca_gelo",
	"props/prop_13_lasca_esmeralda", "props/prop_14_pilha_tabuas", "props/prop_15_placa_perigo",
	"props/prop_16_balde_minerio", "props/prop_17_saco_minerio",
	"props/prop_1_pedra_veios", "props/prop_3_pilha_pedras", "props/prop_9_pedra_veios_gelo",
	"props/prop_10_pedra_veios_esmeralda", "props/prop_11_pedra_pequena",
]
const MINE_SMALL: Array[String] = [
	"miudezas/01_caco_violeta_2x2", "miudezas/02_caco_gelo_2x2", "miudezas/03_caco_esmeralda_2x2",
	"miudezas/04_caco_violeta_3x3", "miudezas/05_caco_gelo_3x3", "miudezas/06_caco_esmeralda_3x3",
	"miudezas/07_caco_violeta_4x3", "miudezas/08_caco_gelo_4x3", "miudezas/09_caco_esmeralda_4x3",
	"miudezas/13_picareta_quebrada", "miudezas/14_capacete_velho", "miudezas/15_trilho",
	"miudezas/16_corda_velha", "miudezas/17_disco_rachado",
	"miudezas/10_poeira_10x6", "miudezas/11_poeira_8x5", "miudezas/12_poeira_6x4",
]

# --- Cume Congelado (res://assets/sprites/biomas/cume/) -----------------------
# Pedra clara com neve fina / rocha escura com geada (o mesmo xadrez creme e
# ameixa), pinheiros nevados, totens de pedra, blocos de gelo e restos da
# expedição. Neve caindo e rajadas de vento animadas por código (ver _draw_snow).
const CUME_LIGHT_TILES: Array[String] = [
	# 3x cada casa normal + 4 congeladas (placa de gelo): ~1 em cada 10 casas
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4",
	"casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8",
	"casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4",
	"casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8",
	"casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4",
	"casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8",
	"casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_gelo_clara", "casas/casa_gelo_clara_rachada_1", "casas/casa_gelo_clara_rachada_2",
	"casas/casa_gelo_clara_rachada_3",
]
const CUME_DARK_TILES: Array[String] = [
	# 3x cada casa normal + 4 congeladas (placa de gelo): ~1 em cada 10 casas
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4",
	"casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8",
	"casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4",
	"casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8",
	"casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4",
	"casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8",
	"casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_gelo_escura", "casas/casa_gelo_escura_rachada_1", "casas/casa_gelo_escura_rachada_2",
	"casas/casa_gelo_escura_rachada_3",
]
const CUME_TREES_LIGHT: Array[String] = [
	"pinheiros/pinheiro_1_alto_fino_clara", "pinheiros/pinheiro_2_largo_baixo_clara",
	"pinheiros/pinheiro_3_torto_vento_clara", "pinheiros/pinheiro_4_jovem_clara",
	"pinheiros/pinheiro_5_seco_gelo_clara", "pinheiros/pinheiro_6_dupla_clara",
	"pinheiros/pinheiro_1_alto_fino_clara", "pinheiros/pinheiro_2_largo_baixo_clara",
	"pinheiros/pinheiro_3_torto_vento_clara", "pinheiros/pinheiro_6_dupla_clara",
	"totens/totem_1_alta_reta_clara", "totens/totem_2_torta_vento_clara", "totens/totem_4_bandeira_clara",
	"gelo/gelo_2_tres_pontas_clara", "gelo/gelo_3_ponta_alta_clara", "gelo/gelo_5_estalagmite_torta_clara",
	"montanhas/montanha_1_pico_alto_clara", "montanhas/montanha_2_cordilheira_clara", "montanhas/montanha_3_geleira_clara", "montanhas/montanha_4_pico_vento_clara", "montanhas/montanha_6_pico_expedicao_clara",
]
const CUME_TREES_DARK: Array[String] = [
	"pinheiros/pinheiro_1_alto_fino_escura", "pinheiros/pinheiro_2_largo_baixo_escura",
	"pinheiros/pinheiro_3_torto_vento_escura", "pinheiros/pinheiro_4_jovem_escura",
	"pinheiros/pinheiro_5_seco_gelo_escura", "pinheiros/pinheiro_6_dupla_escura",
	"pinheiros/pinheiro_1_alto_fino_escura", "pinheiros/pinheiro_2_largo_baixo_escura",
	"pinheiros/pinheiro_3_torto_vento_escura", "pinheiros/pinheiro_6_dupla_escura",
	"totens/totem_1_alta_reta_escura", "totens/totem_2_torta_vento_escura", "totens/totem_4_bandeira_escura",
	"gelo/gelo_2_tres_pontas_escura", "gelo/gelo_3_ponta_alta_escura", "gelo/gelo_5_estalagmite_torta_escura",
	"montanhas/montanha_1_pico_alto_escura", "montanhas/montanha_2_cordilheira_escura", "montanhas/montanha_3_geleira_escura", "montanhas/montanha_4_pico_vento_escura", "montanhas/montanha_6_pico_expedicao_escura",
]
const CUME_BUSHES_LIGHT: Array[String] = [
	"gelo/gelo_1_cubo_rachado_clara", "gelo/gelo_4_disco_preso_clara", "gelo/gelo_6_meio_derretido_clara",
	"totens/totem_3_caida_clara",
	"montanhas/montanha_5_monte_neve_gigante_clara", "montanhas/montanha_7_monte_cornija_clara", "montanhas/montanha_8_monte_pinheiro_soterrado_clara", "montanhas/montanha_9_monte_rastro_vento_clara", "montanhas/montanha_10_monte_duplo_pegadas_clara", "montanhas/montanha_11_monte_lascas_gelo_clara", "montanhas/montanha_12_montes_agrupados_clara",
]
const CUME_BUSHES_DARK: Array[String] = [
	"gelo/gelo_1_cubo_rachado_escura", "gelo/gelo_4_disco_preso_escura", "gelo/gelo_6_meio_derretido_escura",
	"totens/totem_3_caida_escura",
	"montanhas/montanha_5_monte_neve_gigante_escura", "montanhas/montanha_7_monte_cornija_escura", "montanhas/montanha_8_monte_pinheiro_soterrado_escura", "montanhas/montanha_9_monte_rastro_vento_escura", "montanhas/montanha_10_monte_duplo_pegadas_escura", "montanhas/montanha_11_monte_lascas_gelo_escura", "montanhas/montanha_12_montes_agrupados_escura",
]
# Montanhas grandes: arte própria em tamanho grande (tools/cume_montanhas.py), no
# mesmo tamanho de pixel do resto, nas laterais do tabuleiro, longe das trilhas.
# As montanhas pequenas da arte original continuam como enfeite comum.
const CUME_MOUNTAINS: Array[String] = [
	"montanhas/grande_1_pico_alto",
	"montanhas/grande_2_cordilheira",
	"montanhas/grande_3_geleira",
	"montanhas/grande_4_pico_vento",
	"montanhas/grande_5_pico_expedicao",
	"montanhas/grande_6_dois_picos",
]
const MOUNTAIN_SCALE_MUL: int = 1
const CUME_GRASS: Array[String] = [
	"miudezas/07_neve_soprada_10x6", "miudezas/08_neve_soprada_8x5", "miudezas/09_neve_soprada_6x4",
	"miudezas/12_montinho_neve", "miudezas/13_montinho_gelo", "miudezas/14_capim_congelado",
	"miudezas/14_capim_congelado", "miudezas/01_floco_2x2", "miudezas/02_floco_3x3",
]
const CUME_BIG: Array[String] = [
	"props/prop_01_barraca_soterrada", "props/prop_02_mochila_congelada", "props/prop_03_picareta_cravada",
	"props/prop_04_treno_quebrado", "props/prop_05_lampiao_apagado", "props/prop_06_poste_corda",
	"props/prop_07_rocha_grande_neve", "props/prop_08_duas_rochas", "props/prop_09_monte_neve",
	"props/prop_10_monte_neve_vento", "props/prop_11_pedra_veio_gelo", "props/prop_12_lasca_gelo_deitada",
	"props/prop_07_rocha_grande_neve", "props/prop_08_duas_rochas", "props/prop_09_monte_neve",
	"props/prop_10_monte_neve_vento", "props/prop_11_pedra_veio_gelo",
]
const CUME_SMALL: Array[String] = [
	"miudezas/01_floco_2x2", "miudezas/02_floco_3x3", "miudezas/03_floco_5x5",
	"miudezas/04_caco_gelo_2x2", "miudezas/05_caco_gelo_3x3", "miudezas/06_caco_gelo_4x3",
	"miudezas/10_pegadas_par", "miudezas/11_pegada", "miudezas/10_pegadas_par",
	"miudezas/15_pena_escura", "miudezas/16_corda_congelada", "miudezas/17_estaca_barraca",
	"miudezas/18_disco_rachado", "miudezas/19_faisca_aurora_3x3", "miudezas/20_faisca_aurora_2x2",
	"miudezas/07_neve_soprada_10x6", "miudezas/08_neve_soprada_8x5", "miudezas/09_neve_soprada_6x4",
]

# --- Caldeira (bioma 5) ---------------------------------------------------------
const CALDEIRA_LIGHT_TILES: Array[String] = [
	# 3x cada casa normal + 1 de crosta (enfeite raro; no duelo as especiais são das Leis)
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4", "casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8", "casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4", "casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8", "casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_clara_1", "casas/casa_clara_2", "casas/casa_clara_3", "casas/casa_clara_4", "casas/casa_clara_5", "casas/casa_clara_6", "casas/casa_clara_7", "casas/casa_clara_8", "casas/casa_clara_9", "casas/casa_clara_10", "casas/casa_clara_11", "casas/casa_clara_12",
	"casas/casa_crosta_clara",
]
const CALDEIRA_DARK_TILES: Array[String] = [
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4", "casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8", "casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4", "casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8", "casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_escura_1", "casas/casa_escura_2", "casas/casa_escura_3", "casas/casa_escura_4", "casas/casa_escura_5", "casas/casa_escura_6", "casas/casa_escura_7", "casas/casa_escura_8", "casas/casa_escura_9", "casas/casa_escura_10", "casas/casa_escura_11", "casas/casa_escura_12",
	"casas/casa_crosta_escura",
]
const CALDEIRA_TREES_LIGHT: Array[String] = [
	"basalto/basalto_1_tres_colunas_clara", "basalto/basalto_2_alta_fina_clara", "basalto/basalto_3_grupo_baixo_clara",
	"basalto/basalto_4_partida_caida_clara", "basalto/basalto_5_fresta_lava_clara", "basalto/basalto_6_cinza_topo_clara",
	"basalto/basalto_1_tres_colunas_clara", "basalto/basalto_2_alta_fina_clara", "basalto/basalto_5_fresta_lava_clara",
	"chamines/chamine_1_pequena_redonda_clara", "chamines/chamine_2_alta_rachada_clara",
	"chamines/chamine_3_dupla_clara", "chamines/chamine_4_apagada_clara",
	"forja/forja_2_forno_clara", "forja/forja_4_tanque_tempera_clara", "forja/forja_5_suporte_tenazes_clara",
	"forja_extra/forja_extra_1_bigorna_coroa_clara",
	"props2/prop_1_braseiro_clara", "props2/prop_2_estandarte_clara", "props2/prop_11_poste_coroa_clara",
	"props2/prop_1_braseiro_clara", "props2/prop_2_estandarte_clara",
]
const CALDEIRA_TREES_DARK: Array[String] = [
	"basalto/basalto_1_tres_colunas_escura", "basalto/basalto_2_alta_fina_escura", "basalto/basalto_3_grupo_baixo_escura",
	"basalto/basalto_4_partida_caida_escura", "basalto/basalto_5_fresta_lava_escura", "basalto/basalto_6_cinza_topo_escura",
	"basalto/basalto_1_tres_colunas_escura", "basalto/basalto_2_alta_fina_escura", "basalto/basalto_5_fresta_lava_escura",
	"chamines/chamine_1_pequena_redonda_escura", "chamines/chamine_2_alta_rachada_escura",
	"chamines/chamine_3_dupla_escura", "chamines/chamine_4_apagada_escura",
	"forja/forja_2_forno_escura", "forja/forja_4_tanque_tempera_escura", "forja/forja_5_suporte_tenazes_escura",
	"forja_extra/forja_extra_1_bigorna_coroa_escura",
	"props2/prop_1_braseiro_escura", "props2/prop_2_estandarte_escura", "props2/prop_11_poste_coroa_escura",
	"props2/prop_1_braseiro_escura", "props2/prop_2_estandarte_escura",
]
const CALDEIRA_BUSHES_LIGHT: Array[String] = [
	"forja/forja_1_bigorna_clara", "forja/forja_3_fole_clara", "forja/forja_6_molde_peca_clara",
	"props2/prop_5_rack_ferramentas_clara",
]
const CALDEIRA_BUSHES_DARK: Array[String] = [
	"forja/forja_1_bigorna_escura", "forja/forja_3_fole_escura", "forja/forja_6_molde_peca_escura",
	"props2/prop_5_rack_ferramentas_escura",
]
const CALDEIRA_BIG: Array[String] = [
	"props/prop_1_coroa_inacabada", "props/prop_2_coroa_almofada", "props/prop_3_coroas_rejeitadas",
	"props/prop_4_molde_coroa_partido", "props/prop_5_prateleira_coroas", "props/prop_6_balde_coroa",
	"props/prop_7_obsidiana", "props/prop_8_pedra_pomes", "props/prop_9_poca_lava",
	"props/prop_10_escorrida_lava", "props/prop_11_rocha_veio_lava", "props/prop_12_cinza_brasa",
	"props/prop_7_obsidiana", "props/prop_8_pedra_pomes", "props/prop_9_poca_lava",
	"props/prop_10_escorrida_lava", "props/prop_11_rocha_veio_lava", "props/prop_12_cinza_brasa",
	# oficina ainda quente (props2)
	"props2/prop_3_tina_tempera", "props2/prop_4_monte_carvao", "props2/prop_6_lingotes_ouro",
	"props2/prop_7_lingoteira", "props2/prop_8_mesa_ourives", "props2/prop_9_barril_vazando",
	"props2/prop_10_corrente_caida", "props2/prop_12_caixa_coroas", "props2/prop_13_fumarola_baixa",
	"props2/prop_14_roda_amolar", "props2/prop_4_monte_carvao", "props2/prop_3_tina_tempera",
	"props2/prop_13_fumarola_baixa", "props2/prop_9_barril_vazando",
]
# Marcos de 2 a 3 casas (lagos de lava prontos e a oficina da Ferreira): espalhados
# como as montanhas do Cume, mais numerosos. Nomes sem o sufixo _clara/_escura.
const CALDEIRA_LANDMARKS: Array[String] = [
	"marcos/forja_1_forno_escavado", "marcos/forja_2_oficina_engolida", "marcos/forja_3_bigorna_altar",
	"marcos/forja_4_caldeirao_fundicao", "marcos/forja_5_disco_coroado", "marcos/forja_6_moldes_empilhados",
	"marcos/forja_7_arco_fundicao", "marcos/forja_8_trilho_carvao",
	"marcos/lava_1_lago_redondo", "marcos/lava_2_lago_ponte", "marcos/lava_3_cachoeira",
	"marcos/lava_4_geiser", "marcos/lava_5_lago_coroa", "marcos/lava_6_rio_fenda",
	"marcos/lava_1_lago_redondo", "marcos/lava_3_cachoeira", "marcos/lava_4_geiser",
]
# Marcos grandes (poucos por mapa, como as montanhas grandes do Cume).
const CALDEIRA_MOUNTAINS: Array[String] = [
	"marcos/grande_1_grande_forja", "marcos/grande_2_oficina_afundando", "marcos/grande_3_trono_bigorna",
]
const CALDEIRA_SMALL: Array[String] = [
	"miudezas/01_brasa_2x2", "miudezas/02_brasa_3x3", "miudezas/03_brasa_4x3",
	"miudezas/04_brasa_apagando_2x2", "miudezas/05_brasa_apagando_3x3",
	"miudezas/12_escoria_3x2", "miudezas/13_escoria_4x3", "miudezas/14_lasca_obsidiana_5x3",
	"miudezas/15_gota_lava_esfriada_4x4", "miudezas/16_prego_torto_2x5", "miudezas/17_arruela_bronze_3x3",
	"miudezas/18_elo_corrente_4x3", "miudezas/19_pepita_ouro_3x2", "miudezas/20_respingo_ouro_5x3",
	"miudezas/21_disco_derretido_6x6",
	"miudezas/24_fagulha_3x3", "miudezas/25_fagulha_5x5", "miudezas/27_gota_ouro_2x2", "miudezas/28_gota_ouro_3x2",
	"miudezas/29_caco_molde_5x3", "miudezas/30_coroa_quebrada_6x4", "miudezas/31_carvao_2x2", "miudezas/32_carvao_3x2",
	"miudezas/33_carvao_4x3", "miudezas/34_lingotinho_5x2", "miudezas/35_rachadinha_6x3", "miudezas/36_rachadinha_8x4",
	"miudezas/37_rachadinha_10x5", "miudezas/38_poca_lava_6x4", "miudezas/39_marca_martelo_4x4",
	"miudezas/40_pena_queimada_5x2", "miudezas/41_osso_chamuscado_6x2",
	"miudezas/35_rachadinha_6x3", "miudezas/36_rachadinha_8x4", "miudezas/31_carvao_2x2",
]
const CALDEIRA_GRASS: Array[String] = [
	"miudezas/06_floco_cinza_2x2", "miudezas/07_floco_cinza_3x2", "miudezas/08_floco_cinza_4x3",
	"miudezas/09_cinza_soprada_10x6", "miudezas/10_cinza_soprada_8x5", "miudezas/11_cinza_soprada_6x4",
]

# Tudo que muda de um bioma de mapa para outro. "floresta" usa as constantes de
# cima; "deserto" as DESERT_*. `frame`: "moldura" = faixa 9x13 repetida (floresta);
# "bordas" = moldura fina em folha (deserto), ver _draw_frame_sheet.
const THEMES: Dictionary = {
	"floresta": {
		"dir": "res://assets/sprites/biomas/floresta/",
		"trail_dir": "res://assets/sprites/biomas/floresta/trilhas_grade/",
		"tiles_light": LIGHT_TILES, "tiles_dark": DARK_TILES,
		"trees_light": TREES_LIGHT, "trees_dark": TREES_DARK,
		"bushes_light": BUSHES_LIGHT, "bushes_dark": BUSHES_DARK,
		"grass_light": GRASS_LIGHT, "grass_dark": GRASS_DARK,
		"big_light": BIG_LIGHT, "big_dark": BIG_DARK,
		"small_light": SMALL_LIGHT, "small_dark": SMALL_DARK,
		"tree_ground_y": 0.97, "tree_density": 1.0, "grass_scale": 1.0,
		"frame": "moldura", "frame_pad": Vector2(10, 10),
		"clearing_node": "decoracao/clareira_nodo", "clearing_boss": "decoracao/clareira_boss",
	},
	"deserto": {
		"dir": "res://assets/sprites/biomas/deserto/",
		"trail_dir": "res://assets/sprites/biomas/deserto/tabuleiro/trilhas_grade/",
		"tiles_light": DESERT_LIGHT_TILES, "tiles_dark": DESERT_DARK_TILES,
		"trees_light": DESERT_TREES_LIGHT, "trees_dark": DESERT_TREES_DARK,
		"bushes_light": DESERT_BUSHES_LIGHT, "bushes_dark": DESERT_BUSHES_DARK,
		"grass_light": DESERT_GRASS, "grass_dark": DESERT_GRASS,
		"big_light": DESERT_BIG_LIGHT, "big_dark": DESERT_BIG_DARK,
		"small_light": DESERT_SMALL, "small_dark": DESERT_SMALL,
		"tree_ground_y": 0.82, "tree_density": 2.4, "grass_scale": 0.7,
		"frame": "bordas", "frame_pad": Vector2(8, 10),
		"clearing_node": "", "clearing_boss": "",
		"swirls": "tabuleiro/poeira/redemoinho_pequeno",
	},
	"mina": {
		"dir": "res://assets/sprites/biomas/mina/",
		"trail_dir": "res://assets/sprites/biomas/mina/tabuleiro/trilhas_grade/",
		"tiles_light": MINE_LIGHT_TILES, "tiles_dark": MINE_DARK_TILES,
		"trees_light": MINE_TREES_LIGHT, "trees_dark": MINE_TREES_DARK,
		"bushes_light": MINE_BUSHES_LIGHT, "bushes_dark": MINE_BUSHES_DARK,
		"grass_light": MINE_GRASS, "grass_dark": MINE_GRASS,
		"big_light": MINE_BIG, "big_dark": MINE_BIG,
		"small_light": MINE_SMALL, "small_dark": MINE_SMALL,
		"tree_ground_y": 0.86, "tree_density": 1.9, "grass_scale": 0.8,
		"frame": "bordas", "frame_pad": Vector2(18, 18),   # moldura toda FORA das casas (ver BoardSkin._draw_mine_frame)
		"clearing_node": "", "clearing_boss": "",
	},
	"cume": {
		"dir": "res://assets/sprites/biomas/cume/",
		"trail_dir": "res://assets/sprites/biomas/cume/tabuleiro/trilhas_grade/",
		"tiles_light": CUME_LIGHT_TILES, "tiles_dark": CUME_DARK_TILES,
		"trees_light": CUME_TREES_LIGHT, "trees_dark": CUME_TREES_DARK,
		"bushes_light": CUME_BUSHES_LIGHT, "bushes_dark": CUME_BUSHES_DARK,
		"grass_light": CUME_GRASS, "grass_dark": CUME_GRASS,
		"big_light": CUME_BIG, "big_dark": CUME_BIG,
		"small_light": CUME_SMALL, "small_dark": CUME_SMALL,
		"tree_ground_y": 0.86, "tree_density": 1.7, "grass_scale": 0.7,
		"frame": "bordas", "frame_pad": Vector2(18, 18),   # moldura toda FORA das casas (ver BoardSkin._draw_cume_frame)
		"clearing_node": "", "clearing_boss": "",
		"snow": true, "mountains": CUME_MOUNTAINS,
	},
	"caldeira": {
		"dir": "res://assets/sprites/biomas/caldeira/",
		"trail_dir": "res://assets/sprites/biomas/caldeira/tabuleiro/trilhas_grade/",
		"tiles_light": CALDEIRA_LIGHT_TILES, "tiles_dark": CALDEIRA_DARK_TILES,
		"trees_light": CALDEIRA_TREES_LIGHT, "trees_dark": CALDEIRA_TREES_DARK,
		"bushes_light": CALDEIRA_BUSHES_LIGHT, "bushes_dark": CALDEIRA_BUSHES_DARK,
		"grass_light": CALDEIRA_GRASS, "grass_dark": CALDEIRA_GRASS,
		"big_light": CALDEIRA_BIG, "big_dark": CALDEIRA_BIG,
		"small_light": CALDEIRA_SMALL, "small_dark": CALDEIRA_SMALL,
		"tree_ground_y": 0.86, "tree_density": 1.6, "grass_scale": 0.7,
		"frame": "bordas", "frame_pad": Vector2(18, 18),   # basalto FORA das casas (as escorridas de lava passam por cima da ilha)
		"clearing_node": "", "clearing_boss": "",
		"embers": true, "lava_lakes": true, "animated": true,
		"mountains": CALDEIRA_MOUNTAINS, "mountain_div": 110.0,
		"landmarks": CALDEIRA_LANDMARKS, "landmark_div": 18.0,
	},
}

# Resultado público: retângulo (coords do mundo) ocupado pela moldura.
var world_rect: Rect2 = Rect2()

var _tile: float = 78.0
var _scale: int = 3
var _tiles: Array = []      # [Texture2D, Rect2, flip_h, flip_v]
var _decor: Array = []      # [Texture2D, Vector2 centro, y_ordem]
var _clearings: Array = []  # [Texture2D, Vector2 centro]
var _board_rect: Rect2 = Rect2()
var _walk_cells: Array[Vector2] = []   # centros das casas por onde a trilha passa e a peça salta
var _frame_tex: Texture2D = null

# --- Caldeira: lagos de lava montados com as casas de lava -------------------------
# Casa (grade do mapa) -> sprite de casa de lava, margem ou chamuscada.
var _lava_cells: Dictionary = {}
var _lava_lake_rects: Array[Rect2] = []   # retângulo (mundo) de cada lago, com a margem
var _lava_bubbles: Array = []             # [centro (mundo), fase, ritmo]
var _landmark_rects: Array[Rect2] = []    # montanhas/marcos já postos (não se sobrepõem)

# Bioma do mapa ("floresta" | "deserto"); defina ANTES de build().
var biome: String = "floresta"
var _th: Dictionary = THEMES["floresta"]
var _dir: String = DIR
var _swirls: Array = []     # [Vector2 base, float fase]
var _swirl_t: float = 0.0
var _swirl_frame: int = -1
const SWIRL_FRAME_PX: int = 8
const SWIRL_FRAMES: int = 4
var _swirl_tex: Texture2D = null

static var _tex_cache: Dictionary = {}

# Sprites animados (Caldeira): um sprite <pasta>/X.png anima se existir
# <pasta>/anim/X_f1.png, X_f2.png... (lagos, fontes, marcos de lava, chaminés).
# O mapa inteiro é redesenhado só quando o quadro global muda (ANIM_FPS), então
# as emendas do autotile dos lagos ficam sempre no mesmo quadro.
const ANIM_FPS: float = 5.0
static var _anim_cache: Dictionary = {}
var _anim_on: bool = false
var _anim_tick: int = 0

static func _anim_frames(tex: Texture2D) -> Array:
	if tex == null:
		return []
	var p: String = tex.resource_path
	if _anim_cache.has(p):
		return _anim_cache[p]
	var out: Array = []
	var base: String = p.get_base_dir() + "/anim/" + p.get_file().get_basename() + "_f%d.png"
	for i in range(1, 9):
		var fp: String = base % i
		if not ResourceLoader.exists(fp):
			break
		out.append(load(fp))
	_anim_cache[p] = out
	return out

func _anim_tex(tex: Texture2D) -> Texture2D:
	if not _anim_on:
		return tex
	var fr: Array = _anim_frames(tex)
	if fr.is_empty():
		return tex
	return fr[_anim_tick % fr.size()]

static func _tex(sub: String, dir: String = DIR) -> Texture2D:
	var key = dir + sub
	if not _tex_cache.has(key):
		var path = dir + sub + ".png"
		_tex_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[key]

# layers: RunManager.map_data (Array[Array] de MapNode já posicionados).
func build(layers: Array, tile_px: float, sprite_scale: int, min_col: int, max_col: int, min_row: int, max_row: int) -> void:
	_tile = tile_px
	_scale = sprite_scale
	_tiles.clear()
	_decor.clear()
	_clearings.clear()
	_swirls.clear()
	_th = THEMES.get(biome, THEMES["floresta"])
	_dir = _th["dir"]
	_swirl_tex = null
	var frame_name: String = "moldura" if _th["frame"] == "moldura" else "tabuleiro/borda/borda_tabuleiro_13x12"
	_frame_tex = _tex(frame_name, _dir)

	var rng = RandomNumberGenerator.new()
	rng.seed = _layout_seed(layers)

	_board_rect = Rect2(
		Vector2(min_col * _tile - _tile / 2.0, min_row * _tile - _tile / 2.0),
		Vector2((max_col - min_col + 1) * _tile, (max_row - min_row + 1) * _tile))
	var pad_v: Vector2 = (_th["frame_pad"] as Vector2) * float(_scale)
	world_rect = Rect2(_board_rect.position - pad_v, _board_rect.size + pad_v * 2.0)

	# Segmentos das trilhas e posições dos nós (pra manter decoração longe).
	var segments: Array = []
	var node_points: Array = []
	for layer in layers:
		for node in layer:
			node_points.append([node.position, node.type == MapNode.NodeType.Chefe])
			for child in node.children:
				segments.append([node.position, child.position])

	# Casas por onde a PEÇA realmente anda: o desenho da trilha (retas + diagonais) e os
	# saltos em diagonal do peão. Enfeites grandes nunca podem cobrir essas casas.
	_walk_cells.clear()
	for layer in layers:
		for node in layer:
			var gn := Vector2i((node.position / _tile).round())
			_add_walk_cell(gn)
			for child in node.children:
				var gc := Vector2i((child.position / _tile).round())
				var g_t := gn
				_add_walk_cell(g_t)
				for st in ForestTrail.build_steps(gn, gc):
					g_t += st
					_add_walk_cell(g_t)
				if (absi(gc.x - gn.x) + absi(gc.y - gn.y)) % 2 == 0:   # paridade de damas: senão o salto nunca chega
					for hop in MapPlayerPawn.calculate_diagonal_path(gn, gc):
						_add_walk_cell(hop)

	_plan_lava_lakes(rng, min_col, max_col, min_row, max_row, node_points)
	_landmark_rects.clear()
	var half_cols = maxf(float(max_col), float(-min_col))
	var tree_grounds: Array[Vector2] = []
	for r in range(min_row, max_row + 1):
		for c in range(min_col, max_col + 1):
			var center = Vector2(c * _tile, r * _tile)
			var rect = Rect2(center - Vector2(_tile, _tile) / 2.0, Vector2(_tile, _tile))
			var is_light = ((r + c) % 2 + 2) % 2 == 0
			var pool: Array = _th["tiles_light"] if is_light else _th["tiles_dark"]
			var alt: float = _altitude(center.y)
			var tile_name: String = pool[rng.randi() % pool.size()]
			if biome == "cume":
				tile_name = _cume_tile_by_altitude(pool, alt, rng)
			var lava_name: String = String(_lava_cells.get(Vector2i(c, r), ""))
			if lava_name.begins_with("casas/"):
				tile_name = lava_name   # casa chamuscada perto de um lago
			if tile_name != "":
				var tex = _tex(BOARD_DIR + tile_name, _dir)
				if tex != null:
					_tiles.append([tex, rect, rng.randf() < 0.5, rng.randf() < 0.5])
			if lava_name.begins_with("LAVA"):
				continue   # embaixo do lago de lava (ou da fonte): nada de enfeite

			var d_path = _distance_to_walk(center)
			var d_node = _distance_to_nodes(center, node_points)
			var edge_w = clampf(absf(float(c)) / maxf(half_cols, 1.0), 0.0, 1.0)

			# Árvore (mais comum quanto mais perto da borda lateral); se não
			# vier árvore, às vezes um arbusto ou uma peça grande (toco, moita...).
			var p_tree = (0.2 + 0.4 * edge_w * edge_w) * float(_th["tree_density"])
			var placed_tree = false
			var tree_roll: float = rng.randf()
			var trees: Array = _th["trees_light"] if is_light else _th["trees_dark"]
			var tree_name: String = trees[rng.randi() % trees.size()]
			if biome == "cume":
				tree_name = _cume_tree_by_altitude(trees, tree_name, alt, rng)
			var t = _tex(BOARD_DIR + tree_name, _dir)
			var tree_ground: Vector2 = _snap(center + _jitter(rng, 0.12))
			if tree_roll < p_tree and t != null and _tree_fits(t, tree_ground, node_points, tree_grounds) \
					and not _covers_walk_cell(Rect2(_tree_center(t, tree_ground) - t.get_size() * float(_scale) / 2.0, t.get_size() * float(_scale))):
				_decor.append([t, _tree_center(t, tree_ground), tree_ground.y])
				tree_grounds.append(tree_ground)
				placed_tree = true
			elif d_path > 0.8 * _tile and d_node > 1.2 * _tile and rng.randf() < 0.32 + 0.12 * edge_w:
				var pool_big: Array[String] = []
				pool_big.append_array(_th["bushes_light"] if is_light else _th["bushes_dark"])
				pool_big.append_array(_th["big_light"] if is_light else _th["big_dark"])
				var bt = _tex(BOARD_DIR + pool_big[rng.randi() % pool_big.size()], _dir)
				var bpos: Vector2 = _snap(center + _jitter(rng, 0.2))
				if bt != null and not _covers_walk_cell(Rect2(bpos - bt.get_size() * float(_scale) / 2.0, bt.get_size() * float(_scale))):
					_decor.append([bt, bpos, center.y])
					placed_tree = true

			# Detalhes pequenos (até 2 por casa), só fora da trilha/clareira.
			if not placed_tree and d_path > 0.75 * _tile and d_node > 1.1 * _tile:
				var smalls: Array = _th["small_light"] if is_light else _th["small_dark"]
				for attempt in range(4):
					if rng.randf() < 0.36:
						var st = _tex(BOARD_DIR + smalls[rng.randi() % smalls.size()], _dir)
						if st != null:
							var pos = _snap(center + _jitter(rng, 0.34))
							_decor.append([st, pos, pos.y])
				var grass: Array = _th["grass_light"] if is_light else _th["grass_dark"]
				# Cume: mais neve acumulada (montinhos, neve soprada) quanto mais alto
				var grass_mul: float = (0.6 + 0.9 * alt) if biome == "cume" else 1.0
				for attempt in range(GRASS_ATTEMPTS):
					if rng.randf() < GRASS_CHANCE * float(_th["grass_scale"]) * grass_mul:
						var gt = _tex(BOARD_DIR + grass[rng.randi() % grass.size()], _dir)
						if gt != null:
							var gpos = _snap(center + _jitter(rng, 0.36))
							_decor.append([gt, gpos, gpos.y])

	_place_mountains(rng, node_points)
	if _th.has("landmarks"):
		_place_mountains(rng, node_points, _th["landmarks"], float(_th.get("landmark_div", 18.0)), 14)
	if not _lava_cells.is_empty():
		# nada de enfeite pequeno/médio com o pé dentro da lava (os da casa ao lado escorregavam pra cima do lago)
		_decor = _decor.filter(func(d): return d.size() > 3 or d[0].resource_path.contains("/lagos/") or not _decor_hits_lava(d))
	if biome != "floresta":
		_declutter_big_props()
	_decor.sort_custom(func(a, b): return a[2] < b[2])
	if _th["frame"] == "bordas":
		_clear_decor_from_frame_band()

	for np in node_points:
		var cname: String = String(_th["clearing_boss"] if np[1] else _th["clearing_node"])
		var ct = _tex(cname, _dir) if cname != "" else null
		if ct != null:
			_clearings.append([ct, np[0]])

	# Redemoinhos de areia (só no deserto): poucos, longe das trilhas, animados em _process.
	var swirl_name: String = String(_th.get("swirls", ""))
	if swirl_name != "":
		_swirl_tex = _tex(swirl_name, _dir)
		if _swirl_tex != null:
			var n_swirls: int = clampi(int(_board_rect.size.x * _board_rect.size.y / (_tile * _tile) / 30.0), 3, 8)
			var tries := 0
			while _swirls.size() < n_swirls and tries < 80:
				tries += 1
				var sp := Vector2(
					rng.randf_range(_board_rect.position.x + _tile, _board_rect.end.x - _tile),
					rng.randf_range(_board_rect.position.y + _tile, _board_rect.end.y - _tile))
				if _distance_to_paths(sp, segments) < 0.9 * _tile or _distance_to_nodes(sp, node_points) < 1.3 * _tile:
					continue
				_swirls.append([sp, rng.randf() * TAU])
	_setup_snow(rng)
	if biome == "cume":
		_setup_terraces(rng)
	# _process anima redemoinhos, neve/brasas e os sprites animados da Caldeira
	set_process(not _swirls.is_empty() or _snow_layer != null or _anim_on)

	queue_redraw()

# Lagos de lava (autotile "dual grid"): quais CASAS viram lava é decidido aqui; cada
# peça de 26x26 (biomas/caldeira/tabuleiro/lagos/lago_<NO><NE><SO><SE>.png) fica
# centrada no CANTO entre 4 casas e mostra lava nos quartos cujas casas são lago
# (transparente no resto: o tabuleiro aparece por baixo). Assim qualquer formato
# (lago redondo, comprido, em L, rio de 1 casa) sai contínuo com a beira desenhada.
# Lagos próximos se ligam por rios de 1 casa de largura. Nada encosta na trilha
# nem nos nós.
const LAKE_DIR := "lagos/"
var _lake_tiles: Array = []     # [Texture2D, Rect2 mundo]
var _lake_overlays: Array = []  # [Texture2D, Rect2 mundo] (ilhotas, crosta, coroa, pontes)

func _in_lava(p: Vector2, _pad: int = 1) -> bool:
	var cell := Vector2i(int(roundf(p.x / _tile)), int(roundf(p.y / _tile)))
	return String(_lava_cells.get(cell, "")) == "LAVA"

func _lake_cell_ok(cell: Vector2i, min_col: int, max_col: int, min_row: int, max_row: int, node_points: Array) -> bool:
	if cell.x <= min_col or cell.x >= max_col or cell.y <= min_row or cell.y >= max_row:
		return false   # a casa da beira fica livre (a peça da lava passaria da moldura)
	var ctr := Vector2(cell.x * _tile, cell.y * _tile)
	if _covers_walk_cell(Rect2(ctr - Vector2(_tile, _tile) * 0.62, Vector2(_tile, _tile) * 1.24)):
		return false
	for np in node_points:
		if ctr.distance_to(np[0]) < _tile * 1.6:
			return false
	return true

func _plan_lava_lakes(rng: RandomNumberGenerator, min_col: int, max_col: int, min_row: int, max_row: int, node_points: Array) -> void:
	_lava_cells.clear()
	_lava_lake_rects.clear()
	_lava_bubbles.clear()
	_lake_tiles.clear()
	_lake_overlays.clear()
	if not bool(_th.get("lava_lakes", false)):
		return
	var lava: Dictionary = {}       # Vector2i -> true
	var river: Dictionary = {}      # casas de rio (1 de largura)
	var cells: int = (max_col - min_col + 1) * (max_row - min_row + 1)
	var want: int = clampi(int(cells / 45.0), 2, 6)
	var lakes: Array = []           # [Array de casas, centro Vector2i]
	var tries: int = 0
	while lakes.size() < want and tries < 400:
		tries += 1
		var seed_c := Vector2i(rng.randi_range(min_col + 1, max_col - 1), rng.randi_range(min_row + 1, max_row - 1))
		if not _lake_cell_ok(seed_c, min_col, max_col, min_row, max_row, node_points):
			continue
		# longe de outro lago (2 casas de folga)
		var far := true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if lava.has(seed_c + Vector2i(dx, dy)):
					far = false
		if not far:
			continue
		# cresce a partir da semente: 3 a 8 casas, preferindo vizinhas do que já é lago
		var size_want: int = rng.randi_range(3, 8)
		var shape: Array = [seed_c]
		var guard: int = 0
		while shape.size() < size_want and guard < 60:
			guard += 1
			var base: Vector2i = shape[rng.randi() % shape.size()]
			var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
			var nc: Vector2i = base + d
			if shape.has(nc) or not _lake_cell_ok(nc, min_col, max_col, min_row, max_row, node_points):
				continue
			var touches_other := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if lava.has(nc + Vector2i(dx, dy)):
						touches_other = true
			if touches_other:
				continue
			shape.append(nc)
		if shape.size() < 2:
			continue
		# tapa buracos de 1 casa cercados (ficam feios) e soma
		var sum := Vector2.ZERO
		for cc in shape:
			lava[cc] = true
			sum += Vector2(cc)
		lakes.append([shape, Vector2i((sum / float(shape.size())).round())])
	# rios: cada lago se liga ao vizinho mais próximo (até 7 casas) por um caminho em L
	var linked: Dictionary = {}
	for i in range(lakes.size()):
		var best: int = -1
		var best_d: float = INF
		for j in range(lakes.size()):
			if i == j or linked.has(Vector2i(mini(i, j), maxi(i, j))):
				continue
			var dd: float = Vector2(lakes[i][1]).distance_to(Vector2(lakes[j][1]))
			if dd < best_d:
				best_d = dd
				best = j
		if best < 0 or best_d > 7.0:
			continue
		var a: Vector2i = lakes[i][1]
		var b: Vector2i = lakes[best][1]
		for horizontal_first in ([true, false] if rng.randf() < 0.5 else [false, true]):
			var path: Array = []
			var p: Vector2i = a
			var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
			for target in [corner, b]:
				while p != target:
					p += Vector2i(signi(target.x - p.x), signi(target.y - p.y))
					path.append(p)
			var ok := true
			for pc in path:
				if not lava.has(pc) and not _lake_cell_ok(pc, min_col, max_col, min_row, max_row, node_points):
					ok = false
					break
			if ok:
				for pc in path:
					if not lava.has(pc):
						river[pc] = true
					lava[pc] = true
				linked[Vector2i(mini(i, best), maxi(i, best))] = true
				break
	if lava.is_empty():
		return
	for cc in lava.keys():
		_lava_cells[cc] = "LAVA"
		_lava_lake_rects.append(Rect2(Vector2(cc.x * _tile - _tile / 2.0, cc.y * _tile - _tile / 2.0), Vector2(_tile, _tile)))
	# casas vizinhas às vezes chamuscadas (só a arte da casa; a trilha pode passar)
	for cc in lava.keys():
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cc + dv
			if lava.has(nb) or _lava_cells.has(nb) or rng.randf() > 0.3:
				continue
			var tone: String = "clara" if ((nb.x + nb.y) % 2 + 2) % 2 == 0 else "escura"
			_lava_cells[nb] = "casas/casa_chamuscada_%s_%d" % [tone, rng.randi_range(1, 3)]
	# peças do autotile: uma por canto que encosta em alguma casa de lava
	var verts: Dictionary = {}
	for cc in lava.keys():
		for dv in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			verts[cc + dv] = true   # canto (vx, vy) = canto de cima à esquerda da casa (vx, vy)
	for v in verts.keys():
		var no: int = 1 if lava.has(v + Vector2i(-1, -1)) else 0
		var ne: int = 1 if lava.has(v + Vector2i(0, -1)) else 0
		var so: int = 1 if lava.has(v + Vector2i(-1, 0)) else 0
		var se: int = 1 if lava.has(v + Vector2i(0, 0)) else 0
		var key: String = "%d%d%d%d" % [no, ne, so, se]
		if key == "0000":
			continue
		var piece: String = "lago_" + key
		if key == "1111":
			var roll: float = rng.randf()
			if roll < 0.12:
				piece = "lago_1111_v2"
			elif roll < 0.2:
				piece = "lago_1111_v3"
			elif roll < 0.26:
				piece = "lago_1111_v4"
		var tex: Texture2D = _tex(BOARD_DIR + LAKE_DIR + piece, _dir)
		if tex != null:
			var tl := Vector2((v.x - 1) * _tile, (v.y - 1) * _tile)
			_lake_tiles.append([tex, Rect2(tl, Vector2(_tile, _tile))])
	# enfeites por cima: pontes nos rios, ilhotas/crosta/coroa no miolo, bolhas
	var S: float = float(_scale)
	for cc in river.keys():
		if rng.randf() > 0.35:
			continue
		var vert: bool = lava.has(cc + Vector2i(0, -1)) and lava.has(cc + Vector2i(0, 1)) and not lava.has(cc + Vector2i(-1, 0)) and not lava.has(cc + Vector2i(1, 0))
		var horz: bool = lava.has(cc + Vector2i(-1, 0)) and lava.has(cc + Vector2i(1, 0)) and not lava.has(cc + Vector2i(0, -1)) and not lava.has(cc + Vector2i(0, 1))
		var pname: String = "ponte_h" if vert else ("ponte_v" if horz else "")
		if pname != "":
			_add_lake_overlay(pname, Vector2(cc.x * _tile, cc.y * _tile), S)
	for cc in lava.keys():
		var inner := true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not lava.has(cc + dv):
				inner = false
		var ctr := Vector2(cc.x * _tile, cc.y * _tile)
		var jit := Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22)) * _tile
		if inner:
			var r2: float = rng.randf()
			if r2 < 0.12:
				_add_lake_overlay("ilhota_%d" % rng.randi_range(1, 3), ctr + jit, S)
			elif r2 < 0.3:
				_add_lake_overlay("crosta_boiando_%d" % rng.randi_range(1, 3), ctr + jit, S)
			elif r2 < 0.36:
				_add_lake_overlay("coroa_afundando", ctr + jit, S)
			if rng.randf() < 0.7:
				_lava_bubbles.append([ctr - jit, rng.randf() * 10.0, rng.randf_range(0.8, 1.6)])
		elif not river.has(cc) and rng.randf() < 0.3:
			_lava_bubbles.append([ctr + jit * 0.5, rng.randf() * 10.0, rng.randf_range(0.8, 1.6)])
	# fonte: de onde a lava nasce, na beira de cima de alguns lagos
	for lk in lakes:
		if rng.randf() > 0.6:
			continue
		var tops: Array = []
		for cc in lk[0]:
			var up: Vector2i = cc + Vector2i(0, -1)
			if not lava.has(up) and _lake_cell_ok(up, min_col, max_col, min_row, max_row, node_points):
				tops.append(cc)
		if tops.is_empty():
			continue
		var tc: Vector2i = tops[rng.randi() % tops.size()]
		var ft: Texture2D = _tex(BOARD_DIR + LAKE_DIR + "fonte_%d" % rng.randi_range(1, 3), _dir)
		if ft != null:
			var fsz: Vector2 = ft.get_size() * S
			# a ponta de baixo da fonte entra uns 8 px na casa de lava
			var bottom_y: float = tc.y * _tile - _tile / 2.0 + 8.0 * S
			var fpos := Vector2(tc.x * _tile - fsz.x / 2.0, bottom_y - fsz.y)
			_decor.append([ft, fpos + fsz / 2.0, bottom_y])
			_lava_cells[tc + Vector2i(0, -1)] = "LAVA_SRC"   # nada de enfeite em cima da fonte

# A metade de baixo do enfeite (o pé e o corpo) encosta em alguma casa de lava?
func _decor_hits_lava(d: Array) -> bool:
	var t: Texture2D = d[0]
	var sz: Vector2 = t.get_size() * float(_scale)
	var r := Rect2(d[1] - sz / 2.0, sz)
	var low := Rect2(r.position.x + sz.x * 0.15, r.position.y + sz.y * 0.5, sz.x * 0.7, sz.y * 0.5)
	var pad: float = -_tile * 0.08
	if _is_big_decor(d):
		# sprite grande: quase o corpo todo longe da lava, com um respiro (não "boia" na beira do lago)
		low = Rect2(r.position.x + sz.x * 0.05, r.position.y + sz.y * 0.25, sz.x * 0.9, sz.y * 0.75)
		pad = _tile * 0.1
	for lr in _lava_lake_rects:
		if (lr as Rect2).grow(pad).intersects(low):
			return true
	return false

func _add_lake_overlay(piece: String, center: Vector2, S: float) -> void:
	var t: Texture2D = _tex(BOARD_DIR + LAKE_DIR + piece, _dir)
	if t == null:
		return
	var sz: Vector2 = t.get_size() * S
	_lake_overlays.append([t, Rect2(_snap(center - sz / 2.0), sz)])

static func _weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: int = 0
	for w in weights:
		total += int(w)
	var roll: int = rng.randi() % maxi(1, total)
	for i in range(weights.size()):
		roll -= int(weights[i])
		if roll < 0:
			return i
	return 0

# --- Cume Congelado: sensação de subida ------------------------------------------
# Altitude de um ponto do mapa: 0 no pé (fileira de baixo, onde a run começa) e 1
# no cume (fileira de cima, onde fica o chefe).
func _altitude(y: float) -> float:
	if _board_rect.size.y <= 0.0:
		return 0.5
	return clampf(1.0 - (y - _board_rect.position.y) / _board_rect.size.y, 0.0, 1.0)

# Casas: placas de gelo quase não aparecem embaixo e ficam comuns lá em cima.
func _cume_tile_by_altitude(pool: Array, alt: float, rng: RandomNumberGenerator) -> String:
	var ice: Array = pool.filter(func(n): return String(n).contains("gelo"))
	var rock: Array = pool.filter(func(n): return not String(n).contains("gelo"))
	var p_ice: float = 0.01 + 0.24 * alt * alt
	if not ice.is_empty() and rng.randf() < p_ice:
		return ice[rng.randi() % ice.size()]
	return rock[rng.randi() % rock.size()] if not rock.is_empty() else pool[0]

# Limite das árvores: pinheiros fartos no pé, raros no meio e nenhum perto do
# cume (lá só gelo, totens de pedra e montanhas).
func _cume_tree_by_altitude(pool: Array, picked: String, alt: float, rng: RandomNumberGenerator) -> String:
	var is_pine: bool = picked.contains("pinheiro")
	var pine_ok: float = clampf(1.25 - alt * 1.6, 0.0, 1.0)
	if is_pine and rng.randf() < pine_ok:
		return picked
	if not is_pine and alt < 0.35 and rng.randf() < 0.6:
		# no pé, troca boa parte do gelo/totem por pinheiro
		var pines: Array = pool.filter(func(n): return String(n).contains("pinheiro"))
		if not pines.is_empty():
			return pines[rng.randi() % pines.size()]
	var high: Array = pool.filter(func(n): return not String(n).contains("pinheiro"))
	if high.is_empty():
		return picked
	return high[rng.randi() % high.size()] if is_pine else picked

# Patamares: a cada 3 a 5 fileiras o terreno dá um degrau. Na beirada de cada
# patamar fica uma franja de neve com sincelos e, logo abaixo, a sombra do
# paredão; cada patamar mais baixo é um pouco mais escuro (o vale fica lá
# embaixo). Desenhado por cima das casas e por baixo da decoração e das trilhas.
var _terraces: Array = []   # fileiras (0 = topo) onde há uma beirada de patamar

func _setup_terraces(rng: RandomNumberGenerator) -> void:
	_terraces.clear()
	_terrace_texs.clear()
	var rows: int = int(round(_board_rect.size.y / _tile))
	var r: int = 2 + rng.randi() % 2
	while r < rows - 1:
		_terraces.append(r)
		r += rng.randi_range(3, 5)

func _draw_terraces() -> void:
	if _terraces.is_empty():
		return
	var S: float = float(_scale)
	var br: Rect2 = _board_rect
	# escurecimento em degraus: cada patamar abaixo um pouco mais fundo
	var edges: Array = [0]
	edges.append_array(_terraces)
	edges.append(int(round(br.size.y / _tile)))
	for i in range(edges.size() - 1):
		var y0: float = br.position.y + edges[i] * _tile
		var y1: float = br.position.y + edges[i + 1] * _tile
		var a: float = terrace_shade((y0 + y1) / 2.0)
		if a > 0.005:
			draw_rect(Rect2(Vector2(br.position.x, y0), Vector2(br.size.x, y1 - y0)), Color(0.10, 0.07, 0.16, a))
	for t in _terraces:
		var tex: ImageTexture = _terrace_texture(t)
		draw_texture_rect(tex, Rect2(Vector2(br.position.x, br.position.y + float(t) * _tile - float(_TERRACE_TOP) * S), Vector2(tex.get_size()) * S), false)

# Quanto (alfa) o patamar onde fica a altura `y` é escurecido (0 no topo).
func terrace_shade(y: float) -> float:
	if _terraces.is_empty():
		return 0.0
	var row: float = (y - _board_rect.position.y) / _tile
	var idx: int = 0
	for t in _terraces:
		if row >= float(t):
			idx += 1
	return 0.16 * float(idx) / float(maxi(1, _terraces.size()))

# Redesenha as beiradas dos patamares POR CIMA de algo que cobriu o chão (o glaciar
# do Cume): só nas colunas das casas dadas (grade do mapa -> true) que encostam na
# beirada, por cima ou por baixo. Assim o degrau continua inteiro de lado a lado.
func draw_terraces_over(ci: CanvasItem, cells: Dictionary) -> void:
	if _terraces.is_empty():
		return
	var S: float = float(_scale)
	var br: Rect2 = _board_rect
	var tile_px: int = int(round(_tile / S))
	for t in _terraces:
		var y_base: float = br.position.y + float(t) * _tile
		# fileiras (grade) logo acima e logo abaixo da beirada
		var gy_below: int = int(round((y_base + _tile * 0.5) / _tile))
		var gy_above: int = gy_below - 1
		var done: Dictionary = {}
		var tex: ImageTexture = null
		for c in cells:
			if c.y != gy_below and c.y != gy_above:
				continue
			if done.has(c.x):
				continue
			done[c.x] = true
			if tex == null:
				tex = _terrace_texture(t)
			var x_left: float = float(c.x) * _tile - _tile * 0.5
			var cx0: int = int(round((x_left - br.position.x) / S))
			ci.draw_texture_rect_region(tex, Rect2(Vector2(x_left, y_base - float(_TERRACE_TOP) * S), Vector2(_tile, float(_TERRACE_H) * S)), Rect2(cx0, 0, tile_px, _TERRACE_H))

# A beirada de cada patamar é pintada UMA vez numa textura (1 px = 1 px nativo) e
# desenhada ampliada: eram ~40 mil retângulos por quadro só de beirada (queda de FPS).
const _TERRACE_TOP: int = 9       # px nativos acima da linha da beirada
const _TERRACE_H: int = 32        # altura total da textura (px nativos)
var _terrace_texs: Dictionary = {}

func _terrace_texture(t: int) -> ImageTexture:
	if _terrace_texs.has(t):
		return _terrace_texs[t]
	var cols_px: int = int(round(_board_rect.size.x / float(_scale)))
	var img := Image.create(cols_px, _TERRACE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rock := Color(0.16, 0.11, 0.17, 0.62)
	var offs: Array = []
	for cx in range(cols_px):
		# a beirada não é reta: trechos de ~1 casa sobem/descem uns pixels
		var seg: int = int(cx / 22.0)
		var off: int = (absi(hash(Vector3i(seg, t, 5))) % 5 - 2) * 2
		offs.append(off)
		var y: int = _TERRACE_TOP + off
		# paredão: rocha escura logo abaixo da neve, e a sombra que ele joga
		for k in range(3):
			img.set_pixel(cx, y + k, rock)
		for k in range(6):
			var sa: float = 0.32 * (1.0 - float(k) / 6.0)
			for q in range(2):
				img.set_pixel(cx, y + 3 + k * 2 + q, Color(0.08, 0.05, 0.12, sa))
		# franja de neve irregular
		var h: int = 2 + absi(hash(Vector3i(int(cx / 3.0), t, 77))) % 3
		for k in range(h):
			img.set_pixel(cx, y - h + k, Color("dfe8ef"))
		img.set_pixel(cx, y - h, Color("f4f7fa"))
		img.set_pixel(cx, y - 1, Color("c3d2de"))
		# sincelos pendurados aqui e ali
		var ih: int = absi(hash(Vector3i(cx, t, 13))) % 19
		if ih < 3:
			for k in range(ih + 2):
				img.set_pixel(cx, y + k, Color("a9dcef"))
			img.set_pixel(cx, y + ih + 1, Color("6fb6d8"))
	# degrau entre dois trechos: um pouco de paredão vertical
	for cx in range(1, cols_px):
		if offs[cx] != offs[cx - 1]:
			var y_a: int = _TERRACE_TOP + mini(offs[cx], offs[cx - 1])
			var y_b: int = _TERRACE_TOP + maxi(offs[cx], offs[cx - 1])
			for yy in range(y_a, y_b + 3):
				for xx in [cx - 1, cx]:
					if img.get_pixel(xx, yy).a < 0.6:
						img.set_pixel(xx, yy, rock)
	var tex := ImageTexture.create_from_image(img)
	_terrace_texs[t] = tex
	return tex

const _ALT_FONT := preload("res://assets/fonts/m5x7.ttf")
const ALT_BASE_M: int = 2400     # altitude no pé do mapa
const ALT_TOP_M: int = 6800      # altitude do cume

# Placas de altitude presas na moldura direita (e o "CUME" lá em cima).
func _draw_altitude_marks() -> void:
	var S: float = float(_scale)
	var rows: int = int(round(_board_rect.size.y / _tile))
	# meio da moldura DIREITA (a esquerda fica atrás do painel de leis); a moldura
	# do cume tem 18 px nativos numa casa de 26
	var x_mid: float = _board_rect.end.x + 9.0 * _tile / 26.0
	var fs: int = 32
	var step: int = 3
	# metros por fileira em número redondo (degraus iguais entre as placas)
	var per_row: int = maxi(50, int(round(float(ALT_TOP_M - ALT_BASE_M) / maxf(1.0, rows - 1.0) / 50.0)) * 50)
	for j in range(step, rows, step):
		var yc: float = _board_rect.position.y + (float(j) + 0.5) * _tile
		_alt_plate(Vector2(x_mid, yc), "%d m" % (ALT_TOP_M - j * per_row), fs, S, false)
	_alt_plate(Vector2(x_mid, _board_rect.position.y + 0.5 * _tile), "CUME", fs, S, true)

func _alt_plate(c: Vector2, txt: String, fs: int, S: float, top: bool) -> void:
	var tw: float = _ALT_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w: float = ceilf((tw + 6.0 * S) / S) * S
	var h: float = 13.0 * S
	var r := Rect2(_snap(c - Vector2(w, h) / 2.0), Vector2(w, h))
	# estaca
	draw_rect(Rect2(_snap(Vector2(c.x - S, r.end.y)), Vector2(2.0 * S, 4.0 * S)), Color("3a2d37"))
	# placa de pedra com contorno e neve em cima
	draw_rect(r.grow(S), Color("1f161d"))
	draw_rect(r, Color("4a3a46") if not top else Color("6fb6d8"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, S)), Color("685563") if not top else Color("a9dcef"))
	draw_rect(Rect2(r.position - Vector2(0, S), Vector2(r.size.x, S * 2.0)), Color("f4f7fa"))
	draw_rect(Rect2(r.position + Vector2(S * 2.0, S), Vector2(r.size.x * 0.4, S)), Color("dfe8ef"))
	var base_y: float = r.position.y + h / 2.0 + (_ALT_FONT.get_ascent(fs) - _ALT_FONT.get_descent(fs)) / 2.0 + S * 0.5
	var col: Color = Color("efe6cf") if not top else Color("ffffff")
	draw_string(_ALT_FONT, Vector2(r.position.x, base_y + S * 0.5), txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color("1f161d"))
	draw_string(_ALT_FONT, Vector2(r.position.x, base_y - S * 0.5), txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

# --- Cume Congelado: neve caindo e rajadas de vento sobre o tabuleiro ----------
# Ficam numa camada filha (desenhada por cima das casas e enfeites, por baixo dos
# nós e da peça), redesenhada a cada quadro sem refazer o tabuleiro inteiro.
const SNOW_GUSTS := "res://assets/sprites/mapa/ceu/cume/rajada_%d.png"
var _snow_layer: Node2D = null
var _flakes: Array = []      # [x, y, velocidade, fase, tamanho(px nativos), profundidade]
var _gusts: Array = []       # [Texture2D, y, velocidade, atraso, fase]
var _clouds: Array = []      # mar de nuvens no pé do mapa: [x (0..1), y (px abaixo do topo da faixa), largura (casas), velocidade, semente]
var _snow_t: float = 0.0
var _embers_on: bool = false   # Caldeira: a mesma camada desenha brasas subindo e cinza caindo

func _setup_snow(rng: RandomNumberGenerator) -> void:
	_flakes.clear()
	_gusts.clear()
	_clouds.clear()
	_embers_on = bool(_th.get("embers", false))
	_anim_on = bool(_th.get("animated", false))
	if not bool(_th.get("snow", false)) and not _embers_on:
		if _snow_layer != null:
			_snow_layer.queue_free()
			_snow_layer = null
		return
	if _snow_layer == null:
		_snow_layer = Node2D.new()
		_snow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_snow_layer.draw.connect(_draw_snow)
		_snow_layer.process_mode = Node.PROCESS_MODE_INHERIT
		add_child(_snow_layer)
		_snow_layer.set_process(true)
	var area: float = world_rect.size.x * world_rect.size.y / (_tile * _tile)
	if _embers_on:
		# [x, y, velocidade, fase, forma, profundidade]; forma 9 = brasa, 0/1 = cinza
		for i in range(clampi(int(area * 0.9), 30, 260)):
			var dep: float = rng.randf()
			var ember: bool = i % 3 == 0
			_flakes.append([rng.randf(), rng.randf(), lerpf(10.0, 30.0, dep), rng.randf() * TAU, 9 if ember else (0 if dep < 0.6 else 1), dep])
		set_process(true)
		return
	for i in range(clampi(int(area * 2.6), 60, 700)):
		var depth: float = rng.randf()
		# forma: 0 = ponto, 1 = quadradinho 2x2, 2 = cruz 3x3, 3 = estrela 5x5 (poucas)
		var shape: int = 0 if depth < 0.45 else (1 if depth < 0.8 else (2 if depth < 0.96 else 3))
		_flakes.append([rng.randf(), rng.randf(), lerpf(16.0, 52.0, depth), rng.randf() * TAU, shape, depth])
	var gust_tex: Array = []
	for k in range(1, 5):
		var gp: String = SNOW_GUSTS % k
		if ResourceLoader.exists(gp):
			gust_tex.append(load(gp))
	if not gust_tex.is_empty():
		for i in range(clampi(int(world_rect.size.y / _tile * 0.8), 4, 16)):
			# mais rajadas no alto (perto do cume venta mais)
			_gusts.append([gust_tex[i % gust_tex.size()], pow(rng.randf(), 1.7), rng.randf_range(0.10, 0.22), rng.randf() * 6.0, rng.randf() * TAU])
	# mar de nuvens: a subida começa acima das nuvens
	for i in range(clampi(int(_board_rect.size.x / _tile * 1.6), 6, 18)):
		_clouds.append([rng.randf(), rng.randf_range(-0.6, 1.4) * _tile, rng.randf_range(1.2, 2.8), rng.randf_range(0.006, 0.016) * (1.0 if rng.randf() < 0.7 else -1.0), rng.randi()])
	set_process(true)

# Floco de neve em pixel art (u = tamanho de 1 pixel da arte). Usado também nos
# fundos do duelo e no céu do mapa.
static func draw_flake(ci: CanvasItem, p: Vector2, u: float, shape: int, col: Color) -> void:
	match shape:
		0:
			ci.draw_rect(Rect2(p, Vector2(u, u)), col)
		1:
			ci.draw_rect(Rect2(p, Vector2(u, u) * 2.0), col)
		2:
			ci.draw_rect(Rect2(p + Vector2(u, 0), Vector2(u, u * 3.0)), col)
			ci.draw_rect(Rect2(p + Vector2(0, u), Vector2(u * 3.0, u)), col)
		_:
			ci.draw_rect(Rect2(p + Vector2(u * 2.0, 0), Vector2(u, u * 5.0)), col)
			ci.draw_rect(Rect2(p + Vector2(0, u * 2.0), Vector2(u * 5.0, u)), col)
			var dim := Color(col.r, col.g, col.b, col.a * 0.6)
			for d in [Vector2(1, 1), Vector2(3, 1), Vector2(1, 3), Vector2(3, 3)]:
				ci.draw_rect(Rect2(p + d * u, Vector2(u, u)), dim)
			ci.draw_rect(Rect2(p + Vector2(u * 2.0, u * 2.0), Vector2(u, u)), Color(0.85, 0.95, 1.0, col.a))

# Ar da montanha: névoa e mar de nuvens no pé, ar frio e limpo no alto.
func _draw_altitude_air(S: float) -> void:
	var br: Rect2 = _board_rect
	# véu frio no alto (faixas em degrau, ficando mais forte perto do cume)
	var bands: int = 8
	var top_h: float = br.size.y * 0.22
	for i in range(bands):
		var a: float = 0.10 * (1.0 - float(i) / bands)
		var y0: float = br.position.y + top_h * float(i) / bands
		_snow_layer.draw_rect(Rect2(Vector2(br.position.x, y0), Vector2(br.size.x, ceilf(top_h / bands))), Color(0.78, 0.9, 1.0, a))
	# névoa subindo do pé
	var low_h: float = br.size.y * 0.16
	for i in range(bands):
		var a2: float = 0.26 * (1.0 - float(i) / bands)
		var y1: float = br.end.y - low_h * float(i + 1) / bands
		_snow_layer.draw_rect(Rect2(Vector2(br.position.x, y1), Vector2(br.size.x, ceilf(low_h / bands))), Color(0.88, 0.92, 0.97, a2))
	# nuvens em pixel passando devagar, metade por cima da borda de baixo
	for cl in _clouds:
		var w: float = float(_cloud_textures()[absi(int(cl[4])) % 5].get_width()) * S
		var x: float = br.position.x - w + fposmod(float(cl[0]) * (br.size.x + w * 2.0) + _snow_t * float(cl[3]) * br.size.x, br.size.x + w * 2.0)
		var y: float = br.end.y - 0.9 * _tile + float(cl[1])
		_draw_cloud(Vector2(x, y), w, S, int(cl[4]))

static var _cloud_texs: Array = []

# Nuvens em pixel art feitas uma vez: bolhas redondas somadas, corpo branco,
# sombra azulada embaixo e contorno de brilho em cima.
static func _cloud_textures() -> Array:
	if not _cloud_texs.is_empty():
		return _cloud_texs
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for k in range(5):
		var w: int = rng.randi_range(34, 58)
		var h: int = 18
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var puffs: Array = []
		var n: int = rng.randi_range(3, 5)
		for i in range(n):
			var cx: float = lerpf(6.0, w - 6.0, (float(i) + 0.5) / n) + rng.randf_range(-2.0, 2.0)
			var r: float = rng.randf_range(4.0, 7.5) * (1.0 - absf(float(i) / maxf(1.0, n - 1.0) - 0.5) * 0.6)
			puffs.append(Vector3(cx, h - 4.0 - r * 0.6, r))
		var base_y: float = h - 3.0
		for y in range(h):
			for x in range(w):
				var inside: bool = false
				for pf in puffs:
					if Vector2(x + 0.5 - pf.x, (y + 0.5 - pf.y) * 1.15).length() <= pf.z:
						inside = true
						break
				if y >= base_y - 1 and x > 3 and x < w - 4:
					inside = true
				if y > base_y:
					inside = false
				if inside:
					img.set_pixel(x, y, Color(0.96, 0.98, 1.0))
		# sombra embaixo e brilho em cima
		for x in range(w):
			var top: int = -1
			var bot: int = -1
			for y in range(h):
				if img.get_pixel(x, y).a > 0.5:
					if top < 0:
						top = y
					bot = y
			if top >= 0:
				img.set_pixel(x, top, Color(1, 1, 1))
				for yy in range(maxi(top + 1, bot - 1), bot + 1):
					img.set_pixel(x, yy, Color(0.76, 0.84, 0.92))
		_cloud_texs.append(ImageTexture.create_from_image(img))
	return _cloud_texs

func _draw_cloud(p: Vector2, _w: float, S: float, seed_i: int) -> void:
	var texs: Array = _cloud_textures()
	var tex: Texture2D = texs[absi(seed_i) % texs.size()]
	var sz: Vector2 = tex.get_size() * S
	_snow_layer.draw_texture_rect(tex, Rect2(_snap(p - Vector2(0, sz.y)), sz), false, Color(1, 1, 1, 0.62))

# Força do vento agora (0..1): rajadas que vêm e vão, nunca paradas.
func _wind_now() -> float:
	return 0.35 + 0.65 * pow(maxf(0.0, sin(_snow_t * 0.33 + 0.7)), 2.0)

func _draw_snow() -> void:
	if _embers_on:
		_draw_embers()
		return
	var S: float = float(_scale)
	var r: Rect2 = world_rect
	var wind: float = _wind_now()
	_draw_altitude_air(S)
	for f in _flakes:
		var depth: float = f[5]
		var spd: float = float(f[2]) * S
		var fall: float = _snow_t * spd
		# o vento empurra mais as de perto; o "vai e volta" deixa a queda menos reta
		var push: float = _snow_t * spd * (0.6 + 1.6 * wind) * (0.6 + depth) + sin(_snow_t * 0.9 + float(f[3])) * 6.0 * S
		var x: float = r.position.x + fposmod(float(f[0]) * r.size.x + push, r.size.x)
		var y: float = r.position.y + fposmod(float(f[1]) * r.size.y + fall, r.size.y)
		# neva mais forte quanto mais alto: no pé só uns 30% dos flocos aparecem
		if float(f[3]) / TAU > 0.3 + 0.7 * _altitude(y):
			continue
		var a: float = lerpf(0.45, 0.95, depth)
		draw_flake(_snow_layer, _snap(Vector2(x, y)), S, int(f[4]), Color(0.96, 0.98, 1.0, a))
	# rajadas: fiapos de neve cruzando a tela da esquerda para a direita
	for g in _gusts:
		var tex: Texture2D = g[0]
		var gsz: Vector2 = tex.get_size() * S
		var travel: float = r.size.x + gsz.x * 2.0
		var cycle: float = travel / (r.size.x * float(g[2]) * (0.6 + wind))
		var k: float = fposmod(_snow_t + float(g[3]) * cycle, cycle) / cycle
		var gx: float = r.position.x - gsz.x + k * travel
		var gy: float = r.position.y + float(g[1]) * r.size.y + sin(_snow_t * 0.7 + float(g[4])) * 4.0 * S
		var ga: float = clampf(sin(k * PI) * (0.4 + 0.6 * wind), 0.0, 1.0)
		_snow_layer.draw_texture_rect(tex, Rect2(_snap(Vector2(gx, gy)), gsz), false, Color(1, 1, 1, ga))

# Caldeira: brasas subindo devagar, piscando e apagando no alto; cinza caindo de lado.
func _draw_embers() -> void:
	var S: float = float(_scale)
	var r: Rect2 = world_rect
	# bolhas nos lagos de lava: nasce, cresce, estoura, some (e uma pausa)
	for b in _lava_bubbles:
		var fi: int = int(_snow_t * 6.0 * float(b[2]) + float(b[1])) % 10
		if fi < 4:
			var bt: Texture2D = _tex(BOARD_DIR + "casas/lava/bolha_%d" % (fi + 1), _dir)
			if bt != null:
				var bsz: Vector2 = bt.get_size() * S
				_snow_layer.draw_texture_rect(bt, Rect2(_snap(b[0] - bsz / 2.0), bsz), false)
	for f in _flakes:
		var depth: float = f[5]
		var spd: float = float(f[2]) * S
		var shape: int = int(f[4])
		if shape == 9:
			var y: float = r.position.y + fposmod(float(f[1]) * r.size.y - _snow_t * spd * 1.4, r.size.y)
			var x: float = r.position.x + fposmod(float(f[0]) * r.size.x + sin(_snow_t * 1.1 + float(f[3])) * 8.0 * S, r.size.x)
			var life: float = clampf((y - r.position.y) / r.size.y, 0.0, 1.0)   # 1 embaixo, 0 no alto
			var flick: float = 0.6 + 0.4 * sin(_snow_t * 7.0 + float(f[3]) * 3.0)
			var col := Color(1.0, 0.42 + 0.45 * (1.0 - life), 0.16, (0.25 + 0.6 * life) * flick)
			_snow_layer.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(S, S) * (2.0 if depth > 0.7 else 1.0)), col)
		else:
			var fy: float = r.position.y + fposmod(float(f[1]) * r.size.y + _snow_t * spd * 0.6, r.size.y)
			var fx: float = r.position.x + fposmod(float(f[0]) * r.size.x + _snow_t * spd * 0.5 + sin(_snow_t * 0.7 + float(f[3])) * 5.0 * S, r.size.x)
			draw_flake(_snow_layer, _snap(Vector2(fx, fy)), S, shape, Color(0.62, 0.58, 0.6, lerpf(0.25, 0.6, depth)))

func _process(delta: float) -> void:
	if _snow_layer != null:
		_snow_t += delta
		_snow_layer.queue_redraw()
	if _anim_on:
		var tick: int = int(_snow_t * ANIM_FPS)
		if tick != _anim_tick:
			_anim_tick = tick
			queue_redraw()
	if _swirls.is_empty():
		return
	_swirl_t += delta
	var f: int = int(_swirl_t * 6.0) % SWIRL_FRAMES
	if f != _swirl_frame:
		_swirl_frame = f
		queue_redraw()

# Centro do sprite de uma árvore cuja base do tronco está em `ground`.
# Deserto: a moldura de areia entra sobre as casas; sprites com base de areia
# (monólitos, torres...) ou detalhes miúdos que PISAM nessa faixa batiam com a
# areia da borda. Descarta a decoração cuja "pegada" (parte de baixo) toca a
# faixa; a parte alta de um sprite alto pode passar por cima, sem problema.
# Tira do mapa os enfeites que encostam em algum dos retângulos (mundo). Usado
# pelo desfiladeiro e pelo glaciar do Cume, que ocupam o chão no lugar deles.
func clear_decor_in(rects: Array) -> void:
	var kept: Array = []
	for d in _decor:
		var dtex: Texture2D = d[0]
		var dsz: Vector2 = dtex.get_size() * (float(d[3]) if d.size() > 3 else float(_scale))
		var drect := Rect2(d[1] - dsz / 2.0, dsz)
		var hit := false
		for r in rects:
			if (r as Rect2).intersects(drect):
				hit = true
				break
		if not hit:
			kept.append(d)
	_decor = kept
	queue_redraw()

func _clear_decor_from_frame_band() -> void:
	var S := float(_scale)
	var inner := _board_rect
	inner.position += Vector2(FRAME_BAND_SIDE, FRAME_BAND_TOP) * S
	inner.size -= Vector2(FRAME_BAND_SIDE * 2.0, FRAME_BAND_TOP + FRAME_BAND_BOTTOM) * S
	var kept: Array = []
	var big_feet: Array[Rect2] = []   # pegadas dos sprites grandes já aceitos
	for d in _decor:
		if d.size() > 3:
			kept.append(d)   # montanhas do Cume: já posicionadas inteiras dentro das casas
			continue
		var dtex: Texture2D = d[0]
		var dsz := dtex.get_size() * (float(d[3]) if d.size() > 3 else S)
		var drect := Rect2(d[1] - dsz / 2.0, dsz)
		var foot := Rect2(drect.position.x, drect.end.y - dsz.y * 0.35, dsz.x, dsz.y * 0.35)
		if not inner.encloses(foot):
			continue
		# Sprites grandes (monólitos, torres, ruínas) trazem uma base de areia:
		# duas bases não podem se sobrepor.
		if dsz.x >= LARGE_DECOR_NATIVE * S:
			var clash := false
			for bf in big_feet:
				if bf.intersects(foot.grow(8.0 * S)):
					clash = true
					break
			if clash:
				continue
			big_feet.append(foot)
		kept.append(d)
	_decor = kept

func _distance_to_walk(p: Vector2) -> float:
	var best := INF
	for c in _walk_cells:
		best = minf(best, p.distance_to(c))
	return best

func _add_walk_cell(g: Vector2i) -> void:
	var c := Vector2(g.x * _tile, g.y * _tile)
	if not _walk_cells.has(c):
		_walk_cells.append(c)

# O sprite (árvore, monólito, cristal grande...) cobriria alguma casa onde a peça anda?
func _covers_walk_cell(rect: Rect2) -> bool:
	var h := Vector2(_tile, _tile) * 0.36
	for c in _walk_cells:
		if Rect2(c - h, h * 2.0).intersects(rect):
			return true
	return false

# --- Respiro entre sprites grandes ------------------------------------------------
# Marcos e props grandes amontoados viravam uma "sopa" de sprites. Regras:
#  - em volta de um marco, nada grande a menos de LANDMARK_HALO casas;
#  - dois sprites grandes não podem ter as bases (metade de baixo) a menos de
#    BIG_GAP casas uma da outra;
#  - miudezas não ficam por cima de um sprite grande.
# A floresta fica de fora (a mata fechada é o visual dela).
const LANDMARK_HALO: float = 0.35
const MARK_REPEAT_GAP: float = 9.0   # casas (na vertical) entre dois marcos iguais
const BIG_GAP: float = 0.2
const BIG_NATIVE_PX: float = 12.0

func _decor_rect(d: Array) -> Rect2:
	var dk: float = float(d[3]) if d.size() > 3 else float(_scale)
	var sz: Vector2 = (d[0] as Texture2D).get_size() * dk
	return Rect2(d[1] - sz / 2.0, sz)

func _is_big_decor(d: Array) -> bool:
	if d.size() > 3:
		return true
	var ns: Vector2 = (d[0] as Texture2D).get_size()
	return maxf(ns.x, ns.y) >= BIG_NATIVE_PX and not (d[0] as Texture2D).resource_path.contains("/lagos/")

func _declutter_big_props() -> void:
	var bigs: Array[Rect2] = []      # retângulos inteiros dos grandes mantidos
	var feet: Array[Rect2] = []      # bases (metade de baixo) dos grandes mantidos
	var out: Array = []
	# marcos primeiro (sempre ficam), depois os grandes de baixo pra cima (os da frente têm prioridade)
	var order: Array = _decor.duplicate()
	order.sort_custom(func(a, b):
		var la: bool = a.size() > 3
		var lb: bool = b.size() > 3
		if la != lb:
			return la
		return a[2] > b[2])
	var smalls: Array = []
	for d in order:
		if not _is_big_decor(d):
			smalls.append(d)
			continue
		var r: Rect2 = _decor_rect(d)
		var ft := Rect2(r.position.x, r.position.y + r.size.y * 0.5, r.size.x, r.size.y * 0.5)
		if d.size() <= 3:
			var clash := false
			for f in feet:
				if f.grow(BIG_GAP * _tile).intersects(ft):
					clash = true
					break
			if clash:
				continue
		bigs.append(r)
		feet.append(ft)
		out.append(d)
	for d in smalls:
		if (d[0] as Texture2D).resource_path.contains("/lagos/"):
			out.append(d)   # fonte do lago de lava: faz parte do lago
			continue
		var inside := false
		for r in bigs:
			if r.grow(-0.05 * _tile).has_point(d[1]):
				inside = true
				break
		if not inside:
			out.append(d)
	_decor = out

# Montanhas grandes (Cume): sprite no dobro da escala, com a base apoiada numa
# casa do tabuleiro, inteiras dentro dele, sem cobrir trilha nem nó e sem se
# encostar. Tira os enfeites miúdos que ficariam escondidos embaixo delas.
func _place_mountains(rng: RandomNumberGenerator, node_points: Array, names: Array = [], div: float = 0.0, max_n: int = 7) -> void:
	if names.is_empty():
		names = _th.get("mountains", [])
		div = float(_th.get("mountain_div", 28.0))
	if names.is_empty():
		return
	var k: float = float(_scale * MOUNTAIN_SCALE_MUL)
	var cells: float = _board_rect.size.x * _board_rect.size.y / (_tile * _tile)
	var want: int = clampi(int(cells / div), 2, max_n)
	var placed: Array[Rect2] = _landmark_rects
	var start_n: int = placed.size()
	var used_names: Dictionary = {}
	var tries: int = 0
	while placed.size() - start_n < want and tries < 400:
		tries += 1
		var nm: String = String(names[rng.randi() % names.size()])
		# não repete um marco enquanto houver outro ainda não usado neste mapa
		if used_names.has(nm) and used_names.size() < names.size():
			continue
		var tex: Texture2D = _tex(BOARD_DIR + nm + ("_clara" if rng.randf() < 0.5 else "_escura"), _dir)
		if tex == null:
			continue
		var sz: Vector2 = tex.get_size() * k
		# mais perto das laterais (o meio é das trilhas)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var fx: float = 0.5 + side * rng.randf_range(0.18, 0.5)
		var ground := Vector2(_board_rect.position.x + fx * _board_rect.size.x, rng.randf_range(_board_rect.position.y + sz.y, _board_rect.end.y - 0.3 * _tile))
		var rect := Rect2(_snap(ground - Vector2(sz.x / 2.0, sz.y * 0.92)), sz)
		if not _board_rect.encloses(rect):
			continue
		# repetido só bem longe do mesmo marco (nada de dois iguais na mesma tela)
		var too_close := false
		for prev in used_names.get(nm, []):
			if absf((prev as Vector2).y - rect.get_center().y) < MARK_REPEAT_GAP * _tile:
				too_close = true
				break
		if too_close:
			continue
		# Cume: as montanhas grandes ficam mais no alto do mapa (perto do cume)
		if biome == "cume" and rng.randf() > 0.2 + 0.8 * _altitude(ground.y):
			continue
		# a "pegada" (metade de baixo) não pode cobrir trilha/nó; o pico pode passar por cima
		var foot := Rect2(rect.position.x + sz.x * 0.1, rect.position.y + sz.y * 0.45, sz.x * 0.8, sz.y * 0.55)
		# miolo do sprite (sprites largos e baixos, como o trilho de carvão, não podem ficar com altura negativa)
		var gy: float = minf(sz.x * 0.25, sz.y * 0.45)
		if _covers_walk_cell(foot) or _covers_walk_cell(rect.grow_individual(-sz.x * 0.25, -gy, -sz.x * 0.25, -gy)):
			continue
		# fora dos biomas de montanha-pico, só o topo (20%) pode passar por cima da trilha
		if biome != "cume" and _covers_walk_cell(rect.grow_individual(-sz.x * 0.08, -sz.y * 0.2, -sz.x * 0.08, 0.0)):
			continue
		var near_node := false
		for np in node_points:
			if rect.grow(0.6 * _tile).has_point(np[0]):
				near_node = true
				break
		if near_node:
			continue
		var clash := false
		# marcos de estrutura (fora do Cume) pedem mais respiro entre si e da lava
		var gap: float = 0.2 if biome == "cume" else 0.5
		for pr in placed:
			if pr.grow(gap * _tile).intersects(rect):
				clash = true
				break
		var body: Rect2 = foot if biome == "cume" else rect.grow_individual(0.0, -sz.y * 0.15, 0.0, 0.0)
		for lr in _lava_lake_rects:
			if lr.grow(0.25 * _tile).intersects(body):
				clash = true
				break
		if clash:
			continue
		placed.append(rect)
		if not used_names.has(nm):
			used_names[nm] = []
		(used_names[nm] as Array).append(rect.get_center())
		# remove o que ficaria escondido embaixo (árvores, props, miudezas) e abre um
		# respiro em volta: nada grande encostando no marco (evita amontoado de sprites)
		var keep: Array = []
		var halo: Rect2 = rect.grow(LANDMARK_HALO * _tile)
		for d in _decor:
			if d.size() > 3:
				keep.append(d)
				continue
			if foot.grow(0.2 * _tile).has_point(d[1]) or rect.has_point(d[1]):
				continue
			if _is_big_decor(d) and _decor_rect(d).intersects(halo):
				continue
			keep.append(d)
		_decor = keep
		_decor.append([tex, rect.get_center(), rect.end.y, k])

func _tree_center(tex: Texture2D, ground: Vector2) -> Vector2:
	return _snap(ground + Vector2(0.0, (0.5 - float(_th["tree_ground_y"])) * tex.get_height() * float(_scale)))

# A árvore cabe? Copa inteira dentro do tabuleiro, longe das trilhas e dos nós
# e sem encostar demais em outra árvore.
func _tree_fits(tex: Texture2D, ground: Vector2, node_points: Array, others: Array[Vector2]) -> bool:
	var sz: Vector2 = tex.get_size() * float(_scale)
	var ctr: Vector2 = _tree_center(tex, ground)
	var rect := Rect2(ctr - sz / 2.0, sz)
	# A copa pode passar da borda (fica por cima da moldura), mas
	# a base do tronco precisa estar bem dentro do tabuleiro.
	if not _board_rect.grow(-0.3 * _tile).has_point(ground):
		return false
	# E a árvore INTEIRA tem que caber na área desenhada (senão a parte que
	# sai do limite do mapa aparece cortada).
	var limit: Rect2 = _board_rect if _th["frame"] == "bordas" else world_rect
	if not limit.encloses(rect):
		return false
	for o in others:
		if o.distance_to(ground) < TREE_MIN_SPACING * _tile:
			return false
	# Pontos da copa e do tronco contra as trilhas.
	# (a distância às trilhas é decidida por _covers_walk_cell, que olha as casas reais da trilha)
	for np in node_points:
		var q := Vector2(clampf(np[0].x, rect.position.x, rect.end.x), clampf(np[0].y, rect.position.y, rect.end.y))
		if q.distance_to(np[0]) < TREE_NODE_CLEAR * _tile:
			return false
	return true

func _layout_seed(layers: Array) -> int:
	var s = ""
	for layer in layers:
		for node in layer:
			s += "%d,%d,%d;" % [int(node.position.x), int(node.position.y), int(node.type)]
	return hash(s)

func _jitter(rng: RandomNumberGenerator, amount: float) -> Vector2:
	return Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)) * _tile

func _snap(p: Vector2) -> Vector2:
	return (p / float(_scale)).round() * float(_scale)

func _distance_to_paths(p: Vector2, segments: Array) -> float:
	var best = INF
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var q = Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(q))
	return best

func _distance_to_nodes(p: Vector2, node_points: Array) -> float:
	var best = INF
	for np in node_points:
		best = minf(best, p.distance_to(np[0]))
	return best

func _draw() -> void:
	if _board_rect.size == Vector2.ZERO:
		return

	for t in _tiles:
		var tex: Texture2D = t[0]
		var rect: Rect2 = t[1]
		var half = rect.size / 2.0
		draw_set_transform(rect.position + half, 0.0, Vector2(-1.0 if t[2] else 1.0, -1.0 if t[3] else 1.0))
		draw_texture_rect(tex, Rect2(-half, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for lt in _lake_tiles:
		draw_texture_rect(_anim_tex(lt[0]), lt[1], false)
	for lo in _lake_overlays:
		draw_texture_rect(lo[0], lo[1], false)

	if biome == "cume":
		_draw_terraces()

	# Deserto: a areia acumulada da moldura entra 14 px (nativos) sobre as casas,
	# então vai ANTES da decoração (nada do mapa pode ficar escondido por ela).
	if _th["frame"] == "bordas":
		_draw_frame_sheet()
		if biome == "cume":
			_draw_altitude_marks()
	else:
		# Floresta: a moldura vai ANTES da decoração, então a copa das árvores
		# que passam da borda fica NA FRENTE dela (não por trás).
		_draw_frame()

	for c in _clearings:
		var ctex: Texture2D = c[0]
		var sz = ctex.get_size() * float(_scale)
		draw_texture_rect(ctex, Rect2(_snap(c[1]) - sz / 2.0, sz), false)

	for d in _decor:
		var dtex: Texture2D = d[0]
		var dk: float = float(d[3]) if d.size() > 3 else float(_scale)
		var dsz = dtex.get_size() * dk
		var drect := Rect2(d[1] - dsz / 2.0, dsz)
		if _anim_on:
			# quadro animado: mesma base e mesmo centro (a chaminé ganha fumaça por cima)
			var atex: Texture2D = _anim_tex(dtex)
			if atex != dtex:
				var asz: Vector2 = atex.get_size() * dk
				drect = Rect2(Vector2(drect.get_center().x - asz.x / 2.0, drect.end.y - asz.y), asz)
				dtex = atex
		# Deserto: corta no limite do tabuleiro (a areia da moldura fica por cima das
		# casas). Floresta: a copa passa por cima da moldura e só é cortada no limite
		# externo do mapa.
		var clip_rect: Rect2 = _board_rect if _th["frame"] == "bordas" else world_rect
		if clip_rect.encloses(drect):
			draw_texture_rect(dtex, drect, false)
		else:
			var clip := drect.intersection(clip_rect)
			if clip.size.x > 0.0 and clip.size.y > 0.0:
				var k := 1.0 / float(_scale)
				draw_texture_rect_region(dtex, clip, Rect2((clip.position - drect.position) * k, clip.size * k))

	_draw_swirls()

# Redemoinhos: 4 quadros de 8x8 numa faixa; vagam devagar pelo tabuleiro.
func _draw_swirls() -> void:
	if _swirl_tex == null or _swirls.is_empty():
		return
	var S: float = float(_scale)
	var f: int = maxi(_swirl_frame, 0)
	var sz: Vector2 = Vector2(SWIRL_FRAME_PX, SWIRL_FRAME_PX) * S
	for sw in _swirls:
		var base: Vector2 = sw[0]
		var ph: float = sw[1]
		var p := base + Vector2(sin(_swirl_t * 0.35 + ph) * 0.5 * _tile, cos(_swirl_t * 0.27 + ph) * 0.2 * _tile)
		p = _snap(p)
		var rect := Rect2(p - sz / 2.0, sz)
		draw_texture_rect_region(_swirl_tex, rect, Rect2(float(f * SWIRL_FRAME_PX), 0, float(SWIRL_FRAME_PX), float(SWIRL_FRAME_PX)))

# Moldura do deserto: uma folha 13x12 casas (354x332) que se repete casa a casa,
# como a da floresta, mas com as bordas por cima das casas (areia acumulada).
# Medidas nativas: laterais 8 px fora do tabuleiro (peça de 22), topo 10 px
# (peça de 22 de altura), base 10 px (peça de 26 de altura; parede mais grossa).
const SHEET_COLS: int = 13
const SHEET_ROWS: int = 12
const SHEET_MARGIN_X: float = 8.0
const SHEET_MARGIN_Y: float = 10.0
const SHEET_SIDE_W: float = 22.0
const SHEET_TOP_H: float = 22.0
const SHEET_BOT_H: float = 26.0
# Quanto a moldura entra sobre as casas (px nativos, + 1 de folga): lados, topo, base.
const FRAME_BAND_SIDE: float = 15.0
const FRAME_BAND_TOP: float = 13.0
const FRAME_BAND_BOTTOM: float = 17.0
# Largura nativa a partir da qual um sprite conta como "grande" (tem base de areia).
const LARGE_DECOR_NATIVE: float = 11.0
func _draw_frame_sheet() -> void:
	if _frame_tex == null:
		return
	if biome == "caldeira":
		# Basalto com grampos de bronze, todo FORA das casas, e lava escorrendo embaixo.
		BoardSkin._ensure_sheet(BoardSkin.SKIN_CALDEIRA)
		BoardSkin._draw_cume_frame(self, _board_rect.position, int(round(_board_rect.size.y / _tile)), int(round(_board_rect.size.x / _tile)), _tile, Color.WHITE, BoardSkin.SKIN_CALDEIRA, BoardSkin._CALDEIRA_DRIP)
		return
	if biome == "cume":
		# Pedra escura com neve em cima e sincelos embaixo, toda FORA das casas.
		BoardSkin._ensure_sheet(BoardSkin.SKIN_CUME)
		BoardSkin._draw_cume_frame(self, _board_rect.position, int(round(_board_rect.size.y / _tile)), int(round(_board_rect.size.x / _tile)), _tile, Color.WHITE)
		return
	if biome == "mina":
		# Mesma moldura do duelo: pedra lisa + vigas + cantoneiras de 18 px, sem
		# blocos que avançam sobre as casas.
		BoardSkin._ensure_sheet(BoardSkin.SKIN_MINE)
		var mcols := int(round(_board_rect.size.x / _tile))
		var mrows := int(round(_board_rect.size.y / _tile))
		BoardSkin._draw_mine_frame(self, _board_rect.position, mrows, mcols, _tile, Color.WHITE, 30.0)
		return
	var S := float(_scale)
	var tw := float(NATIVE_TILE)
	var W := float(_frame_tex.get_width())
	var H := float(_frame_tex.get_height())
	var outer := world_rect
	var cols := int(round(_board_rect.size.x / _tile))
	var rows := int(round(_board_rect.size.y / _tile))
	for i in range(cols):
		var sx := SHEET_MARGIN_X + tw * float(i % SHEET_COLS)
		var dx := _board_rect.position.x + float(i) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.position.y, _tile, SHEET_TOP_H * S), Rect2(sx, 0, tw, SHEET_TOP_H))
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.end.y - SHEET_BOT_H * S, _tile, SHEET_BOT_H * S), Rect2(sx, H - SHEET_BOT_H, tw, SHEET_BOT_H))
	for j in range(rows):
		var sy := SHEET_MARGIN_Y + tw * float(j % SHEET_ROWS)
		var dy := _board_rect.position.y + float(j) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(outer.position.x, dy, SHEET_SIDE_W * S, _tile), Rect2(0, sy, SHEET_SIDE_W, tw))
		draw_texture_rect_region(_frame_tex, Rect2(outer.end.x - SHEET_SIDE_W * S, dy, SHEET_SIDE_W * S, _tile), Rect2(W - SHEET_SIDE_W, sy, SHEET_SIDE_W, tw))
	# Cantos
	draw_texture_rect_region(_frame_tex, Rect2(outer.position, Vector2(SHEET_SIDE_W, SHEET_TOP_H) * S), Rect2(0, 0, SHEET_SIDE_W, SHEET_TOP_H))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.end.x - SHEET_SIDE_W * S, outer.position.y), Vector2(SHEET_SIDE_W, SHEET_TOP_H) * S), Rect2(W - SHEET_SIDE_W, 0, SHEET_SIDE_W, SHEET_TOP_H))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.position.x, outer.end.y - SHEET_BOT_H * S), Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S), Rect2(0, H - SHEET_BOT_H, SHEET_SIDE_W, SHEET_BOT_H))
	draw_texture_rect_region(_frame_tex, Rect2(outer.end - Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S, Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S), Rect2(W - SHEET_SIDE_W, H - SHEET_BOT_H, SHEET_SIDE_W, SHEET_BOT_H))

func _draw_frame() -> void:
	if _frame_tex == null:
		return
	var S = float(_scale)
	var fw = float(FRAME) * S
	var cols = int(round(_board_rect.size.x / _tile))
	var rows = int(round(_board_rect.size.y / _tile))
	var outer = world_rect
	var tw = float(NATIVE_TILE)
	var tex_w = float(_frame_tex.get_width())
	var tex_h = float(_frame_tex.get_height())

	for i in range(cols):
		var sx = float(FRAME) + tw * float(i % FRAME_SRC_COLS)
		var dx = _board_rect.position.x + float(i) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.position.y, _tile, fw), Rect2(sx, 0, tw, float(FRAME)))
		draw_texture_rect_region(_frame_tex, Rect2(dx, _board_rect.end.y, _tile, fw), Rect2(sx, tex_h - float(FRAME), tw, float(FRAME)))
	for j in range(rows):
		var sy = float(FRAME) + tw * float(j % FRAME_SRC_ROWS)
		var dy = _board_rect.position.y + float(j) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(outer.position.x, dy, fw, _tile), Rect2(0, sy, float(FRAME), tw))
		draw_texture_rect_region(_frame_tex, Rect2(_board_rect.end.x, dy, fw, _tile), Rect2(tex_w - float(FRAME), sy, float(FRAME), tw))

	# Cantos (12x12 nativos, sobrepõem 2 px do tabuleiro).
	var cs = float(FRAME_CORNER)
	var cd = cs * S
	draw_texture_rect_region(_frame_tex, Rect2(outer.position, Vector2(cd, cd)), Rect2(0, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.end.x - cd, outer.position.y), Vector2(cd, cd)), Rect2(tex_w - cs, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.position.x, outer.end.y - cd), Vector2(cd, cd)), Rect2(0, tex_h - cs, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(outer.end - Vector2(cd, cd), Vector2(cd, cd)), Rect2(tex_w - cs, tex_h - cs, cs, cs))
