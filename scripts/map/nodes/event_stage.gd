class_name EventStage
extends Control

# PALCO DE CUTSCENE dos eventos ("?" do mapa). No lugar da arte parada + roleta, o evento
# vira uma cena jogada no TABULEIRO DAS BATALHAS, estendido para fora da tela (o mundo é
# grande): cenário do bioma, a peça do jogador entrando aos saltos em diagonal, personagens
# e objetos com sprite próprio, falas numa caixa de diálogo e as escolhas dentro dela.
# O desfecho é encenado (suspense, moedas, susto, emboscada) em vez de sorteado numa roleta.
#
# Quem manda é o EventView: ele sorteia o evento, resolve os efeitos (_resolve) e chama
# aqui play_intro / show_choices / play_choice / play_result / narrate.
# A peça do jogador nunca fala (o Ascendente não fala): só os outros e o narrador.

signal advanced()
signal choice_made(choice_id: String)

const CELL: float = 96.0
const ROWS: int = 26                         # sobra bastante para baixo: o chão nunca acaba antes da tela
const COLS: int = 30
const ORIGIN_TILE := Vector2(15.5, 10.5)     # casa (0,0) do palco dentro do tabuleirão
const PXS: float = 3.0                        # escala dos sprites (pixel art nativo -> tela)
const ART: String = "res://assets/sprites/events/cena/"
const FOREST: String = "res://assets/sprites/biomas/floresta/tabuleiro/"
const LIB: String = "res://assets/sprites/events/biblioteca/"
# Biblioteca: a fachada fica na casa (1,-2); a porta está em (50,60) dentro do sprite.
const LIB_CELL := Vector2i(1, -2)
const LIB_DOOR_OFF := Vector2(50, 60)
# Interior da biblioteca (coordenadas do mundo, com o foco mais baixo na tela).
const ROOM_FOCUS := Vector2(1190, 500)
const ROOM_L: float = -680.0          # borda de dentro da parede esquerda
const ROOM_R: float = 680.0            # borda de dentro da parede direita
const ROOM_WALL_Y: float = -274.0      # pé da parede do fundo (estantes)
const ROOM_WINDOW_SLOT: int = 4        # qual módulo da parede do fundo é a janela
const BOX_RECT := Rect2(500, 792, 1380, 262)
const BAR_H: float = 64.0
const TEXT_W: float = 1150.0
const NARRATOR_TINT := Color(0.74, 0.80, 0.92)
# Quem fala: [nome mostrado, cor do nome, tinta da caixa]. A caixa muda de cor com o personagem.
const SPEAKERS: Dictionary = {
	"MERCADOR": ["O MERCADOR", Color("#b79cf0"), Color(0.72, 0.60, 1.0)],
	"FERREIRO": ["O FERREIRO", Color("#f0a268"), Color(1.0, 0.66, 0.42)],
	"VIAJANTE": ["O VIAJANTE", Color("#e6dcc0"), Color(0.95, 0.90, 0.76)],
	"CAÇADOR": ["O CAÇADOR", Color("#9fd07c"), Color(0.62, 0.92, 0.55)],
	"BRUXA": ["A BRUXA", Color("#c79af5"), Color(0.82, 0.55, 1.0)],
	"MONGE": ["O MONGE", Color("#f3c26a"), Color(1.0, 0.80, 0.42)],
	# deserto
	"CARAVANEIRO": ["O CARAVANEIRO", Color("#f0a860"), Color(1.0, 0.68, 0.38)],
	"NÔMADE": ["O NÔMADE", Color("#8fa8f0"), Color(0.50, 0.62, 1.0)],
	"ANTIQUÁRIO": ["O ANTIQUÁRIO", Color("#e8dcc0"), Color(0.92, 0.86, 0.70)],
	"ESCRIBA": ["O ESCRIBA", Color("#e6c06a"), Color(0.95, 0.78, 0.40)],
	# mina
	"MINEIRO": ["O MINEIRO", Color("#e3c25a"), Color(0.90, 0.78, 0.40)],
}

# Biomas do palco: casas do tabuleiro e cenário espalhado em volta da clareira.
const BIOMES: Dictionary = {
	"floresta": {"skin": "wood", "shade": Color(0.03, 0.07, 0.04, 0.20)},
	"deserto": {"skin": "desert", "shade": Color(0.10, 0.06, 0.02, 0.10)},
	"mina": {"skin": "mine", "shade": Color(0.03, 0.02, 0.07, 0.36)},
}
const DESERT: String = "res://assets/sprites/biomas/deserto/tabuleiro/"
const MINE: String = "res://assets/sprites/biomas/mina/"
# Sprites com quadro `_2` que NÃO tocam em loop: o segundo quadro é trocado na hora certa
# (olhos da esfinge acendendo, hieróglifos acendendo, cristal rachando, rodas do carrinho).
const NO_LOOP: Array = ["sphinx", "obelisk", "vein_cristal", "sarcophagus"]

