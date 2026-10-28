class_name TutorialDialogue
extends RefCounted

# TODAS as falas, títulos, textos de objetivo e dicas do tutorial ficam aqui —
# é o único arquivo para editar texto. O TutorialManager só guarda o estado e
# repassa para estas funções (os nomes get_* são os mesmos).
#
# Formato de uma fala: String simples, ou Dictionary com:
#   "t"       texto
#   "spot"    id de um trecho da tela a destacar (ex.: "board", "law_board", "hand")
#   "caption" legenda do destaque
#   "dim"     (só objetivos) escurecimento do resto da tela; 0.0 = sem escurecer.
#             Use 0.0 quando a ação NÃO é clicar no destaque (ex.: mover uma peça
#             até a fileira), senão o jogador acha que o resto da tela está travado.
#   "who"     "evil" para o Irmão falar (padrão: o Guia)
#   "flip"    "evil" gira o rosto do Guia (moeda) e vira o Irmão antes da fala
#   "shake"   0..1, intensidade do tremor de tela enquanto a fala é digitada

static func get_law_applied_lines() -> Array:
	return [
		{"t": "Olha só! Sua Lei acabou de agir sozinha — o letreiro mostra qual foi. Ela vale sempre que a condição dela acontece.", "spot": "law_board", "caption": "SUAS LEIS"},
		"Quando quiser reler o que cada Lei faz, é só passar o mouse sobre ela no quadro.",
	]

static func get_lesson_title(step: int) -> String:
	match step:
		TutorialManager.Step.DUEL_1_BASICS:
			return "Regras das damas"
		TutorialManager.Step.SHOP:
			return "A Loja"
		TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			return "Cartas e Leis"
		TutorialManager.Step.BET:
			return "Mesa de Apostas"
	return ""

static func get_lesson_goal(step: int) -> String:
	match step:
		TutorialManager.Step.DUEL_1_BASICS:
			return "Mover, capturar, coroar e a Morte Súbita"
		TutorialManager.Step.SHOP:
			return "Comprar uma Lei e Cartas com ouro"
		TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			return "Usar o que você comprou num duelo"
		TutorialManager.Step.BET:
			return "Moeda: branca ou preta"
	return ""

static func get_objectives(step: int) -> Array:
	match step:
		TutorialManager.Step.DUEL_1_BASICS:
			return [
				{"event": "piece_selected", "text": "Clique na peça com contorno amarelo",
				"spot": "cell:3,4", "caption": "CLIQUE AQUI",
				"done_tip": "Isso! Os pontos mostram para onde ela pode ir. Aqui só existe UMA jogada: capturar é obrigatório."},
				{"event": "capture", "text": "Pule sobre a peça inimiga",
				"spot": "cell:5,2", "caption": "PULE PARA CÁ",
				"done_tip": "Capturada! A peça inimiga saiu do tabuleiro. Se houvesse outro salto na sequência, você continuaria no mesmo turno."},
				{"event": "promotion", "text": "Mova suas peças até a última fileira (clique numa peça e depois na casa)",
				"spot": "row:0", "caption": "LEVE UMA PEÇA ATÉ AQUI", "dim": 0.0,
				"done_tip": "Coroada! A Dama anda e captura para os dois lados — e vale mais pontos."},
				{"event": "duel_won", "text": "Vença o duelo", "spot": "", "caption": "",
				"done_tip": ""},
			]
		TutorialManager.Step.SHOP:
			return [
				{"event": "shop_buy_law", "text": "Compre a Lei Segundo Movimento",
				"spot": "shop_buy_law", "caption": "COMPRE A LEI",
				"done_tip": ""},
				{"event": "shop_buy_card", "text": "Compre pelo menos uma Carta",
				"spot": "shop_buy_card", "caption": "COMPRE UMA CARTA",
				"done_tip": "Boa! Essa Carta já está no seu baralho."},
				{"event": "open_laws", "text": "Abra suas Leis (botão LEIS ou tecla TAB)",
				"spot": "laws_btn", "caption": "OU APERTE TAB",
				"done_tip": "Aqui você consulta tudo que tem. Feche com TAB ou ESC."},
				{"event": "close_laws", "text": "Feche o quadro de Leis (TAB ou ESC)",
				"spot": "", "caption": "",
				"done_tip": "Tudo certo! Agora o botão CONTINUAR VIAGEM está liberado."},
			]
		TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			return [
				{"event": "card_selected", "text": "Clique em uma Carta da sua mão para selecioná-la",
				"spot": "hand", "caption": "CLIQUE EM UMA CARTA", "dim": 0.0,
				"done_tip": "Cada Carta mostra o efeito ao passar o mouse. Algumas pedem um alvo no tabuleiro; outras agem na hora."},
				{"event": "card_used", "text": "Use a Carta (clique no alvo, se pedir um)",
				"spot": "", "caption": "",
				"done_tip": "Perfeito! A Carta usada vai para o descarte até o fim do duelo."},
				{"event": "law_triggered", "text": "Mova uma peça (clique nela e depois na casa) e veja sua Lei agir",
				"spot": "board", "caption": "MOVA UMA PEÇA", "dim": 0.0,
				"done_tip": ""},
				{"event": "duel_won", "text": "Vença o duelo", "spot": "", "caption": "",
				"done_tip": ""},
			]
		TutorialManager.Step.BET:
			return [
				{"event": "bet_stake", "text": "Escolha quanto ouro arriscar",
				"spot": "bet_gold", "caption": "ARRISQUE OURO",
				"done_tip": "Se acertar a cor, você ganha 80% a mais do que apostou. Errou, perde o que apostou."},
				{"event": "bet_call", "text": "Chame BRANCA ou PRETA",
				"spot": "bet_call", "caption": "ESCOLHA UM LADO",
				"done_tip": ""},
				{"event": "bet_resolved", "text": "Veja a moeda cair",
				"spot": "", "caption": "",
				"done_tip": ""},
				{"event": "bet_leave", "text": "Clique em IR EMBORA para concluir",
				"spot": "bet_leave", "caption": "TERMINAR",
				"done_tip": ""},
			]
	return []

