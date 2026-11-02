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
		{"t": "Olha só! Sua Lei agiu sozinha, o letreiro mostra qual foi. Ela vale toda vez que a condição dela rolar.", "spot": "law_board", "caption": "SUAS LEIS"},
		"Quer reler o que cada Lei faz? Passa o mouse em cima dela no quadro.",
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
		"E aí! Eu sou o Guia e vou te mostrar o básico por aqui.",
		"São 4 lições rapidinhas: regras, Loja, Cartas e Leis, e Apostas.",
		"Pra começar, segue a trilha: clica no nó brilhante do mapa.",
	]

static func get_duel1_intro_lines() -> Array:
	return [
		{"t": "Esse é o seu primeiro duelo. Todo duelo começa com uma moeda decidindo o seu lado. Dessa vez você é as brancas, que sempre jogam primeiro.", "spot": "board"},
		{"t": "As peças andam na diagonal, uma casa por vez, sempre pra frente. Capturar é pular por cima de uma peça inimiga que tenha casa vazia logo atrás.", "spot": "board"},
		{"t": "Se tiver captura, você TEM que fazer. A peça que pode capturar fica com um contorno amarelo piscando, igual essa aqui.", "spot": "cell:3,4", "caption": "CAPTURA OBRIGATÓRIA"},
		{"t": "Chegou na última fileira do inimigo? A peça é virada de cabeça pra baixo e vira Dama: anda quantas casas quiser e captura pra trás também.", "spot": "row:0", "caption": "FILEIRA DE COROAÇÃO"},
		"Eu vou te guiando. Fica de olho nos OBJETIVOS no canto da tela!",
	]

static func get_sudden_death_started_lines() -> Array:
	return [
		{"t": "Opa, apareceu um contador: é a MORTE SÚBITA! Ela começa quando alguém coroa uma Dama ou quando um lado fica com só 1 peça.", "spot": "sd_clock", "caption": "TURNOS RESTANTES"},
		"Quando os turnos acabam, ganha quem tiver mais PONTOS em peças. Peça comum vale 1 e Dama vale 3.",
		"Aí é decidir: joga seguro, ou arrisca pra ganhar antes do tempo acabar.",
	]

# Mostrado quando o jogador vence o Duelo 1 SEM ter passado pela Morte Súbita:
# o Guia reinicia o tabuleiro para demonstrar o relógio na prática.
static func get_sudden_death_forced_lines() -> Array:
	return [
		"Boa, ganhou! Antes de seguir, deixa eu te mostrar uma coisa importante.",
		"A Morte Súbita começa quando um dos lados fica com só 1 peça viva, ou quando alguém promove uma Dama.",
		"Vou reiniciar o tabuleiro rapidinho pra você ver isso acontecendo.",
	]

# Mostrado assim que a tela de recompensa de carta abre, explicando de
# onde as Cartas vêm antes do jogador escolher uma.
static func get_card_reward_explanation_lines() -> Array:
	return [
		"Todo duelo normal que você ganha te deixa escolher uma Carta nova. É assim que o baralho cresce.",
		"Aqui é só demonstração, a escolha não vai pra sua run. Na Loja, logo depois, você compra as de verdade!",
	]

static func get_shop_intro_lines() -> Array:
	return [
		"Antes da Loja: o ouro vem dos duelos, e na Loja vira poder. Separei um pouco pra você!",
	]

static func get_shop_lines() -> Array:
	return [
		{"t": "Bem-vindo à Loja! Esse aqui é o seu OURO.", "spot": "gold", "caption": "SEU OURO"},
		{"t": "Lá em cima ficam as LEIS: elas são permanentes e mudam as regras da run inteira, tipo uma habilidade passiva sempre ligada.", "spot": "laws_row", "caption": "LEIS"},
		{"t": "Embaixo ficam as CARTAS DE AÇÃO: você escolhe a hora de usar no duelo, mas só uma vez por duelo.", "spot": "cards_row", "caption": "CARTAS"},
		{"t": "REROLL troca as Cartas à venda (as Leis não mudam). REMOVER tira uma Carta do seu baralho, bom pra deixar ele mais afiado.", "spot": "shop_tools"},
		"Dá pra ter até 6 Leis ao mesmo tempo. Com o quadro cheio, comprar outra te obriga a descartar uma.",
		"Bora comprar! Primeiro a Lei Segundo Movimento, depois pelo menos uma Carta. A gente usa no próximo duelo.",
	]

# Logo depois da 1ª Lei comprada: o quadro de Leis acaba de descer do topo.
static func get_shop_law_board_lines() -> Array:
	return [
		{"t": "Comprou! Olha só: a Lei foi direto pro seu QUADRO DE LEIS, que acabou de aparecer ali.", "spot": "law_board", "caption": "SEU QUADRO DE LEIS"},
		{"t": "Cada Lei ocupa um espaço e cabem seis. Elas ficam sempre ligadas, e nos duelos esse quadro fica à esquerda mostrando o que tá valendo.", "spot": "law_board", "caption": "SEIS ESPAÇOS"},
		"Agora pega uma CARTA, lá embaixo!",
	]

static func get_shop_done_lines() -> Array:
	return [
		"Boas compras! Leis e Cartas que você compra ficam com você a run toda.",
		"Vamos testar isso num duelo de verdade.",
	]