# Roteiro de cada evento: quem está em cena (ator: [sprite, casa, é_peça, no_chão, escala]; no_chão = desenhado deitado no piso, centrado na casa) e as falas de abertura
# ([quem, texto]; quem = "" é narração). "target" é o ator para onde a peça olha/vai.
const SCRIPTS: Dictionary = {
	"chest": {
		"actors": {"chest": ["chest", Vector2i(1, -1), true]}, "target": "chest", "coins": true,
		"lines": [["", "Um cofre preso entre as raízes, meio engolido pela terra."], ["", "A tranca está podre de velha. Uma batida boa e ela cede. Se ninguém ouvir."]],
	},
	"merchant": {
		"actors": {"stall": ["merchant_stall", Vector2i(2, -2), false], "lantern": ["lantern", Vector2i(3, -1), false], "goods": ["merchant_goods", Vector2i(1, 0), false, true], "npc": ["merchant", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["MERCADOR", "Psiu. Aqui."], ["MERCADOR", "Quando o mundo rachou, choveu carta de tudo que é ilha. Eu juntei umas."], ["MERCADOR", "Compro e vendo, sem perguntas."]],
	},
	"altar": {
		"actors": {"runes": ["altar_runes", Vector2i(1, -1), false, true], "altar": ["altar", Vector2i(1, -1), true]}, "target": "altar",
		"lines": [["", "Um altar de pedra coberto de musgo, com uma runa que pulsa fraca."], ["", "Antes da Rachadura, cada lugar guardava as suas Leis em altares assim. Este ainda tem um pedaço de uma, esperando uma troca."]],
	},
	"forge": {
		"actors": {"forge": ["forge", Vector2i(3, -1), false], "anvil": ["anvil", Vector2i(2, -1), true], "hammer": ["hammer", Vector2i(1, 0), false, true], "npc": ["smith", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["FERREIRO", "Fogo bom, bigorna boa."], ["FERREIRO", "Por umas moedas eu bato numa carta sua até ela virar coisa melhor. Ou pisa no fole pra mim, que eu pago."]],
	},
	"library": {
		# cena em dois atos (ver _library_intro): fachada no meio do mato e depois o salão por dentro
		"actors": {}, "target": "tome",
		"lines_out": [["", "Uma biblioteca de pedra no meio do mato, com hera até o telhado."], ["", "A porta range e se abre sozinha. Lá dentro, uma luz azul e fria."]],
		"lines": [["", "Lá dentro tudo parou há séculos. Páginas pelo chão, velas derretidas, estantes até o teto."], ["", "No meio do salão, um tomo preso por correntes treme sozinho."]],
	},
	"traveler": {
		"actors": {"bag": ["traveler_bag", Vector2i(2, -1), false, true], "npc": ["traveler", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["VIAJANTE", "Ei... me ajuda. Uns bandidos me pegaram na trilha."], ["VIAJANTE", "Racharam a minha borda. Umas moedas pro remendo e eu te dou o melhor que tenho na bolsa."]],
	},
	"camp": {
		# barracas grandes (escala 2: cada uma ocupa umas 2 casas de largura)
		"actors": {"tent": ["camp_barraca_grande", Vector2i(0, -2), false, false, 2.0], "tent2": ["camp_barraca_media", Vector2i(3, -2), false, false, 2.0],
			"tent3": ["camp_barraca_pequena", Vector2i(-3, -1), false, false, 2.0], "tarp": ["camp_lona", Vector2i(4, 1), false, false, 2.0],
			"log": ["camp_tora", Vector2i(2, 0), false, true, 2.0], "pack": ["camp_pack", Vector2i(-1, -1), false, false, 1.5],
			"camp": ["camp_fogueira", Vector2i(1, -1), false, false, 2.0]}, "target": "camp", "cam": Vector2(0, -120),
		"lines": [["", "Um acampamento largado às pressas. A fogueira ainda está morna."], ["", "As mochilas ficaram. Os donos podem voltar a qualquer momento."]],
	},
	"fountain": {
		"actors": {"fountain": ["fountain", Vector2i(1, -1), true]}, "target": "fountain",
		"lines": [["", "Uma fonte de pedra no meio do nada, com uma água que brilha por conta própria."], ["", "No fundo, moedas de quem fez pedidos antes. Dizem que às vezes ela atende."]],
	},
	"mushrooms": {
		"actors": {"ring": ["mushrooms", Vector2i(1, -1), false, true]}, "target": "ring",
		"lines": [["", "Um círculo perfeito de cogumelos vermelhos."], ["", "Lá de dentro vêm umas risadinhas. Dizem que quem pisa no meio dança até o sol nascer."]],
	},
	"hunter": {
		"actors": {"bow": ["bow", Vector2i(2, -2), false], "quiver": ["quiver", Vector2i(3, -1), false], "npc": ["hunter", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["CAÇADOR", "Parado! ...Ah. É só uma peça perdida."], ["CAÇADOR", "Troco uma carta sua por outra, se pagar. Ou a gente resolve no tabuleiro, se tiver coragem."]],
	},
	"witch": {
		"actors": {"pot": ["cauldron", Vector2i(2, -1), true], "npc": ["witch", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["BRUXA", "Chegou na hora. A poção acabou de ficar pronta."], ["BRUXA", "Já tentaram juntar o que não cabe junto. Você sabe o preço, eu sei também. Só nenhum de nós lembra quanto foi."], ["BRUXA", "Enfim. Quer provar? Não garanto nada. Ou leva umas ervas, que são mais seguras e mais sem graça."]],
	},
	"monk": {
		"actors": {"tree": ["monk_tree", Vector2i(1, -2), false], "scroll": ["scroll_roxo", Vector2i(2, 0), false, true], "scroll2": ["scroll_verde", Vector2i(0, -2), false, true],
			"scroll3": ["scroll_amarelo", Vector2i(3, -1), false, true], "scroll4": ["scroll_vermelho", Vector2i(-1, -1), false, true], "scroll5": ["scroll", Vector2i(2, -3), false, true], "npc": ["monk", Vector2i(1, -1), true]}, "target": "npc",
		"lines": [["MONGE", "..."], ["MONGE", "Quem ouviu o que ele disse nunca mais fez a mesma pergunta."], ["MONGE", "Suas Leis podiam ser melhores. Quer que eu reescreva uma? Ou me ajude com o jardim, que as pedras não se arrumam sozinhas."]],
	},
	# ------------------------------------------------------------- deserto
	"mirage": {
		"actors": {"pond": ["mirage_lagoa", Vector2i(1, -2), false, true, 1.5], "palm": ["mirage_palmeira", Vector2i(3, -2), false, false, 1.3],
			"ruin": ["mirage_ruina", Vector2i(-1, -3), false, false, 1.3], "bones": ["mirage_ossos", Vector2i(2, 0), false, true], "hole": ["mirage_buraco", Vector2i(3, -1), false, true]},
		"target": "pond",
		"lines": [["", "Uma lagoa tremendo lá no horizonte, bonita demais pra ser real."], ["", "Onde o ar treme, a areia parece mais fofa. Talvez a miragem esteja escondendo alguma coisa."]],
	},
	"sarcophagus": {
		"actors": {"sarc": ["sarcophagus", Vector2i(1, -1), false, false, 1.5], "cold": ["sarcophagus_frio", Vector2i(1, -1), false, true],
			"vases": ["vasos_oferenda", Vector2i(3, -1), false, false, 1.2], "dune": ["duna_pequena", Vector2i(-2, -2), false, false, 1.5]},
		"target": "sarc",
		"lines": [["", "Um sarcófago de pedra meio enterrado, com a tampa torta."], ["", "Sai um friozinho da fresta. As oferendas ainda estão nos vasos, e tem ouro brilhando lá dentro."]],
	},
	"caravan": {
		"actors": {"tent": ["caravan_tenda", Vector2i(3, -2), false, false, 1.6], "camel": ["camelo_deitado", Vector2i(-1, -2), false, false, 1.5],
			"camel2": ["camelo_em_pe", Vector2i(5, 0), false, false, 1.5], "chests": ["caravan_baus", Vector2i(2, 0), false, false, 1.2],
			"cards": ["caravan_cartas", Vector2i(1, 0), false, true], "npc": ["caravan_npc", Vector2i(1, -1), true]},
		"target": "npc",
		"lines": [["CARAVANEIRO", "Ô de casa! Chega mais, que a sombra é de graça."], ["CARAVANEIRO", "Na frente, o maço barato. No baú do fundo, as boas. E não, não são roubadas."]],
	},
	"sphinx": {
		"actors": {"sphinx": ["sphinx", Vector2i(1, -2), false, false, 1.5], "signs": ["sphinx_simbolos", Vector2i(1, 0), false, true, 1.2]},
		"target": "sphinx", "cam": Vector2(0, -90),
		"lines": [["", "Uma esfinge de olho vazio fecha o caminho. Na frente dela, três placas: uma ampulheta, uma sombra, uma boca fechada."], ["", "\"Eu pergunto: o que foi feito com tudo que foi guardado? Ninguém responde. Ele também nunca respondeu.\""], ["", "\"Você também não vai responder. Então pise numa placa e pague o preço dela.\""]],
	},
	"sandstorm": {
		"actors": {"tower": ["torre_ruina", Vector2i(2, -2), false, false, 1.5], "dune": ["duna_pequena", Vector2i(-2, -1), false, false, 1.5],
			"dune2": ["duna_pequena", Vector2i(5, 1), false, false, 1.3], "loot": ["tesouro_desenterrado", Vector2i(0, -2), false, true]},
		"target": "tower", "cam": Vector2(0, -80), "storm": true,
		"lines": [["", "O céu virou uma parede laranja."], ["", "Tem uma torre em ruínas logo ali. O vento pode desenterrar um tesouro, ou te enterrar."]],
	},
	"nomad": {
		"actors": {"rug": ["nomad_tapete", Vector2i(2, 0), false, true, 1.2], "fire": ["nomad_fogueira", Vector2i(3, -1), false],
			"camel": ["camelo_deitado", Vector2i(0, -3), false, false, 1.5], "coin": ["nomad_moeda", Vector2i(2, -2), false], "npc": ["nomad", Vector2i(1, -1), true]},
		"target": "npc",
		"lines": [["NÔMADE", "..."], ["NÔMADE", "Troco carta por um preço bom."], ["NÔMADE", "Mas respeito, só no tabuleiro. O tapete está estendido, se quiser."]],
	},
	"relics": {
		"actors": {"stall": ["relics_toldo", Vector2i(2, -2), false, false, 1.5], "amulets": ["relics_amuletos", Vector2i(1, 0), false, true, 1.2],
			"urn": ["relics_urna", Vector2i(3, -1), false, false, 1.3], "npc": ["relics_npc", Vector2i(1, -1), true]},
		"target": "npc",
		"lines": [["ANTIQUÁRIO", "Hm? Um cliente. Faz tempo."], ["ANTIQUÁRIO", "Amuleto, carta de tumba... Compro o que você tiver também. Não pergunto de onde veio."]],
	},
	"obelisk": {
		"actors": {"obelisk": ["obelisk", Vector2i(1, -2), false, false, 1.2], "base": ["obelisk_base", Vector2i(1, -1), false, false, 1.2]},
		"target": "obelisk", "cam": Vector2(0, -110),
		"lines": [["", "Um obelisco coberto de hieróglifos, com oferendas velhas aos pés."], ["", "Como os altares da mata, ele guarda um pedaço de uma Lei perdida. E pede uma carta em troca."]],
	},
	"scribe": {
		"actors": {"rolls": ["scribe_rolos", Vector2i(2, -2), false, false, 1.3], "desk": ["scribe_mesa", Vector2i(2, -1), false, false, 1.2],
			"p1": ["papiro_1", Vector2i(0, -1), false, true], "p2": ["papiro_2", Vector2i(3, 0), false, true], "p3": ["papiro_3", Vector2i(1, 0), false, true],
			"npc": ["scribe", Vector2i(1, -1), true]},
		"target": "npc",
		"lines": [["ESCRIBA", "Suas Leis foram escritas com pressa. Dá pra ver daqui."], ["ESCRIBA", "Eu anotava tudo certinho, sabe. Antes de ele pedir pra eu parar de anotar."], ["ESCRIBA", "Reescrevo uma das suas, se o preço for justo. Ou me ajude a arrumar esses papiros."]],
	},
	"oasis": {
		"actors": {"pond": ["oasis_lagoa", Vector2i(1, -1), false, true, 1.4], "palm": ["palmeira_1", Vector2i(-1, -2), false, false, 1.3],
			"palm2": ["palmeira_2", Vector2i(3, -2), false, false, 1.3], "ribbons": ["oasis_fitas", Vector2i(3, 0), false]},
		"target": "pond",
		"lines": [["", "Uma lagoa quietinha no meio das palmeiras, com um céu mais azul que o de verdade."], ["", "Na margem, uma estaca cheia de fitas e moedas que outros viajantes deixaram."]],
	},
	"bandits": {
		"actors": {"tent": ["bandits_tenda", Vector2i(1, -2), false, false, 1.6], "fire": ["bandits_fogueira", Vector2i(-1, -1), false, false, 1.3],
			"camel": ["camelo_amarrado", Vector2i(4, -1), false, false, 1.5], "bags": ["bandits_sacos", Vector2i(2, 0), false, false, 1.2],
			"sword": ["cimitarra", Vector2i(3, -2), false]},
		"target": "tent", "cam": Vector2(0, -60),
		"lines": [["", "Tenda rasgada, fogueira apagada, camelo amarrado."], ["", "Os donos saíram agorinha e deixaram os sacos abertos."]],
	},
	# ---------------------------------------------------------------- mina
	"crystal_vein": {
		"actors": {"vein": ["vein_cristal", Vector2i(1, -2), false, false, 1.5], "chips": ["vein_lascas", Vector2i(0, -1), false, true],
			"pick": ["picareta", Vector2i(2, 0), false, true], "rubble": ["desabamento", Vector2i(2, -1), false, false, 1.4]},
		"target": "vein", "cam": Vector2(0, -80),
		"lines": [["", "Um cristal do tamanho de uma porta cresce da parede, brilhando em violeta."], ["", "Dá pra ouvir ele estalando por dentro. Vale uma fortuna. Ou vale o teto."]],
	},
	"mirror_shard": {
		"actors": {"mirror": ["mirror_shard", Vector2i(1, -1), false, false, 1.5], "shards": ["cacos", Vector2i(2, 0), false, true]},
		"target": "mirror",
		"lines": [["", "Um espelho de cristal rachado de ponta a ponta."], ["", "O seu reflexo se mexe um instante depois de você. Como se estivesse pensando."]],
	},
	"echo_miner": {
		"actors": {"stall": ["miner_banca", Vector2i(2, 0), false, true, 1.2], "lamp": ["lanterna_mina", Vector2i(0, -1), false],
			"pick": ["picareta", Vector2i(3, -1), false, true], "npc": ["miner", Vector2i(1, -1), true]},
		"target": "npc",
		"lines": [["MINEIRO", "Eu vi você chegando."], ["MINEIRO", "Duas vezes. Aqui embaixo o eco chega antes da gente."], ["MINEIRO", "Quer trocar uma carta? Estão todas viradas, é mais justo assim. Ou escuta a parede comigo."]],
	},
	"ore_cart": {
		"actors": {"cart": ["carrinho", Vector2i(2, -1), false, false, 1.4], "lever": ["alavanca", Vector2i(0, -2), false, false, 1.3],
			"ore": ["minerio_espalhado", Vector2i(3, 0), false, true]},
		"target": "cart", "rails": true,
		"lines": [["", "Um carrinho de minério cheio de ouro, descendo o trilho sozinho."], ["", "Do lado do trilho, uma alavanca de freio. Nenhum mineiro por perto."]],
	},
	"echo_chamber": {
		"actors": {"wave": ["onda_eco", Vector2i(1, -1), false, true, 2.0], "stone": ["echo_pedra", Vector2i(1, -1), false, false, 1.5],
			"c1": ["cristal_espelho_3", Vector2i(-2, -2), false, false, 1.3], "c2": ["cristal_espelho_2", Vector2i(4, -2), false, false, 1.3],
			"c3": ["cristal_espelho_1", Vector2i(-3, 1), false], "c4": ["cristal_espelho_2", Vector2i(4, 1), false], "c5": ["cristal_espelho_1", Vector2i(1, -4), false, false, 1.3]},
		"target": "stone", "cam": Vector2(0, -60),
		"lines": [["", "Uma caverna redonda de paredes espelhadas. Todo som volta duas vezes, de lugares diferentes."], ["", "No centro, uma pedra com uma fenda. Lá de dentro vem o eco de uma batida que ninguém deu."]],
	},
	"prospectors": {
		"actors": {"tarp": ["prosp_lona", Vector2i(1, -2), false, false, 1.5], "lamp": ["prosp_lanterna", Vector2i(-1, -1), false],
			"pot": ["prosp_panela", Vector2i(3, -1), false, false, 1.2], "picks": ["prosp_picaretas", Vector2i(4, -2), false, false, 1.2],
			"bags": ["prosp_sacos", Vector2i(2, 0), false, false, 1.2], "sh1": ["sombra_gente_1", Vector2i(-3, -3), false, false, 1.4], "sh2": ["sombra_gente_2", Vector2i(6, -3), false, false, 1.4]},
		"target": "bags", "cam": Vector2(0, -60),
		"lines": [["", "Lanterna acesa, picaretas encostadas, uma panela de sopa quente."], ["", "Nenhum garimpeiro por perto. Só umas sombras paradas no fundo da galeria."]],
	},
	"mirror_altar": {
		"actors": {"altar": ["mirror_altar", Vector2i(1, -2), false, false, 1.5], "hand": ["mirror_mao", Vector2i(1, -1), false],
			"v1": ["vela_cristal", Vector2i(-1, -1), false, false, 1.2], "v2": ["vela_cristal", Vector2i(3, -1), false, false, 1.2]},
		"target": "altar", "cam": Vector2(0, -80),
		"lines": [["", "Um altar de cristal com uma face espelhada. Nela, uma versão sua mais velha, gasta, com a borda rachada."], ["", "Uma mão de cristal sai do espelho e se abre, pedindo uma carta. Em troca, promete uma Lei."]],
	},
}

# Frase curta que acompanha a ação de cada escolha (evento.escolha). Sem entrada = sem frase.
const BEATS: Dictionary = {
	"chest.pry": "Você pula em cima da tranca...",
	"library.tome": "Você empurra o tomo. As correntes rangem...",
	"library.read": "Você vira as páginas que ainda dá pra ler, uma por uma.",
	"traveler.rob": "Você mexe na bolsa dele enquanto ele geme...",
	"traveler.help": "Você deixa as moedas do lado dele.",
	"camp.search": "Você revira as mochilas...",
	"camp.setup": "Você se esconde atrás da barraca e espera.",
	"fountain.drink": "Você pula na água...",
	"fountain.wish": "Você empurra uma moeda pra dentro da fonte...",
	"mushrooms.eat": "Você pula pro meio do círculo...",
	"mushrooms.pick": "Você colhe os cogumelos da borda, sem pisar no círculo.",
	"witch.potion": "A bruxa derrama uma concha da poção em cima de você...",
	"altar.offer": "Você deixa uma carta sobre a pedra.",
	"altar.pray": "Você descansa ao pé do altar até a runa se apagar.",
	"forge.forge": "O martelo desce três vezes.",
	"forge.help": "Você pula no fole, uma vez, duas, cem...",
	"hunter.challenge": "O caçador sorri e arma o tabuleiro.",
	"monk.alms": "Você empurra as pedras do jardim de volta pro lugar.",
	"mirage.run": "Você corre até a lagoa...",
	"mirage.dig": "Você cava onde o ar treme.",
	"sarcophagus.open": "Você empurra a tampa...",
	"sarcophagus.loot": "Você recolhe as oferendas, sem encostar na tampa.",
	"sphinx.time": "Você pula na placa da ampulheta. A areia para de correr...",
	"sphinx.shadow": "Você pula na placa da sombra. Os olhos da esfinge se acendem...",
	"sphinx.silence": "Você pula na placa da boca fechada e espera.",
	"sandstorm.cross": "Você entra na parede de areia...",
	"sandstorm.shelter": "Você se encolhe dentro da torre até o vento passar.",
	"nomad.challenge": "O nômade guarda a moeda e estende o tapete.",
	"obelisk.offer": "Você deixa uma carta aos pés do obelisco.",
	"obelisk.pray": "Você descansa na sombra fresca do obelisco.",
	"scribe.alms": "Você empilha os papiros em ordem.",
	"oasis.drink": "Você pula na lagoa...",
	"oasis.wish": "Você empurra uma moeda pra dentro da água azul...",
	"bandits.search": "Você revira os sacos...",
	"bandits.setup": "Você se esconde atrás da duna e espera.",
	"crystal_vein.pry": "Você bate no cristal com toda a força...",
	"crystal_vein.chip": "Você junta as lascas do chão.",
	"mirror_shard.gaze": "Você encara o reflexo. Ele para de te imitar...",
	"mirror_shard.cover": "Você puxa um pano velho por cima do espelho.",
	"echo_miner.listen": "Você encosta na parede com ele e escuta.",
	"ore_cart.brake": "Você pula na alavanca...",
	"ore_cart.sift": "Você pula na carga enquanto ela passa...",
	"echo_chamber.shout": "Você bate na pedra. O som vai e volta de dois lados...",
	"echo_chamber.whisper": "Você empurra uma pedrinha pra dentro da fenda...",
	"echo_chamber.silence": "Você não se mexe. O eco também não.",
	"prospectors.search": "Você revira os sacos...",
	"prospectors.setup": "Você apaga a lanterna e espera no escuro.",
	"mirror_altar.offer": "Você empurra uma carta até a mão de cristal...",
	"mirror_altar.gaze": "Você só olha. Ela olha de volta.",
}

var title: String = ""
var skip: bool = false                 # testes: sem animação nem espera
var cam: Vector2 = Vector2.ZERO        # deslocamento da câmera (px do mundo)
var focus: Vector2 = Vector2(1190, 430)   # ponto da tela onde fica a casa (0,0)
var actors: Dictionary = {}            # id -> {tex, pos, z, scale, alpha, piece, shake, emote, emote_t, flip}
var _props: Array = []                 # cenário: [tex, pos(mundo, pé), espelhado]
var _clutter: Array = []               # miudezas do chão: [tex, pos]
var _parts: Array = []                 # partículas: {pos, vel, life, max, tex, col, size, grav}
var _t: float = 0.0
var _target: String = ""
var _talker: String = ""               # ator que está falando agora (boca mexendo)
var _interior: bool = false            # biblioteca: cenário trocado para o salão
var _path_tiles: Array = []            # casas de chão trocadas (caminho de lajotas): [casa, textura]
var _ambient_t: float = 0.0
var biome: String = "floresta"
var _event_id: String = ""
var _storm: bool = false               # tempestade de areia passando pela cena
var _tex: Dictionary = {}

var ui: CanvasLayer
var box: PanelContainer
var portrait: TextureRect
var continue_btn: Button
var name_plate: Label
var text_label: Label

var choices_row: HBoxContainer
var footer: HBoxContainer              # o EventView pendura aqui o botão de seguir/lutar
var preview_anchor: CenterContainer    # o EventView pendura aqui as cartas/Leis ganhas
var _flash: ColorRect
var _full_text: String = ""
var _shown: float = 0.0
var _typing: bool = false
var _waiting: bool = false
var _voice_t: float = 0.0

static func supports(event: Dictionary) -> bool:
	return SCRIPTS.has(String(event.get("id", ""))) and BIOMES.has(String(event.get("biome", "floresta")))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_scenery()
	_build_ui()
	# a peça do jogador começa fora da tela, embaixo à esquerda
	_add_actor("player", PieceSkin.player_texture(), Vector2i(-6, 6), true)

func _tx(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[path]

func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL

func _add_actor(id: String, tex: Texture2D, cell: Vector2i, piece: bool, flat: bool = false) -> void:
	actors[id] = {"id": id, "tex": tex, "pos": cell_pos(cell), "z": 0.0, "scale": 1.0, "alpha": 1.0, "piece": piece, "flat": flat,
		"shake": Vector2.ZERO, "emote": "", "emote_t": 0.0, "flip": false}

# Sprite de cena com quadros extras: `<nome>_fala.png` (boca aberta enquanto fala) e
# `<nome>_2.png` (segundo quadro em loop: fogo, poção, água).
func _add_scene_actor(id: String, sprite: String, cell: Vector2i, piece: bool, flat: bool = false) -> void:
	_add_actor(id, _tx(ART + sprite + ".png"), cell, piece, flat)
	var talk := _tx(ART + sprite + "_fala.png")
	if talk != null:
		actors[id]["talk"] = talk
	actors[id]["sprite"] = sprite
	var f2 := _tx(ART + sprite + "_2.png")
	if f2 != null and not (sprite in NO_LOOP):
		var fr: Array = [actors[id]["tex"], f2]
		var f3 := _tx(ART + sprite + "_3.png")
		if f3 != null:
			fr.append(f3)
		actors[id]["frames"] = fr
		actors[id]["fp"] = 0.34

# Moedas soltas espalhadas em volta da base do cofre: mais juntas perto dele e
# rareando para fora, algumas em montinhos, nenhuma no caminho da peça.
func _scatter_coins(center: Vector2) -> void:
	var tex := _tx(ART + "coin.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var base: Vector2 = center + Vector2(0, CELL * 0.12)
	var n: int = 0
	var tries: int = 0
	while n < 22 and tries < 300:
		tries += 1
		var ang: float = rng.randf() * TAU
		var r: float = lerpf(0.6, 2.0, pow(rng.randf(), 0.9))
		var off := Vector2(cos(ang) * r * CELL * 0.95, sin(ang) * r * CELL * 0.5)
		if off.y < -CELL * 0.18 and absf(off.x) < CELL * 0.55:
			continue   # escondida atrás do cofre
		var p: Vector2 = base + off
		var path_d: float = absf(p.x + p.y) / sqrt(2.0)
		if path_d < CELL * 0.45 and p.y > 0.0:
			continue   # no caminho por onde a peça chega
		var id: String = "coin%d" % n
		_add_actor(id, tex, Vector2i.ZERO, false, true)
		actors[id]["pos"] = p.round()
		n += 1
		# às vezes um montinho: uma segunda moeda quase em cima
		if rng.randf() < 0.3 and n < 22:
			var id2: String = "coin%d" % n
			_add_actor(id2, tex, Vector2i.ZERO, false, true)
			actors[id2]["pos"] = (p + Vector2(rng.randf_range(-9, 9), -6)).round()
			n += 1

# Textura do ator neste instante (quadro animado / boca aberta).
func _actor_tex(a: Dictionary) -> Texture2D:
	var t: Texture2D = a["tex"]
	if a.has("frames"):
		var fr: Array = a["frames"]
		t = fr[int(_t / float(a["fp"])) % fr.size()]
	if a.has("talk") and _talker == String(a.get("id", "")) and _typing and int(_t * 9.0) % 2 == 1:
		t = a["talk"]
	return t

# ------------------------------------------------------------------ cenário ----

func _load_list(base: String, names: Array) -> Array:
	var out: Array = []
	for n in names:
		var t := _tx(base + String(n) + ".png")
		if t != null:
			out.append(t)
	return out

func _build_scenery(keep_free: Rect2i = Rect2i()) -> void:
	_props.clear()
	_clutter.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var trees: Array = []
	var bushes: Array = []
	var small: Array = []
	var tree_k: float = 0.34
	match biome:
		"deserto":
			var mono: Array = []
			for i in range(1, 15):
				mono.append("monolitos/monolito_%d_chao_%s" % [i, "claro" if i % 2 == 1 else "escuro"])
			trees = _load_list(DESERT, mono) + _load_list(DESERT, ["torres/torre_enterrada_1_chao_claro", "torres/torre_enterrada_2_chao_escuro",
				"torres/torre_enterrada_3_chao_claro", "torres/torre_enterrada_4_chao_escuro", "torres/torre_enterrada_5_chao_escuro", "torres/torre_enterrada_6_chao_claro"])
			bushes = _load_list(DESERT, ["ruinas/coluna_quebrada_chao_claro", "ruinas/laje_inclinada_chao_escuro", "ruinas/bloco_de_ruina", "pedras/pedra_grande_2",
				"pedras/pedra_grande_3", "pedras/rochas_grupo", "vegetacao/arbusto_1_chao_escuro", "vegetacao/arbusto_4_chao_claro", "vegetacao/tufo_seco_alto", "vegetacao/cacto_mini"])
			small = _load_list(DESERT, ["vegetacao/tufo_seco_1", "vegetacao/tufo_seco_2", "vegetacao/capim_ralo", "vegetacao/flor_do_deserto", "vegetacao/ondinha_de_areia",
				"pedras/seixos", "pedras/pedrinha", "pedras/pedra_media_1", "ossos_e_restos/osso", "ossos_e_restos/cranio_pequeno", "ossos_e_restos/caco_de_vaso",
				"ossos_e_restos/escaravelho", "poeira/areia_soprada_1", "poeira/areia_soprada_2", "folhas/folha_seca_1", "ruinas/hieroglifo_no_chao"])
			tree_k = 0.16
		"mina":
			var cr: Array = []
			for n in ["1_violeta_alto", "2_violeta_largo", "3_gelo_pequeno", "4_gelo_alto", "5_esmeralda", "6_misto"]:
				cr.append("tabuleiro/cristais/cristal_%s_clara" % n)
				cr.append("tabuleiro/cristais/cristal_%s_escura" % n)
			trees = _load_list(MINE, cr)
			bushes = _load_list(MINE, ["gruta/rocha_solta_4", "gruta/rocha_solta_3", "tabuleiro/cristais/cristal_3_gelo_pequeno_clara", "tabuleiro/cristais/cristal_5_esmeralda_escura"])
			small = _load_list(MINE, ["gruta/rocha_solta_1", "gruta/rocha_solta_2", "gruta/rocha_solta_3"])
			tree_k = 0.22
		_:
			for i in range(1, 15):
				var t := _tx(FOREST + "arvores/arvore_copa_%d.png" % i)
				if t != null:
					trees.append(t)
			bushes = _load_list(FOREST, ["arvores/arbusto_1", "arvores/arbusto_3", "arvores/arbusto_5", "arvores/arbusto_7", "vegetacao/moita_grande", "vegetacao/samambaia_grande", "vegetacao/moita_frutos"])
			small = _load_list(FOREST, ["pedras/pedra_grande", "pedras/rochas_grupo", "pedras/pedra_musgo", "madeira/tronco_caido", "madeira/toco_em_pe", "madeira/tora_deitada",
				"cogumelos/cogumelos_duplo", "vegetacao/flor_branca", "vegetacao/flor_vermelha", "vegetacao/tufo_grama_escuro_alto", "vegetacao/trevo", "folhas/folhas_mistas", "pedras/seixos"])
	# A clareira da cena (em volta da casa 0,0 e o caminho por onde a peça entra) fica livre.
	for cy in range(-9, 8):
		for cx in range(-14, 15):
			var c := Vector2i(cx, cy)
			var d: float = Vector2(float(cx) * 0.8, float(cy)).length()
			var on_path: bool = absi(cx + cy) <= 1 and cx <= 0 and cy >= 0
			if on_path or (keep_free.size != Vector2i.ZERO and keep_free.has_point(c)):
				continue
			var p: Vector2 = cell_pos(c) + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-14.0, 18.0))
			var r: float = rng.randf()
			if d > 4.2 and not trees.is_empty() and r < tree_k + 0.03 * (d - 4.2):
				_props.append([trees[rng.randi() % trees.size()], p + Vector2(0, CELL * 0.4), rng.randf() < 0.5])
			elif d > 3.0 and not bushes.is_empty() and r < 0.5:
				_props.append([bushes[rng.randi() % bushes.size()], p + Vector2(0, CELL * 0.25), rng.randf() < 0.5])
			elif d > 1.8 and not small.is_empty() and r < 0.6:
				_clutter.append([small[rng.randi() % small.size()], p])
	_props.sort_custom(func(a, b): return a[1].y < b[1].y)

# --------------------------------------------------------------------- UI ----

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 69
	add_child(ui)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	ui.add_child(_flash)

	preview_anchor = CenterContainer.new()
	preview_anchor.position = Vector2(500, 150)
	preview_anchor.size = Vector2(1380, 620)
	preview_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(preview_anchor)

	# A MESMA caixa de diálogo do tutorial (painel de personagem + retrato + nome + texto +
	# botão CONTINUAR), tingida com a cor de quem fala.
	box = PanelContainer.new()
	box.position = BOX_RECT.position
	box.size = BOX_RECT.size
	box.add_theme_stylebox_override("panel", TutorialGuideView._char_panel(NARRATOR_TINT, 22))
	box.visible = false
	ui.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	box.add_child(h)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(136, 136)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	name_plate = Label.new()
	name_plate.add_theme_font_size_override("font_size", 30)
	v.add_child(name_plate)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.custom_minimum_size = Vector2(TEXT_W, 104.0)
	text_label.add_theme_font_size_override("font_size", 36)
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	v.add_child(text_label)
	choices_row = HBoxContainer.new()
	choices_row.add_theme_constant_override("separation", 12)
	choices_row.visible = false
	v.add_child(choices_row)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	v.add_child(footer)
	continue_btn = Button.new()
	continue_btn.text = "CONTINUAR"
	continue_btn.custom_minimum_size = Vector2(260, 56)
	continue_btn.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(continue_btn, Color(0.4, 0.85, 0.45), "", "icone_confirmar")
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	footer.add_child(continue_btn)

func _on_continue() -> void:
	if _typing:
		_typing = false
		text_label.visible_characters = -1
		return
	if _waiting:
		advanced.emit()

# ---------------------------------------------------------------- desenho ----

func _w2s(p: Vector2) -> Vector2:
	return (focus + p - cam).round()

func _process(delta: float) -> void:
	_t += delta
	# texto letra a letra
	if _typing:
		_shown += delta * 95.0
		var n: int = int(_shown)
		if n >= _full_text.length():
			n = _full_text.length()
			_typing = false
		text_label.visible_characters = n
		_voice_t -= delta
		if _voice_t <= 0.0 and _typing:
			_voice_t = 0.07
			Sfx.play("voz_guia", -6.0)
	if _talker != "" and actors.has(_talker):
		portrait.texture = _actor_tex(actors[_talker])
	if _interior and not skip:
		_library_ambient(delta)
	elif not skip and (_storm or biome == "mina"):
		_biome_ambient(delta)
	for id in actors:
		var a: Dictionary = actors[id]
		if float(a["emote_t"]) > 0.0:
			a["emote_t"] = float(a["emote_t"]) - delta
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_parts.remove_at(i)
			continue
		p["vel"] = (p["vel"] as Vector2) + Vector2(0, float(p["grav"])) * delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var off: Vector2 = _w2s(-ORIGIN_TILE * CELL)
	if _interior:
		_draw_room_floor(off)
		_draw_room_back()
	else:
		var bd: Dictionary = BIOMES.get(biome, BIOMES["floresta"])
		BoardSkin.draw_tiles(self, off, ROWS, COLS, CELL, Color.WHITE, Color.WHITE, String(bd["skin"]))
		for pt in _path_tiles:
			draw_texture_rect(pt[1], Rect2(_w2s(cell_pos(pt[0]) - Vector2(CELL, CELL) / 2.0), Vector2(CELL, CELL)), false)
		# sombra do bioma sobre o tabuleiro (mata, sol, escuro da mina)
		draw_rect(Rect2(Vector2.ZERO, vp), bd["shade"])
		if _storm:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.86, 0.55, 0.26, 0.16 + 0.04 * sin(_t * 1.7)))
	for c in _clutter:
		var ct: Texture2D = c[0]
		var csz: Vector2 = ct.get_size() * PXS
		draw_texture_rect(ct, Rect2(_w2s(c[1]) - csz / 2.0, csz), false)
	# cenário e atores, ordenados pela altura na tela (quem está mais embaixo fica na frente)
	var items: Array = []
	for pr in _props:
		items.append([float(pr[1].y), 0, pr])
	var over: Array = []
	for id in actors:
		var a: Dictionary = actors[id]
		if a.get("flat", false):
			_draw_actor(a)   # coisas no chão ficam por baixo de tudo
			continue
		if a.get("over", false):
			over.append(a)   # entrando pela porta: por cima da fachada
			continue
		items.append([float((a["pos"] as Vector2).y) + (CELL * 0.3 if a["piece"] else CELL * 0.36), 1, a])
	items.sort_custom(func(x, y): return x[0] < y[0])
	for it in items:
		if it[1] == 0:
			var pr2: Array = it[2]
			var t: Texture2D = pr2[0]
			var sz: Vector2 = t.get_size() * PXS
			var foot: Vector2 = _w2s(pr2[1])
			var sway: float = roundf(sin(_t * 0.9 + foot.x * 0.01) * 1.0) * PXS if sz.y > 90.0 else 0.0
			draw_rect(Rect2(foot + Vector2(-sz.x * 0.3, -6.0), Vector2(sz.x * 0.6, 9.0)), Color(0.04, 0.03, 0.05, 0.28))
			var rect := Rect2(foot + Vector2(-sz.x / 2.0 + sway * 0.0, -sz.y), sz)
			if pr2[2]:
				draw_texture_rect(t, Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(-rect.size.x, rect.size.y)), false)
			else:
				draw_texture_rect(t, rect, false)
		else:
			_draw_actor(it[2])
	for a4 in over:
		_draw_actor(a4)
	if _interior:
		_draw_room_front()
	for p in _parts:
		var a2: float = clampf(float(p["life"]) / maxf(float(p["max"]), 0.01) * 2.0, 0.0, 1.0)
		var pp: Vector2 = _w2s(p["pos"])
		if p["tex"] != null:
			var pt: Texture2D = p["tex"]
			var psz: Vector2 = pt.get_size() * PXS
			draw_texture_rect(pt, Rect2(pp - psz / 2.0, psz), false, Color(1, 1, 1, a2))
		else:
			var col: Color = p["col"]
			col.a *= a2
			var s: float = float(p["size"])
			var w: float = float(p.get("w", s))   # rajada de areia: risco comprido
			draw_rect(Rect2((pp - Vector2(w, s) / 2.0).round(), Vector2(w, s)), col)
	# balões de reação
	for id in actors:
		var a3: Dictionary = actors[id]
		if float(a3["emote_t"]) > 0.0 and String(a3["emote"]) != "":
			_draw_emote(a3)
	# bordas escuras + faixas de cinema
	for k in range(6):
		var w: float = 34.0
		var al: float = 0.34 * (1.0 - float(k) / 6.0)
		draw_rect(Rect2(float(k) * w, 0, w, vp.y), Color(0.02, 0.03, 0.03, al))
		draw_rect(Rect2(vp.x - float(k + 1) * w, 0, w, vp.y), Color(0.02, 0.03, 0.03, al))
	draw_rect(Rect2(0, 0, vp.x, BAR_H), Color(0.02, 0.02, 0.03))
	draw_rect(Rect2(0, vp.y - BAR_H * 0.4, vp.x, BAR_H * 0.4), Color(0.02, 0.02, 0.03))
	if title != "":
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(500, 46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.85, 0.35))

func _draw_actor(a: Dictionary) -> void:
	var t: Texture2D = _actor_tex(a)
	if t == null or float(a["alpha"]) <= 0.01:
		return
	var sc: float = float(a["scale"])
	var sz: Vector2 = t.get_size() * PXS * sc
	var base: Vector2 = _w2s(a["pos"]) + (a["shake"] as Vector2)
	var z: float = float(a["z"])
	var col: Color = a.get("tint", Color.WHITE)
	col.a *= float(a["alpha"])
	if a.get("flat", false):
		draw_texture_rect(t, Rect2((base - sz / 2.0).round(), sz), false, col)
	elif a["piece"]:
		# o DISCO fica centrado na casa: o que passa da peça (chapéu da bruxa, vela do
		# monge, capuz) sobe para cima, em vez de empurrar o disco para baixo
		var disc: float = sz.x / 2.0
		draw_texture_rect(t, Rect2((base + Vector2(-sz.x / 2.0, disc - sz.y - z)).round(), sz), false, col)
	else:
		var foot: Vector2 = base + Vector2(0, CELL * 0.36)
		var tl: Vector2 = (foot + Vector2(-sz.x / 2.0, -sz.y - z)).round()
		draw_texture_rect(t, Rect2(tl, sz), false, col)
		# camadas por cima do sprite (porta abrindo, luz da porta): [textura, deslocamento em px nativos]
		for ov in a.get("overlays", []):
			if ov[0] != null:
				var ot: Texture2D = ov[0]
				draw_texture_rect(ot, Rect2(tl + (ov[1] as Vector2) * PXS * sc, ot.get_size() * PXS * sc), false, col)
		# espelho: o reflexo da peça do jogador dentro da face lisa
		if a.has("mirror") and actors.has("player"):
			var m: Dictionary = a["mirror"]
			var pl: Dictionary = actors["player"]
			var pt2: Texture2D = pl["tex"]
			var rs: float = float(m["size"]) * PXS * sc
			var par: float = clampf(((pl["pos"] as Vector2).x - (a["pos"] as Vector2).x) * 0.05, -rs * 0.2, rs * 0.2)
			var rc: Vector2 = tl + (m["center"] as Vector2) * PXS * sc + Vector2(-par, float(m.get("lag", 0.0)))
			var mc: Color = m["tint"]
			mc.a *= float(pl["alpha"]) * float(a["alpha"])
			draw_texture_rect(pt2, Rect2((rc - Vector2(rs, rs) / 2.0).round(), Vector2(rs, rs)), false, mc)

func _draw_emote(a: Dictionary) -> void:
	var txt: String = a["emote"]
	var font: Font = ThemeDB.fallback_font
	var tsz: Vector2 = (a["tex"] as Texture2D).get_size() * PXS * float(a["scale"])
	var top: float = maxf(CELL * 0.62, tsz.y - tsz.x / 2.0 + 14.0) if a["piece"] else (tsz.y - CELL * 0.3)
	var pop: float = clampf((0.9 - float(a["emote_t"])) * 8.0, 0.0, 1.0) if float(a["emote_t"]) > 0.6 else 1.0
	var c: Vector2 = _w2s(a["pos"]) + Vector2(0, -top - 26.0 - 6.0 * pop - float(a["z"]))
	var w: float = maxf(44.0, 20.0 + float(txt.length()) * 20.0)
	var r := Rect2(c - Vector2(w / 2.0, 22.0), Vector2(w, 44.0))
	# balão nas cores do jogo: fundo ameixa, borda creme, texto dourado/creme
	var edge := Color(0.89, 0.85, 0.74)
	var fill := Color(0.18, 0.13, 0.17)
	draw_rect(r.grow(3.0), edge)
	draw_rect(r, fill)
	draw_rect(Rect2(c + Vector2(-6.0, 25.0), Vector2(12.0, 3.0)), edge)
	draw_rect(Rect2(c + Vector2(-3.0, 28.0), Vector2(6.0, 3.0)), edge)
	draw_rect(Rect2(c + Vector2(-3.0, 22.0), Vector2(6.0, 3.0)), fill)
	var col := Color(1.0, 0.8, 0.32) if txt == "!" else edge
	draw_string(font, c + Vector2(-w / 2.0, 12.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 34, col)

# ------------------------------------------------------------- animações ----

func _wait(sec: float) -> void:
	if skip:
		return
	await get_tree().create_timer(sec).timeout

# Salto de uma casa (como a peça anda no tabuleiro): arco para cima e poeirinha na chegada.
func hop_to(id: String, cell: Vector2i, dur: float = 0.26, height: float = 46.0) -> void:
	if not actors.has(id):
		return
	var a: Dictionary = actors[id]
	var to: Vector2 = cell_pos(cell)
	if skip:
		a["pos"] = to
		return
	var from: Vector2 = a["pos"]
	var tw := create_tween()
	tw.tween_method(func(k: float):
		a["pos"] = from.lerp(to, k)
		a["z"] = sin(k * PI) * height, 0.0, 1.0, dur)
	await tw.finished
	a["z"] = 0.0
	Sfx.play("salto", -8.0)
	_dust(to + Vector2(0, CELL * 0.3), 5)

func walk(id: String, cells: Array) -> void:
	for c in cells:
		await hop_to(id, c)
		await _wait(0.05)

# Pulinho no lugar (falar, reagir).
func bump(id: String, height: float = 22.0) -> void:
	if skip or not actors.has(id):
		return
	var a: Dictionary = actors[id]
	var tw := create_tween()
	tw.tween_method(func(k: float): a["z"] = sin(k * PI) * height, 0.0, 1.0, 0.2)
	await tw.finished
	a["z"] = 0.0

func shake(id: String, amp: float = 6.0, dur: float = 0.5) -> void:
	if skip or not actors.has(id):
		return
	var a: Dictionary = actors[id]
	var tw := create_tween()
	var n: int = int(dur / 0.04)
	for i in range(n):
		tw.tween_callback(func(): a["shake"] = Vector2(randf_range(-amp, amp), randf_range(-amp * 0.4, amp * 0.4)))
		tw.tween_interval(0.04)
	await tw.finished
	a["shake"] = Vector2.ZERO

func emote(id: String, txt: String, dur: float = 1.0) -> void:
	if actors.has(id):
		actors[id]["emote"] = txt
		actors[id]["emote_t"] = dur

func cam_to(to: Vector2, dur: float) -> void:
	if skip:
		cam = to
		return
	create_tween().tween_property(self, "cam", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func flash(col: Color, peak: float = 0.4, dur: float = 0.6) -> void:
	if skip:
		return
	_flash.color = col
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", peak, 0.06)
	tw.tween_property(_flash, "modulate:a", 0.0, dur)

func _dust(at: Vector2, n: int) -> void:
	for i in range(n):
		_parts.append({"pos": at + Vector2(randf_range(-14, 14), 0), "vel": Vector2(randf_range(-50, 50), randf_range(-50, -10)), "life": 0.35, "max": 0.35,
			"tex": null, "col": Color(0.85, 0.78, 0.62, 0.7), "size": PXS * 2.0, "grav": 60.0})

func coins(at: Vector2, n: int, to_player: bool = true) -> void:
	var ct := _tx(ART + "coin.png")
	for i in range(n):
		var v := Vector2(randf_range(-170, 170), randf_range(-420, -220))
		if to_player and actors.has("player"):
			v.x += ((actors["player"]["pos"] as Vector2).x - at.x) * 0.9
		_parts.append({"pos": at + Vector2(randf_range(-10, 10), -20), "vel": v, "life": randf_range(0.7, 1.1), "max": 1.0, "tex": ct, "col": Color.WHITE, "size": 0.0, "grav": 900.0})
	if n > 0:
		Sfx.play("moeda_pousa", -4.0)

func sparkles(at: Vector2, col: Color, n: int) -> void:
	for i in range(n):
		var ang: float = randf() * TAU
		_parts.append({"pos": at + Vector2(randf_range(-20, 20), randf_range(-30, 10)), "vel": Vector2(cos(ang), sin(ang)) * randf_range(40, 190) + Vector2(0, -60),
			"life": randf_range(0.5, 1.1), "max": 1.0, "tex": null, "col": col.lerp(Color.WHITE, randf() * 0.5), "size": PXS * float(1 + randi() % 2), "grav": -30.0})

# ------------------------------------------------------------- diálogos ----

func _set_text(who: String, text: String) -> void:
	box.visible = true
	var sp: Array = SPEAKERS.get(who, [])
	_talker = "npc" if not sp.is_empty() and actors.has("npc") else ""
	if sp.is_empty():
		# narração: caixa neutra, com o retrato do que está em cena
		name_plate.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
		box.add_theme_stylebox_override("panel", TutorialGuideView._char_panel(NARRATOR_TINT, 22))
		# o narrador não "é" ninguém: com personagem em cena, a caixa fica sem retrato
		# (senão parece que o personagem está falando); com objeto, mostra o objeto
		var show_obj: bool = actors.has(_target) and _target != "npc"
		portrait.texture = actors[_target]["tex"] if show_obj else null
		portrait.visible = show_obj
		# sem o título do evento (ex.: "BRUXA DA CLAREIRA") em cima da narração, que soava como o nome de quem fala
		name_plate.text = title if show_obj else ""
	else:
		name_plate.text = sp[0]
		name_plate.add_theme_color_override("font_color", sp[1])
		box.add_theme_stylebox_override("panel", TutorialGuideView._char_panel(sp[2], 22))
		portrait.texture = actors["npc"]["tex"] if actors.has("npc") else null
		portrait.visible = true
	text_label.remove_theme_color_override("font_color")
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	text_label.custom_minimum_size.y = 104.0
	_full_text = text
	text_label.text = text
	_shown = 0.0
	text_label.visible_characters = -1 if skip else 0
	_typing = not skip

# Mostra uma fala e espera o clique.
func say(who: String, text: String) -> void:
	choices_row.visible = false
	_set_text(who, text)
	if skip:
		return
	_waiting = true
	continue_btn.visible = true
	await advanced
	_waiting = false
	continue_btn.visible = false

# Mostra um texto sem esperar clique (desfecho: o botão de seguir aparece ao lado).
func narrate(text: String, col: Color = Color(0.78, 0.82, 0.9)) -> void:
	choices_row.visible = false
	continue_btn.visible = false
	_set_text("", text)
	text_label.add_theme_color_override("font_color", col)

func _unhandled_input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_SPACE or e.keycode == KEY_ENTER))
	if not press:
		return
	if _typing:
		_typing = false
		text_label.visible_characters = -1
		return
	if _waiting:
		advanced.emit()

# Escolhas dentro da caixa de diálogo. `choices`: [{id, label, hint, enabled, color}].
func show_choices(prompt: String, choices: Array) -> void:
	_set_text("", prompt)
	_typing = false
	text_label.visible_characters = -1
	continue_btn.visible = false
	for ch in choices_row.get_children():
		ch.queue_free()
	var n: int = maxi(choices.size(), 1)
	var w: float = (TEXT_W - 12.0 * float(n - 1)) / float(n)
	for c in choices:
		var btn := Button.new()
		btn.text = "%s\n%s" % [c["label"], c["hint"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(w, 118)
		btn.add_theme_font_size_override("font_size", 22)
		PixelUI.skin_button(btn, c["color"])
		btn.disabled = not c["enabled"]
		var cid: String = c["id"]
		btn.pressed.connect(func():
			choices_row.visible = false
			choice_made.emit(cid))
		choices_row.add_child(btn)
	text_label.custom_minimum_size.y = 40.0
	choices_row.visible = true

# ------------------------------------------------------------- roteiro ----

# Abertura: a câmera vem de longe, a peça entra saltando em diagonal, os personagens falam.
func play_intro(event: Dictionary) -> void:
	var sc: Dictionary = SCRIPTS[String(event["id"])]
	_event_id = String(event["id"])
	var b: String = String(event.get("biome", "floresta"))
	if b != biome:
		biome = b
		_build_scenery()
	if String(event["id"]) == "library":
		await _library_intro(sc)
		return
	_target = String(sc["target"])
	for id in sc["actors"]:
		var d: Array = sc["actors"][id]
		_add_scene_actor(id, String(d[0]), d[1], d[2], d.size() > 3 and bool(d[3]))
		if d.size() > 4:
			actors[id]["scale"] = float(d[4])   # sprites que ocupam várias casas
	if sc.get("coins", false):
		_scatter_coins(actors[_target]["pos"])
	_setup_special(sc)
	cam = Vector2(-260, 190)
	cam_to(sc.get("cam", Vector2.ZERO), 2.4)   # cenas com coisas altas sobem a câmera
	await _wait(0.5)
	await walk("player", [Vector2i(-5, 5), Vector2i(-4, 4), Vector2i(-3, 3), Vector2i(-2, 2), Vector2i(-1, 1)])
	if _target == "npc":
		emote(_target, "!", 0.9)   # só personagens reagem com balão
		await bump(_target)
	else:
		emote("player", "?", 0.9)
	await _wait(0.35)
	for line in sc["lines"]:
		var who: String = line[0]
		if who != "" and actors.has("npc"):
			bump("npc", 12.0)
		await say(who, line[1])

# A ação da escolha. `luck`: a escolha depende de sorte (tem suspense antes do desfecho).
func play_choice(event_id: String, choice_id: String, luck: bool) -> void:
	if choice_id == "skip":
		return
	if not actors.has(_target):
		return
	var tgt: Dictionary = actors[_target]
	_on_choice(event_id, choice_id)
	# a peça se aproxima (meio salto na direção do alvo) e age
	var beat: String = BEATS.get(event_id + "." + choice_id, "")
	if beat != "":
		narrate(beat)
	if not skip:
		var a: Dictionary = actors["player"]
		var home: Vector2 = a["pos"]
		var near: Vector2 = home.lerp(tgt["pos"], 0.42)
		# esfinge: a peça pula em cima da placa escolhida
		if event_id == "sphinx" and actors.has("signs"):
			var dx: float = {"time": -16.0, "shadow": 0.0, "silence": 16.0}.get(choice_id, 0.0) * PXS * 1.2
			near = (actors["signs"]["pos"] as Vector2) + Vector2(dx, -6.0)
		var tw := create_tween()
		tw.tween_method(func(k: float):
			a["pos"] = home.lerp(near, k)
			a["z"] = sin(k * PI) * 30.0, 0.0, 1.0, 0.22)
		await tw.finished
		a["z"] = 0.0
		Sfx.play("salto", -8.0)
		if luck:
			# suspense: a coisa treme, a peça espera
			emote("player", "...", 1.3)
			await shake(_target, 3.0, 0.45)
			await _wait(0.25)
			await shake(_target, 6.0, 0.55)
			await _wait(0.2)
		else:
			await bump(_target, 14.0)
			await _wait(0.25)
		var tw2 := create_tween()
		tw2.tween_method(func(k: float):
			a["pos"] = near.lerp(home, k)
			a["z"] = sin(k * PI) * 22.0, 0.0, 1.0, 0.2)
		await tw2.finished
		a["z"] = 0.0

# O desfecho encenado. `kind`: "good" | "bad" | "danger" | "neutral" | "" (escolha sem sorte).
func play_result(event_id: String, kind: String, gold_delta: int, gained: bool, ambush: bool) -> void:
	if skip:
		return
	var tpos: Vector2 = actors[_target]["pos"] if actors.has(_target) else Vector2.ZERO
	_on_result(event_id, kind, gold_delta, gained, ambush)
	if ambush:
		await _play_ambush()
		return
	if kind == "bad" or (gold_delta < 0 and not gained and kind != ""):
		Sfx.play("erro")
		flash(Color(0.45, 0.1, 0.5), 0.42, 0.9)
		emote("player", "!", 0.9)
		sparkles(tpos, Color(0.6, 0.3, 0.8), 22)
		await shake("player", 9.0, 0.5)
		return
	if event_id == "chest" and gold_delta > 0:
		for id in actors:
			if String(id).begins_with("coin"):
				actors[id]["alpha"] = 0.0   # as moedas do chão vão junto para a bolsa
		if actors.has("chest"):
			actors["chest"]["tex"] = _tx(ART + "chest_open.png")
	if event_id == "library" and (gained or kind == "good"):
		_pages_burst(tpos + Vector2(0, -CELL * 0.6), 16)
	if gold_delta > 0:
		coins(tpos, clampi(5 + gold_delta, 8, 24))
		flash(Color(1.0, 0.85, 0.35), 0.25, 0.6)
		Sfx.play("acerto")
		await bump("player", 30.0)
	if gained:
		sparkles(tpos, Color(1.0, 0.9, 0.5), 30)
		flash(Color(1.0, 0.95, 0.7), 0.32, 0.7)
		Sfx.play("item")
		await bump("player", 30.0)
	if gold_delta == 0 and not gained and kind == "neutral":
		emote("player", "...", 1.0)
	await _wait(0.2)

# Emboscada: peças escuras saltam de fora da tela e cercam a peça do jogador.
func _play_ambush() -> void:
	var black := PieceSkin.enemy_texture()
	var from: Array = [Vector2i(-7, -3), Vector2i(5, 5), Vector2i(-6, 7), Vector2i(6, -6)]
	var to: Array = [Vector2i(-3, -1), Vector2i(1, 3), Vector2i(-3, 3), Vector2i(3, -3)]
	Sfx.play("erro")
	flash(Color(0.9, 0.2, 0.2), 0.45, 0.8)
	emote("player", "!", 1.2)
	shake("player", 7.0, 0.5)
	for i in range(4):
		_add_actor("foe%d" % i, black, from[i], true)
	for i in range(4):
		var id: String = "foe%d" % i
		var f: Vector2i = from[i]
		var t: Vector2i = to[i]
		# dois saltos em diagonal até a posição de cerco
		var mid := Vector2i(int(round((f.x + t.x) / 2.0)), int(round((f.y + t.y) / 2.0)))
		_foe_run(id, [mid, t])
	await _wait(1.0)
	for i in range(4):
		emote("foe%d" % i, "!", 0.8)
	await _wait(0.4)

func _foe_run(id: String, cells: Array) -> void:
	for c in cells:
		await hop_to(id, c, 0.22, 60.0)

# ------------------------------------------------------------- biblioteca ----

# Ato 1: a fachada no meio do mato. A peça chega pelo caminho de lajotas, a porta se abre
# sozinha e ela entra. Ato 2: o cenário troca para o salão e as falas continuam lá dentro.
func _library_intro(sc: Dictionary) -> void:
	_target = "house"
	_build_scenery(Rect2i(-6, -7, 15, 7))
	_library_outside()
	# a fachada é alta: a câmera fica mais para cima para caber o telhado
	cam = Vector2(-260, -20)
	cam_to(Vector2(0, -190), 2.4)
	await _wait(0.5)
	await walk("player", [Vector2i(-5, 5), Vector2i(-4, 4), Vector2i(-3, 3), Vector2i(-2, 2), Vector2i(-1, 1), Vector2i(0, 0)])
	emote("player", "?", 0.9)
	await _wait(0.35)
	var lo: Array = sc["lines_out"]
	await say(lo[0][0], lo[0][1])
	# a porta abre sozinha, quadro a quadro, e sai luz
	var house: Dictionary = actors["house"]
	for f in [1, 2, 3]:
		house["overlays"] = [[_tx(LIB + "bib_porta_%d.png" % f), LIB_DOOR_OFF]]
		if f == 1:
			Sfx.play("mover", -4.0)
		await _wait(0.16)
	house["overlays"].append([_tx(LIB + "bib_luz_porta.png"), LIB_DOOR_OFF + Vector2(-5, 20)])
	await say(lo[1][0], lo[1][1])
	await _library_enter()
	_library_inside()
	if not skip:
		# vem do escuro
		_flash.color = Color(0.02, 0.02, 0.05)
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, 0.7)
	cam = Vector2(-200, 150)
	cam_to(Vector2.ZERO, 1.8)
	await _wait(0.3)
	await walk("player", [Vector2i(-5, 5), Vector2i(-4, 4), Vector2i(-3, 3), Vector2i(-2, 2), Vector2i(-1, 1)])
	emote("player", "!", 0.9)
	shake("tome", 2.0, 0.4)
	await _wait(0.35)
	for line in sc["lines"]:
		await say(line[0], line[1])

func _library_outside() -> void:
	_add_actor("house", _tx(LIB + "bib_fachada.png"), LIB_CELL, false)
	var foot: Vector2 = cell_pos(LIB_CELL) + Vector2(0, CELL * 0.36)
	var half: float = 65.0 * PXS                         # meia largura da fachada
	var wall_y: float = foot.y - 26.0 * PXS + 12.0       # pé da parede (acima dos degraus)
	var m1 := _tx(LIB + "bib_muro_1.png")
	var m2 := _tx(LIB + "bib_muro_2.png")
	var mq := _tx(LIB + "bib_muro_quebrado.png")
	# mureta saindo das laterais e sumindo na mata (a ponta desmoronada fica para fora)
	for side in [-1.0, 1.0]:
		var x: float = foot.x + side * (half + 26.0 * PXS)
		_props.append([m1 if side < 0 else m2, Vector2(x, wall_y), side > 0])
		x += side * 52.0 * PXS
		_props.append([m2 if side < 0 else m1, Vector2(x, wall_y), side < 0])
		x += side * 39.0 * PXS
		_props.append([mq, Vector2(x, wall_y), side < 0])
	_props.append([_tx(LIB + "bib_estatua.png"), Vector2(foot.x - half + 8.0 * PXS, foot.y + 6.0), false])
	_props.append([_tx(LIB + "bib_poste_lanterna.png"), Vector2(foot.x + 40.0 * PXS, foot.y + 4.0), false])
	_props.sort_custom(func(a, b): return a[1].y < b[1].y)
	var lm := _tx(LIB + "bib_livros_mato.png")
	_clutter.append([lm, cell_pos(Vector2i(-2, -1)) + Vector2(10, 20)])
	_clutter.append([lm, cell_pos(Vector2i(4, 1))])
	# caminho de lajotas por onde a peça vem, alargando perto dos degraus
	_path_tiles.clear()
	var cells: Array = [Vector2i(0, -1), Vector2i(2, -1), Vector2i(1, 0)]
	for k in range(-6, 2):
		cells.append(Vector2i(k, -k))
	for i in range(cells.size()):
		_path_tiles.append([cells[i], _tx(LIB + "bib_caminho_%d.png" % (1 + i % 3))])

# A peça sobe os degraus e some no escuro da porta.
func _library_enter() -> void:
	var a: Dictionary = actors["player"]
	await hop_to("player", Vector2i(1, -1))
	await _wait(0.1)
	var foot: Vector2 = cell_pos(LIB_CELL) + Vector2(0, CELL * 0.36)
	var door_floor: Vector2 = foot + Vector2(0, -26.0 * PXS)   # soleira da porta
	var stand: Vector2 = door_floor + Vector2(0, -14.0 * PXS)
	if skip:
		a["alpha"] = 0.0
		return
	a["over"] = true
	var from: Vector2 = a["pos"]
	var tw := create_tween()
	tw.tween_method(func(k: float):
		a["pos"] = from.lerp(stand, k)
		a["z"] = sin(k * PI) * 40.0, 0.0, 1.0, 0.3)
	await tw.finished
	a["z"] = 0.0
	Sfx.play("salto", -8.0)
	await _wait(0.15)
	# entra: encolhe, escurece e some
	var tw2 := create_tween()
	tw2.tween_method(func(k: float):
		a["pos"] = stand + Vector2(0, -10.0 * PXS * k)
		a["scale"] = lerpf(1.0, 0.78, k)
		a["tint"] = Color.WHITE.lerp(Color(0.25, 0.3, 0.55), k)
		a["alpha"] = 1.0 - k, 0.0, 1.0, 0.45)
	await tw2.finished
	flash(Color(0.55, 0.65, 0.95), 0.5, 0.35)
	await _wait(0.3)

func _library_inside() -> void:
	_interior = true
	focus = ROOM_FOCUS
	_props.clear()
	_clutter.clear()
	_path_tiles.clear()
	_parts.clear()
	var keep: Dictionary = actors["player"]
	actors.clear()
	actors["player"] = keep
	keep["pos"] = cell_pos(Vector2i(-6, 6))
	keep["alpha"] = 1.0
	keep["scale"] = 1.0
	keep["over"] = false
	keep.erase("tint")
	_add_actor("tome", _tx(LIB + "bib_atril_tomo.png"), Vector2i(1, -1), false)
	_target = "tome"
	_lib_prop("bib_candelabro", Vector2(0.15, -1.25))
	_lib_prop("bib_candelabro", Vector2(1.85, -1.25), true)
	_lib_prop("bib_coluna", Vector2(-2.4, -1.6))
	_lib_prop("bib_coluna", Vector2(4.4, -1.6))
	_lib_prop("bib_estante_solta", Vector2(-5.6, -1.2))
	_lib_prop("bib_estante_caida", Vector2(3.6, 2.2))
	_lib_prop("bib_mesa", Vector2(-4.9, 2.2))
	_lib_prop("bib_pilha_livros_1", Vector2(-1.6, -2.0))
	_lib_prop("bib_pilha_livros_2", Vector2(3.0, 0.4))
	_lib_prop("bib_pilha_livros_3", Vector2(-6.2, 4.0))
	_lib_prop("bib_pilha_livros_1", Vector2(5.6, 3.6), true)
	_props.sort_custom(func(a, b): return a[1].y < b[1].y)
	for pc in [Vector2(-3.4, 0.6), Vector2(2.3, 1.3), Vector2(-5.8, 5.2), Vector2(0.6, 3.8), Vector2(4.6, -0.6), Vector2(-4.3, -1.4)]:
		_clutter.append([_tx(LIB + "bib_paginas_voando_%d.png" % (1 + int(absf(pc.x * 7.0)) % 3)), pc * CELL])

func _lib_prop(name: String, cell: Vector2, flip: bool = false) -> void:
	_props.append([_tx(LIB + name + ".png"), cell * CELL + Vector2(0, CELL * 0.36), flip])

func _lib_floor_tex(cx: int, cy: int) -> Texture2D:
	# tapete sob o atril e a rosácea na frente dele
	if cy == -1 and cx >= 0 and cx <= 2:
		return _tx(LIB + ["bib_escura_05_tapete", "bib_escura_05b_tapete", "bib_escura_05c_tapete"][cx] + ".png")
	if cx == 1 and cy == 1:
		return _tx(LIB + "bib_clara_07_rosacea.png")
	var h: int = absi(((cx + 40) * 92837111) ^ ((cy + 40) * 689287499)) % 1000003
	var light: bool = (cx + cy) % 2 != 0
	if light:
		var pool: Array = ["00_lisa", "00_lisa", "00_lisa", "00_lisa", "01_veios", "01_veios", "01_veios", "02_rachada", "03_poeira", "03_poeira", "04_pagina", "05_cera", "06_musgo"]
		return _tx(LIB + "bib_clara_" + pool[h % pool.size()] + ".png")
	var pool2: Array = ["00_tacos", "00_tacos", "00_tacos", "00_tacos", "01_gasta", "01_gasta", "01_gasta", "02_prego", "02_prego", "03_poeira", "03_poeira", "00_tacos", "01_gasta", "00_tacos", "01_gasta", "00_tacos", "02_prego", "04_tinta"]
	return _tx(LIB + "bib_escura_" + pool2[h % pool2.size()] + ".png")

func _draw_room_floor(off: Vector2) -> void:
	for r in range(ROWS):
		for c in range(COLS):
			var cx: int = c - 15
			var cy: int = r - 10
			var t := _lib_floor_tex(cx, cy)
			if t != null:
				draw_texture_rect(t, Rect2(off + Vector2(c, r) * CELL, Vector2(CELL, CELL)), false)
	# penumbra azulada do salão
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.05, 0.06, 0.13, 0.26))