static func get_intro_lines() -> Array:
	return [
		"Olá! Eu sou o Guia e vou te ensinar os básicos desse mundo.",
		"Vou te acompanhar em 4 lições curtas: regras, Loja, Cartas e Leis, e Apostas.",
		"Para começar, siga a trilha: clique no nó brilhante do mapa.",
	]

static func get_duel1_intro_lines() -> Array:
	return [
		{"t": "Esta é seu primeiro duelo, os duelos sempre começam com uma peça decidindo que lado você irá jogar. Dessa vez será com as brancas, que sempre começam primeiro", "spot": "board"},
		{"t": "Peças andam na diagonal, uma casa por vez, sempre para frente. Capturar é pular sobre uma peça inimiga que tenha uma casa vazia logo atrás.", "spot": "board"},
		{"t": "Se existir uma captura, ela é OBRIGATÓRIA. A peça que pode capturar ganha um contorno amarelo pulsante — como esta.", "spot": "cell:3,4", "caption": "CAPTURA OBRIGATÓRIA"},
		{"t": "Chegando à última fileira inimiga, a peça é virada ao contrário se transformando em uma Dama que anda quantas casas quiser e captura para trás também.", "spot": "row:0", "caption": "FILEIRA DE COROAÇÃO"},
		"Vou te guiar passo a passo. Acompanhe os OBJETIVOS no canto da tela!",
	]

static func get_sudden_death_started_lines() -> Array:
	return [
		{"t": "Opa, o contador apareceu: é a MORTE SÚBITA! Ela começa quando alguém coroa uma Dama ou quando um lado fica com só 1 peça.", "spot": "sd_clock", "caption": "TURNOS RESTANTES"},
		"Quando os turnos acabam, vence quem tiver mais PONTOS em peças. Peça comum vale 1; Dama vale 3.",
		"Então agora vale decidir: jogar rápido e seguro, ou arriscar para vencer antes do tempo acabar.",
	]

# Mostrado quando o jogador vence o Duelo 1 SEM ter passado pela Morte Súbita:
# o Guia reinicia o tabuleiro para demonstrar o relógio na prática.
static func get_sudden_death_forced_lines() -> Array:
	return [
		"Boa vitória! Antes de seguir, deixa eu te mostrar uma coisa importante.",
		"A Morte Súbita começa quando um dos lados fica com só 1 peça viva, ou quando alguém promove uma Dama.",
		"Vou reiniciar esse tabuleiro rapidinho para você ver ela acontecendo na prática.",
	]

# Mostrado assim que a tela de recompensa de carta abre, explicando de
# onde as Cartas vêm antes do jogador escolher uma.
static func get_card_reward_explanation_lines() -> Array:
	return [
		"Toda vez que você vence um duelo normal, ganha a chance de escolher uma Carta nova — é assim que seu baralho cresce.",
		"Aqui é só uma demonstração: a escolha não vai para a sua run. Na Loja, a seguir, você compra as de verdade!",
	]