static func get_duel3_intro_lines() -> Array:
	return [
		"Agora é duelo de verdade: tabuleiro 8x8, mais peças. Tudo que você comprou na Loja tá aqui.",
		{"t": "Embaixo ficam as suas CARTAS. Passa o mouse em uma pra ler o efeito.", "spot": "hand", "caption": "SUAS CARTAS"},
		{"t": "À esquerda tá o quadro de LEIS: as que você comprou ficam ativas o duelo inteiro.", "spot": "law_board", "caption": "SUAS LEIS"},
		{"t": "À direita ficam as Leis do inimigo. Nos duelos mais fortes ele também tem Leis e Cartas. Aqui é treino, então tá vazio.", "spot": "enemy_law_board", "caption": "LEIS DO INIMIGO"},
		"Segue os objetivos no canto da tela. Boa sorte!",
	]

static func get_bet_intro_lines() -> Array:
	return [
		{"t": "Chegamos na Mesa de Apostas! Aqui o ouro vai pra sorte.", "spot": "gold"},
		"A moeda tem dois lados: uma peça comum BRANCA e uma PRETA. Se cair o lado que você chamou, você ganha.",
		{"t": "Primeiro escolha o que arriscar. Com ouro, se acertar você ganha 80% a mais do valor apostado — e só dá para apostar até metade do seu ouro por vez. Na run de verdade você pode apostar quantas vezes quiser.", "spot": "bet_gold", "caption": "ARRISQUE OURO"},
		{"t": "Também dá para arriscar uma Carta ou uma Lei sua por uma versão melhor. Vale quando o item é fraco.", "spot": "bet_special"},
		"Depois você chama BRANCA ou PRETA. As Cartas e Leis de moeda nos duelos seguem a mesma ideia: o efeito bom fica com quem joga na COR que cair.",
		"Na run de verdade aposta é opcional, mas aqui vamos treinar uma rodada. Arrisca o menor valor!",
	]

# Antes do Guia se despedir: como ler o mapa de verdade.
static func get_real_map_lines() -> Array:
	return [
		"Na jornada de verdade o mapa se divide em caminhos: você escolhe um nó, e os outros daquela fileira ficam pra trás.",
		"Duelo dá ouro e Cartas. Elite é mais difícil e paga melhor. Loja e Aposta servem pra se preparar. E no fim da trilha tem um Chefe esperando.",
		"Um anel dourado marca onde você tá, e os próximos nós possíveis ficam destacados. Escolhe com calma!",
	]

# Antes da virada: o Guia segue sozinho até o fim da trilha (o mapa anima a
# peça dele subindo) — é isso que, sem querer, provoca a coroação.
static func get_flip_walk_lines() -> Array:
	return [
		"Bom, é isso! Vou indo na frente pela trilha, até a última fileira, te espero lá no fim.",
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
		"O resto você descobre jogando. Cada run tem Leis e Cartas diferentes pra combinar.",
		"Boa sorte lá fora. Até mais!",
	]

# Se o jogador venceu sem cumprir os objetivos (ex.: nunca usou uma Carta).
static func get_missed_objectives_lines(step: int) -> Array:
	if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		return [
			"Você ganhou, mas ficou coisa sem testar (olha o objetivo no canto da tela).",
			"Na run de verdade, Cartas e Leis fazem muita diferença. Vale experimentar sempre que der.",
		]
	return [
		"Você ganhou, mas deixou uns objetivos de lado.",
		"Sem problema, a prática vem jogando. Bora em frente!",
	]

# Dica mostrada no mapa do tutorial quando o jogador perde o duelo.
static func get_retry_hint(step: int) -> String:
	if step == TutorialManager.Step.DUEL_1_BASICS:
		return "Não foi dessa vez! Dica: captura é obrigatória, então usa isso pra empurrar o inimigo pra uma troca boa. Tenta de novo."
	if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		return "Não foi dessa vez! Dica: usa as Cartas cedo, elas ajudam mais antes do tabuleiro esvaziar. Tenta de novo."
	return "Não foi dessa vez! Tenta o mesmo duelo de novo."

# Dicas pontuais mostradas DURANTE o duelo, uma vez cada, por evento.
static func get_in_duel_tip(step: int, tip_id: String) -> String:
	# Dicas de inatividade valem para qualquer duelo do tutorial.
	if tip_id == "idle_hint":
		if step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
			return "Sem saber o que fazer? Seleciona uma Carta na mão (embaixo) e clica no alvo, ou clica numa peça sua pra ver os movimentos."
		return "Sem saber o que fazer? Clica numa peça sua: as casas pra onde ela pode ir ficam destacadas."
	if step == TutorialManager.Step.DUEL_1_BASICS:
		match tip_id:
			"mandatory_capture_shown":
				return "Viu o contorno amarelo piscando? Essa peça TEM que capturar agora."
			"first_promotion":
				return "Chegou na última fileira! Essa peça virou Dama, agora anda pra trás também."
	elif step == TutorialManager.Step.DUEL_3_CARDS_AND_LAWS:
		match tip_id:
			"card_available":
				return "Suas Cartas tão prontas na mão. Testa cada uma pra ver como funciona."
	return ""