# Parede do fundo: estantes (topo + frente), quinas e a janela.
func _draw_room_back() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fw: float = 52.0 * PXS
	var fh: float = 52.0 * PXS
	var tw: float = 26.0 * PXS
	var top_y: float = ROOM_WALL_Y - fh
	# fora do salão: escuro
	var tl: Vector2 = _w2s(Vector2(ROOM_L - tw, top_y - tw))
	draw_rect(Rect2(0, 0, vp.x, maxf(tl.y, 0.0)), Color(0.02, 0.02, 0.04))
	var slot: int = 0
	var x: float = ROOM_L
	while x < ROOM_R:
		var w: float = minf(fw, ROOM_R - x)
		var name: String = "bib_janela" if slot == ROOM_WINDOW_SLOT else "bib_parede_face_%d" % (1 + (slot * 2) % 3)
		var t := _tx(LIB + name + ".png")
		var dst := Rect2(_w2s(Vector2(x, top_y)), Vector2(w, fh))
		draw_texture_rect_region(t, dst, Rect2(0, 0, w / PXS, 52.0))
		x += fw
		slot += 1
	x = ROOM_L - tw
	var k: int = 0
	while x < ROOM_R + tw:
		var tt := _tx(LIB + "bib_parede_topo_%d.png" % (1 + k % 2))
		draw_texture_rect(tt, Rect2(_w2s(Vector2(x, top_y - tw)), Vector2(tw, tw)), false)
		x += tw
		k += 1
	draw_texture_rect(_tx(LIB + "bib_parede_quina_esq.png"), Rect2(_w2s(Vector2(ROOM_L - tw, top_y)), Vector2(tw, fh)), false)
	draw_texture_rect(_tx(LIB + "bib_parede_quina_dir.png"), Rect2(_w2s(Vector2(ROOM_R, top_y)), Vector2(tw, fh)), false)
	# sombra da estante no chão
	var sy: Vector2 = _w2s(Vector2(ROOM_L, ROOM_WALL_Y))
	draw_rect(Rect2(sy, Vector2(ROOM_R - ROOM_L, 4.0 * PXS)), Color(0.03, 0.02, 0.05, 0.35))