static func get_shop_intro_lines() -> Array:
	return [
		"Antes da Loja: ouro vem dos duelos, e na Loja ele vira poder. Preparei algum para você!",
	]

static func get_shop_lines() -> Array:
	return [
		{"t": "Bem-vindo à Loja! Aqui está o seu OURO.", "spot": "gold", "caption": "SEU OURO"},
		{"t": "No alto ficam as LEIS: são permanentes e mudam as regras da run inteira — como uma habilidade passiva que está sempre ligada.", "spot": "laws_row", "caption": "LEIS"},
		{"t": "Embaixo, são as CARTAS DE AÇÃO: você escolhe quando usar durante um duelo, só podendo usar apenas uma vez por duelo.", "spot": "cards_row", "caption": "CARTAS"},
		{"t": "REROLL troca as Cartas à venda (as Leis não mudam). REMOVER tira uma Carta do seu baralho — útil para deixá-lo mais afiado.", "spot": "shop_tools"},
		"Você pode ter até 6 Leis ao mesmo tempo. Com o quadro cheio, comprar outra pede que você escolha uma para descartar.",
		"Hora de comprar! Primeiro a Lei Segundo Movimento, depois pelo menos uma Carta. Vamos usá-las no próximo duelo.",
	]

# Logo depois da 1ª Lei comprada: o quadro de Leis acaba de descer do topo.
static func get_shop_law_board_lines() -> Array:
	return [
		{"t": "Comprada! Veja: a Lei foi direto para o seu QUADRO DE LEIS, que acabou de aparecer ali.", "spot": "law_board", "caption": "SEU QUADRO DE LEIS"},
		{"t": "Cada Lei ocupa um espaço, e cabem seis. Elas ficam sempre ligadas: durante os duelos esse quadro fica à esquerda, mostrando o que está valendo.", "spot": "law_board", "caption": "SEIS ESPAÇOS"},
		"Agora escolha uma CARTA, lá embaixo!",
	]

static func get_shop_done_lines() -> Array:
	return [
		"Ótimas compras! Leis e Cartas que você compra ficam com você pela run toda.",
		"Agora vamos testá-las num duelo de verdade.",
	]

static func get_duel3_intro_lines() -> Array:
	return [
		"Agora é um duelo de verdade: tabuleiro 8x8, com mais peças. Tudo que você comprou na Loja está aqui.",
		{"t": "Embaixo ficam as suas CARTAS. Passe o mouse em uma para ler o efeito.", "spot": "hand", "caption": "SUAS CARTAS"},
		{"t": "À esquerda, o quadro de LEIS: as que você comprou ficam ativas durante todo o duelo.", "spot": "law_board", "caption": "SUAS LEIS"},
		{"t": "À direita ficam as Leis do inimigo. Em duelos mais fortes ele também terá Leis e Cartas; aqui é treino, então está vazio.", "spot": "enemy_law_board", "caption": "LEIS DO INIMIGO"},
		"Siga os objetivos no canto da tela. Boa sorte!",
	]

static func get_bet_intro_lines() -> Array:
	return [
		{"t": "Chegamos à Mesa de Apostas! Aqui o ouro vai para a sorte.", "spot": "gold"},
		"A moeda tem dois lados: uma peça comum BRANCA e uma peça comum PRETA. Se cair o lado que você chamou, você ganha.",
		{"t": "Primeiro escolha o que arriscar. Com ouro, se acertar você ganha 80% a mais do valor apostado — e só dá para apostar até metade do seu ouro por vez. Na run de verdade você pode apostar quantas vezes quiser.", "spot": "bet_gold", "caption": "ARRISQUE OURO"},
		{"t": "Também dá para arriscar uma Carta ou uma Lei sua por uma versão melhor. Vale quando o item é fraco.", "spot": "bet_special"},
		"Depois você chama BRANCA ou PRETA. As Cartas e Leis de moeda dos duelos usam a mesma ideia: o efeito bom vale para quem joga com a COR que cair.",
		"Aposta é opcional na run de verdade — mas aqui, vamos treinar uma rodada. Arrisque o menor valor!",
	]

# Antes do Guia se despedir: como ler o mapa de verdade.
static func get_real_map_lines() -> Array:
	return [
		"Na jornada de verdade, o mapa tem caminhos que se dividem: você escolhe qual nó seguir, e os outros da fileira ficam para trás.",
		"Duelos dão ouro e Cartas; Elites são mais difíceis e pagam melhor; Lojas e Apostas servem para se preparar; no fim da trilha espera um Chefe.",
		"Um anel dourado marca onde você está, e os próximos nós possíveis ficam destacados. Escolha com calma!",
	]