# Paredes laterais (na frente de tudo), luz da janela e o escuro de fora.
func _draw_room_front() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var tw: float = 26.0 * PXS
	var fh: float = 52.0 * PXS
	# feixe de luz da janela caindo no chão
	var wx: float = ROOM_L + float(ROOM_WINDOW_SLOT) * 52.0 * PXS
	var beam := _tx(LIB + "bib_luz_janela.png")
	if beam != null:
		var bs: Vector2 = beam.get_size() * PXS
		draw_texture_rect(beam, Rect2(_w2s(Vector2(wx + 26.0 * PXS - bs.x * 0.35, ROOM_WALL_Y - 12.0 * PXS)), bs), false, Color(1, 1, 1, 0.85 + 0.1 * sin(_t * 0.8)))
	var y: float = ROOM_WALL_Y
	var i: int = 0
	while _w2s(Vector2(0, y)).y < vp.y:
		var n: int = 1 + i % 2
		draw_texture_rect(_tx(LIB + "bib_parede_lateral_%d_esq.png" % n), Rect2(_w2s(Vector2(ROOM_L - tw, y)), Vector2(tw, fh)), false)
		draw_texture_rect(_tx(LIB + "bib_parede_lateral_%d.png" % n), Rect2(_w2s(Vector2(ROOM_R, y)), Vector2(tw, fh)), false)
		y += fh
		i += 1
	var l: float = _w2s(Vector2(ROOM_L - tw, 0)).x
	var r: float = _w2s(Vector2(ROOM_R + tw, 0)).x
	if l > 0.0:
		draw_rect(Rect2(0, 0, l, vp.y), Color(0.02, 0.02, 0.04))
	if r < vp.x:
		draw_rect(Rect2(r, 0, vp.x - r, vp.y), Color(0.02, 0.02, 0.04))