# Antes da virada: o Guia segue sozinho até o fim da trilha (o mapa anima a
# peça dele subindo) — é isso que, sem querer, provoca a coroação.
static func get_flip_walk_lines() -> Array:
	return [
		"Bom, é isso! Vou indo na frente pela trilha, até a última fileira, para te esperar lá no fim.",
	]

# A virada ACIDENTAL: o Guia chega na última fileira e é coroado sem querer.
static func get_flip_lines() -> Array:
	return [
		{"crown": true, "t": "Ué?! Estou sendo coroado?! Eu cheguei na última fileira... Eu não queria ser coroado!", "shake": 0.3},
		{"t": "Claro... peça que chega na última fileira vira Dama. E Dama é só uma peça comum... VIRADA AO CONTRÁRIO", "shake": 0.2},
		{"t": "ELE NÃO...", "shake": 0.4},
		{"t": "Espera... NÃO! Foi sem querer! Eu estou sendo... VIRADO!", "shake": 0.8},
		{"flip": "evil", "t": "MUAHAHAHA!!! O GUIA SE COROOU SEM QUERER E A DAMA CAIU DO MEU LADO! Séculos esperando por esse acidente!", "shake": 1.0},
		{"who": "evil", "t": "Eu sou o IRMÃO do Guia. Ele é o lado de cima. Fofo. EU SOU O LADO DE BAIXO. MALVADO. Muito. Mas MUITO malvado MUSHUSMHUAAHAHAHAHAHMUHAHAHAHAMAUHAHAUAUMAAHUAAMUAHAUHAHAHAMAUHAHAUAHAUAUHUAMAUHAHAHAU.", "shake": 0.8},
		{"who": "evil", "t": "Você conhece a regra da captura obrigatória? EU FUI QUE FIZ! E NEM GOSTO DELA!", "shake": 1.0},
		{"who": "evil", "t": "TREMA DIANTE MINHA MALDADE JOGADOR! MUAHAHAHAHAHA!!!", "shake": 1.0},
	]

static func get_finished_lines() -> Array:
	return [
		"É isso! Você já sabe o essencial: regras, Morte Súbita, Loja, Cartas, Leis e Apostas.",
		"O resto você descobre jogando — cada run tem Leis e Cartas diferentes para combinar.",
		"Boa sorte lá fora. Até a próxima!",
	]

# Se o jogador venceu sem cumprir os objetivos (ex.: nunca usou uma Carta).
static func get_missed_objectives_lines(step: int) -> Array:
	if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		return [
			"Você venceu, mas deixou algumas coisas sem testar (veja o objetivo no canto da tela).",
			"Na run de verdade, Cartas e Leis fazem muita diferença — vale a pena experimentá-las sempre que puder.",
		]
	return [
		"Você venceu, mas deixou alguns objetivos de lado.",
		"Sem problemas — a prática vem jogando. Vamos em frente!",
	]

# Dica mostrada no mapa do tutorial quando o jogador perde o duelo.
static func get_retry_hint(step: int) -> String:
	if step == TutorialManager.Step.DUEL_1_BASICS:
		return "Não foi dessa vez! Dica: capturas são obrigatórias — use isso para empurrar o inimigo para uma troca boa. Tente de novo."
	if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		return "Não foi dessa vez! Dica: use as Cartas cedo — elas ajudam mais antes de o tabuleiro esvaziar. Tente de novo."
	return "Não foi dessa vez! Tente o mesmo duelo de novo."

# Dicas pontuais mostradas DURANTE o duelo, uma vez cada, por evento.
static func get_in_duel_tip(step: int, tip_id: String) -> String:
	# Dicas de inatividade valem para qualquer duelo do tutorial.
	if tip_id == "idle_hint":
		if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			return "Sem saber o que fazer? Selecione uma Carta na sua mão (embaixo) e clique no alvo, ou clique numa peça sua para ver os movimentos."
		return "Sem saber o que fazer? Clique em uma peça sua: as casas para onde ela pode ir ficam destacadas."
	if step == TutorialManager.Step.DUEL_1_BASICS:
		match tip_id:
			"mandatory_capture_shown":
				return "Viu o contorno amarelo pulsante? Essa peça TEM que capturar neste turno."
			"first_promotion":
				return "Chegou à última fileira! Essa peça virou Dama — agora anda para trás também."
	elif step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		match tip_id:
			"card_available":
				return "Suas Cartas estão prontas na mão — experimente cada uma para ver como funciona."
	return ""