# Páginas soltas flutuando e poeira na luz da janela.
func _library_ambient(delta: float) -> void:
	_ambient_t -= delta
	if _ambient_t > 0.0:
		return
	_ambient_t = randf_range(0.35, 0.8)
	var vp: Vector2 = get_viewport_rect().size
	if randf() < 0.45:
		var p0: Vector2 = cam - focus + Vector2(randf_range(150.0, vp.x - 150.0), vp.y * randf_range(0.2, 0.7))
		_parts.append({"pos": p0, "vel": Vector2(randf_range(-30, 30), randf_range(-20, -6)), "life": 4.0, "max": 4.0,
			"tex": _tx(LIB + "bib_paginas_voando_%d.png" % (1 + randi() % 3)), "col": Color.WHITE, "size": 0.0, "grav": 2.0})
	var wx: float = ROOM_L + float(ROOM_WINDOW_SLOT) * 52.0 * PXS + 26.0 * PXS
	for j in range(2):
		_parts.append({"pos": Vector2(wx + randf_range(-40, 120), ROOM_WALL_Y + randf_range(0, 360)), "vel": Vector2(randf_range(4, 14), randf_range(-8, 8)),
			"life": 2.6, "max": 2.6, "tex": null, "col": Color(0.8, 0.88, 1.0, 0.55), "size": PXS, "grav": 0.0})

func _pages_burst(at: Vector2, n: int) -> void:
	for i in range(n):
		var ang: float = randf_range(-PI * 0.95, -PI * 0.05)
		_parts.append({"pos": at, "vel": Vector2(cos(ang), sin(ang)) * randf_range(120, 300), "life": randf_range(1.0, 1.6), "max": 1.4,
			"tex": _tx(LIB + "bib_paginas_voando_%d.png" % (1 + randi() % 3)), "col": Color.WHITE, "size": 0.0, "grav": 160.0})

# ------------------------------------------------------- deserto e mina ----

# Detalhes de cada cena que não cabem na tabela SCRIPTS.
func _setup_special(sc: Dictionary) -> void:
	_storm = bool(sc.get("storm", false))
	if sc.get("rails", false):
		# trilho atravessando a cena na fileira do carrinho
		_path_tiles.clear()
		for x in range(-9, 8):
			_path_tiles.append([Vector2i(x, -1), _tx(ART + "trilho_h.png")])
		_path_tiles.append([Vector2i(8, -1), _tx(ART + "trilho_fim.png")])
	match _event_id:
		"mirage":
			actors["palm"]["alpha"] = 0.55       # a palmeira da miragem é meio de mentira
			actors["pond"]["alpha"] = 0.85
		"crystal_vein":
			actors["rubble"]["alpha"] = 0.0      # só aparece se desabar
		"obelisk":
			actors["base"]["pos"] = actors["obelisk"]["pos"] + Vector2(0, 6)   # oferendas no pé do obelisco
		"mirror_shard":
			actors["mirror"]["mirror"] = {"center": Vector2(15, 24), "size": 18.0, "tint": Color(0.62, 0.82, 1.0, 0.6)}
		"mirror_altar":
			# a "versão mais velha": acinzentada, um pouco maior
			actors["altar"]["mirror"] = {"center": Vector2(18, 22), "size": 20.0, "tint": Color(0.70, 0.66, 0.78, 0.75)}
			actors["hand"]["alpha"] = 0.0
			actors["hand"]["pos"] = actors["altar"]["pos"] + Vector2(0, -CELL * 0.55)
		"prospectors":
			for id in ["sh1", "sh2"]:
				actors[id]["alpha"] = 0.32
		"echo_chamber":
			actors["wave"]["alpha"] = 0.7
		"nomad":
			actors["coin"]["z"] = 34.0          # a moeda girando no ar, ao lado dele

func _swap(id: String, sprite: String) -> void:
	if actors.has(id):
		var t := _tx(ART + sprite + ".png")
		if t != null:
			actors[id]["tex"] = t

# Na hora da escolha (antes do suspense).
func _on_choice(event_id: String, choice_id: String) -> void:
	match event_id + "." + choice_id:
		"crystal_vein.pry":
			_swap("vein", "vein_cristal_2")
		"mirror_shard.cover":
			_swap("mirror", "mirror_shard_coberto")
			actors["mirror"].erase("mirror")
		"ore_cart.brake":
			_swap("lever", "alavanca_puxada")
		"mirror_altar.offer":
			if actors.has("hand") and not skip:
				var h: Dictionary = actors["hand"]
				var tw := create_tween()
				tw.tween_method(func(k: float): h["alpha"] = k, 0.0, 0.85, 0.5)
		"sphinx.time", "sphinx.shadow", "sphinx.silence":
			_swap("sphinx", "sphinx_2")
		"echo_chamber.shout", "echo_chamber.whisper":
			if actors.has("wave"):
				actors["wave"]["scale"] = 3.0

# No desfecho (antes da animação padrão de ganho/perda).
func _on_result(event_id: String, kind: String, gold_delta: int, gained: bool, ambush: bool) -> void:
	var good: bool = gained or gold_delta > 0 or kind == "good"
	match event_id:
		"sarcophagus":
			_swap("sarc", "sarcophagus_aberto")
			if actors.has("cold"):
				actors["cold"]["alpha"] = 0.0
		"obelisk":
			if good:
				_swap("obelisk", "obelisk_2")
		"crystal_vein":
			if kind == "bad" and actors.has("rubble"):
				actors["rubble"]["alpha"] = 1.0
				shake("player", 10.0, 0.6)
				_dust(actors["rubble"]["pos"] + Vector2(0, CELL * 0.3), 18)
		"mirage":
			if kind == "bad" or good:
				# a miragem some
				for id in ["pond", "palm"]:
					if actors.has(id) and not skip:
						var a: Dictionary = actors[id]
						var tw := create_tween()
						tw.tween_method(func(k: float): a["alpha"] = (1.0 - k) * 0.85, 0.0, 1.0, 0.8)
		"ore_cart":
			if actors.has("cart"):
				actors["cart"].erase("frames")   # o carrinho para
		"mirror_altar":
			if actors.has("hand") and not skip:
				var h: Dictionary = actors["hand"]
				create_tween().tween_method(func(k: float): h["alpha"] = 0.85 * (1.0 - k), 0.0, 1.0, 0.6)
		"echo_chamber":
			if actors.has("wave"):
				actors["wave"]["scale"] = 2.0

# Tempestade passando (rajadas de areia) e brilhinhos dos cristais na mina.
func _biome_ambient(delta: float) -> void:
	_ambient_t -= delta
	if _ambient_t > 0.0:
		return
	var vp: Vector2 = get_viewport_rect().size
	var origin: Vector2 = cam - focus
	if _storm:
		_ambient_t = 0.02
		for i in range(6):
			var y: float = randf_range(0.0, vp.y)
			var col: Color = [Color(0.93, 0.80, 0.58, 0.9), Color(0.85, 0.66, 0.42, 0.85), Color(0.98, 0.9, 0.72, 0.8)][randi() % 3]
			_parts.append({"pos": origin + Vector2(-20.0, y), "vel": Vector2(randf_range(1100, 1700), randf_range(80, 220)), "life": 1.6, "max": 1.6,
				"tex": null, "col": col, "size": PXS * float(1 + randi() % 2), "w": PXS * float(4 + randi() % 8), "grav": 0.0})
	else:
		_ambient_t = randf_range(0.15, 0.35)
		var p: Vector2 = origin + Vector2(randf_range(100.0, vp.x - 100.0), randf_range(80.0, vp.y - 200.0))
		var cc: Color = [Color(0.56, 0.42, 0.82), Color(0.66, 0.86, 0.94), Color(0.25, 0.61, 0.47)][randi() % 3]
		_parts.append({"pos": p, "vel": Vector2(0, randf_range(-14, -4)), "life": 1.4, "max": 1.4, "tex": null, "col": cc, "size": PXS, "grav": 0.0})
