class_name BossDialogue
extends RefCounted
# Personalidade e falas dos Chefes (uma por bioma). Para ajustar o tom ou o nome
# de um chefe, é só editar este arquivo. Eventos:
#   start / start_<id da lei>  : começo do duelo (a específica da lei tem prioridade)
#   win                        : o JOGADOR venceu (o chefe perdeu)
#   lose                       : o jogador perdeu
#   capture_boss               : o chefe capturou uma peça do jogador
#   piece_lost                 : o jogador capturou uma peça do chefe
#   promote_player / promote_boss
#   card_player                : o jogador usou uma carta
#   law_<tipo>                 : evento da lei do chefe (night, dawn, vines, trees,
#                                devour, sun, storm, quicksand, hourglass, cactus,
#                                sarcophagus, mummy)

const DATA := {
	"floresta": {
		"name": "MUSGO, O ANCIÃO",
		"tint": Color(0.55, 1.0, 0.5),
		"events": {
			"start": [
				"Opa, mais um querendo passar pela minha mata.",
				"Eu já tava aqui quando seus avós nem eram gente, sabia?",
				"Senta aí. As raízes não têm pressa nenhuma.",
				"Fazia tempo que ninguém aparecia. Tava até ficando cansado de ver pássaro.",
			],
			"start_frog_devourer": ["O sapo tá com fome hoje. Eu avisei.", "Cuidado com as moscas, viu. E com a língua também."],
			"start_owl_night": ["Quem manda na noite é a coruja, não eu. Eu só aviso.", "Quando escurecer, vai por mim, nem tenta enxergar."],
			"start_closing_forest": ["A mata vai fechando. Devagarzinho, mas fecha.", "Cada árvore nova é uma porta batendo na sua cara."],
			"start_vines": ["Os cipós sabem pra onde ir. Você não.", "Olha onde pisa, menino."],
			"start_fireflies": ["Segue a luzinha, vai. Segue.", "Vaga-lume mente que é uma beleza."],
			"start_hungry_roots": ["As raízes tão com fome. Sempre estiveram, na real.", "Não foi o chão que tremeu não. Foram elas."],
			"win": [
				"Hm. As raízes cederam. Dessa vez.",
				"Cortou fundo, hein. Pode passar, vai.",
				"A mata vai lembrar de você. Eu também, infelizmente.",
			],
			"lose": [
				"Mais um pro adubo.",
				"Volta quando deixar de ser muda, tá?",
				"As árvores nem precisaram se mexer, olha só.",
			],
			"capture_boss": ["Caiu igual folha em abril.", "Pras raízes essa.", "Foi um sopro só..."],
			"piece_lost": [
				"Ai! Essa doeu na raiz!",
				"Pera, pera, cuidado com a casca!",
				"Perdi uma folha. A árvore tá aí ainda.",
			],
			"promote_player": ["Coroa de galho? Que ousadia a sua.", "Coroado, é? Olha a pose do pirralho."],
			"promote_boss": ["Até árvore velha dá flor, ué.", "Coroa de musgo. Não tem melhor."],
			"card_player": ["Truquezinho de forasteiro...", "Carta? Aqui na mata ninguém usa isso.", "Hm. Essa eu nunca tinha visto."],
			"law_night": ["Shh. Já é hora da coruja."],
			"law_dawn": ["Amanheceu. A coruja foi dormir."],
			"law_vines": ["Os cipós mudaram de ideia de novo.", "Eles andam quando ninguém tá olhando."],
			"law_trees": ["Nasceu mais uma pra fechar o caminho.", "A mata cresce e você fica sem lugar."],
			"law_devour": ["Hora da boia do meu amigo!", "Nhac! Ouviu?"],
		},
	},
	"deserto": {
		"name": "O FARAÓ VAIDOSO",
		"tint": Color(1.0, 0.8, 0.35),
		"events": {
			"start": [
				"De joelhos pro FARAÓ! Ou joga direito, que já ajuda.",
				"Quatro mil anos esperando um rival à altura. E aparece você.",
				"Pode olhar. Eu deixo.",
				"Nossa, que sorte a sua, ver o faraó de pertinho.",
			],
			"start_scorching_sun": ["O Sol é meu espelho e ele ADORA me ver ganhando.", "Passou protetor, ou vai assar?"],
			"start_sandstorm": ["Tempestade? É só meu cabelo ao vento.", "Fecha o olho. Ou não, a vista é boa."],
			"start_quicksand": ["Olha o chão. A areia me obedece.", "Já ouviu falar de areia movediça? Ela já ouviu falar de você."],
			"start_hourglass": ["O tempo trabalha pra mim, tá?", "Tic-tac. O seu acaba primeiro."],
			"start_sarcophagi": ["Acordei meus ancestrais. Tão de MAU humor.", "Respeita a família. Eles mordem."],
			"start_cacti": ["Cacto! Bonitinho e cheio de espinho, que nem eu.", "Meu jardineiro é um gênio, não encosta nele."],
			"win": [
				"IMPOSSÍVEL! Mandem refazer o meu busto!",
				"Hmpf. Anota aí nos hieróglifos que eu deixei você ganhar.",
				"Meu reino de areia... tá desmoronando.",
			],
			"lose": [
				"Já era de se esperar. Eu sou perfeito.",
				"Vai pra coleção de múmias.",
				"Pode aplaudir. Aplaude.",
			],
			"capture_boss": ["Magnífico! Eu sou magnífico.", "Pelo Sol, tá feito.", "Fácil, fácil, que nem ser lindo."],
			"piece_lost": [
				"COMO ASSIM encostou nas MINHAS peças?!",
				"Esse arranhão vai sair caro, em ouro.",
				"Atrevido! Sabe quem eu sou?!",
			],
			"promote_player": ["Uma coroa? Pff, a minha é maior.", "Coroou! Que gracinha. Baratinha."],
			"promote_boss": ["Realeza reconhece realeza. Ou seja, eu.", "A coroa nasceu pra mim, simples assim."],
			"card_player": ["Truquezinho barato!", "Carta? Meu escriba usa pra anotar conta.", "Hm. Isso foi quase esperto."],
			"law_sun": ["Sente o abraço do deus Sol!", "Tá quentinho, né?"],
			"law_storm": ["Areia no olho! Meu perfume favorito.", "Ventinho gostoso, hein?"],
			"law_quicksand": ["O chão se mexeu. Ele gosta de mim.", "Olha o chão, olha o chão..."],
			"law_hourglass": ["Tic-tac. O tempo tá acabando.", "A areia escorre. A sua sorte junto."],
			"law_cactus": ["Olha o cacto! Meu jardineiro é um gênio.", "Espinho tá na moda no deserto."],
			"law_sarcophagus": ["Mais um parente acordando...", "Visita! Que bom."],
			"law_mummy": ["Levanta, primo! Tem gente nova aqui!", "A família cresceu. E bate."],
		},
	},
	"mina": {
		"name": "O GARIMPEIRO CEGO",
		"tint": Color(0.68, 0.58, 1.0),
		"events": {
			"start": [
				"Eu ouvi você chegando... ouvi duas vezes.",
				"Não precisa acenar. Eu não vejo. Mas escuto tudo.",
				"Quebrou? Quem disse que quebrou? Só passou a ter duas faces.",
				"Pisa mais leve. A mina conta tudo pra mim.",
			],
			"start_lantern": ["Meu lampião não serve pra mim. Serve pra você.", "Olha pra luz. Vai, olha."],
			"start_ricochet": ["Os cristais devolvem tudo. Até você.", "Aqui embaixo nada vai reto. Tudo volta."],
			"start_cave_in": ["Escuta o teto. Ele tá cansado.", "Cuidado onde para. A pedra cai onde quer."],
			"start_rails": ["Os trilhos ainda funcionam. Eu acho.", "Quem embarca na vagoneta não escolhe onde desce."],
			"start_nuggets": ["Ouro no chão! Eu sinto o brilho daqui.", "Três pepitas valem uma coroa. Regra da casa."],
			"win": [
				"Hm. O eco ficou mais baixo. Passa, passa.",
				"Ouvi você ganhar. Duas vezes. Doeu as duas.",
				"A mina é sua por hoje. Só por hoje.",
			],
			"lose": [
				"Silêncio. Era o que faltava.",
				"Mais um pedaço pra parede da mina.",
				"Eu nem precisei ver pra saber.",
			],
			"capture_boss": ["Escutei o estalo. Era seu.", "Tum! Ouviu? Nem eu.", "Essa ecoou bonito."],
			"piece_lost": [
				"Ei! Essa era das boas!",
				"Ouvi rachar... foi minha?",
				"Hmpf. Sorte de principiante, sorte de principiante.",
			],
			"promote_player": ["Coroa? Tô ouvindo ela tilintar.", "Coroou. O eco ficou mais pesado."],
			"promote_boss": ["Coroa de cristal. Brilha até no escuro.", "Mais uma pra minha coleção."],
			"card_player": ["Papel? Na mina? Vai molhar.", "Escutei a carta. Que barulhinho chato.", "Truque de gente que enxerga."],
			"law_lantern": ["Olha a luz! Olha a luz!", "Clarão! Eu nem pisquei."],
			"law_crystal": ["Mais um espelho pra você se perder.", "Brotou mais um. Ouvi o tilintar."],
			"law_cave_warn": ["Escuta... o teto tá falando.", "Crec. Crec. Ouviu?"],
			"law_cave_in": ["Desceu! Eu avisei, avisei.", "A mina tem fome de vez em quando."],
		},
	},
	"cume": {
		"name": "O ÚLTIMO MONTANHISTA",
		"tint": Color(0.66, 0.88, 1.0),
		"events": {
			"start": [
				"Chegou até aqui? Respira. Daqui pra cima o ar cobra.",
				"Faz tanto tempo que eu subo que esqueci de onde vim.",
				"O cume é logo ali. Sempre foi logo ali.",
				"Não olha pra baixo. Lá embaixo não tem mais nada.",
			],
			"start_frost": ["Quem para aqui em cima vira estátua. Mexe esses pés.", "Sozinho no frio ninguém dura três turnos."],
			"start_ice": ["Pisa no gelo e ele escolhe por você.", "O chão aqui não segura ninguém. Nem eu."],
			"start_avalanche": ["Escuta a montanha. Ela tá juntando força.", "Quando a neve desce, ela não pede licença."],
			"start_rope": ["Ninguém sobe sozinho. A corda segura os meus.", "Puxa um, vem o outro. Regra de montanha."],
			"start_thin_air": ["Aqui em cima falta ar. Pra você, pelo menos.", "Chegar perto do topo cansa. Eu sei bem."],
			"start_polar": ["A aurora protege quem é daqui.", "Olha pro céu. Ele tá do meu lado."],
			"win": [
				"Eu ainda estou subindo. Não tem como ter acabado.",
				"O topo... era isso? Só vento?",
				"Vai. Sobe você. Eu fico mais um pouco.",
			],
			"lose": [
				"A montanha guarda quem cai.",
				"Mais um que não aguentou o frio.",
				"Desce. Lá embaixo é mais quente.",
			],
			"capture_boss": ["Escorregou. Acontece.", "O frio leva um de cada vez.", "Essa ficou na neve."],
			"piece_lost": [
				"Ei! Essa estava amarrada comigo!",
				"Perdi uma. A montanha cobra de todo mundo.",
				"Hmpf. Foi o vento. Só pode ter sido o vento.",
			],
			"promote_player": ["Coroa no frio pesa o dobro.", "Coroou? Lá em cima ninguém repara."],
			"promote_boss": ["Uma coroa de gelo. Não derrete nunca.", "Chegou embaixo e voltou rainha. Bonito."],
			"card_player": ["Papel no vento? Segura firme.", "Truque de gente que mora embaixo.", "Carta molhada de neve não vale nada."],
			"law_freeze": ["Ficou parada demais. Agora é gelo.", "Congelou. Eu avisei pra se mexer."],
			"law_thaw": ["Esquentou? Por pouco tempo.", "Junto todo mundo esquenta. Sorte sua."],
			"law_avalanche_warn": ["Ouviu esse estalo? É a encosta.", "A neve tá escorregando lá em cima."],
			"law_avalanche": ["Lá vem ela!", "Desceu tudo! Segura aí!"],
			"law_rope_break": ["A corda arrebentou! Quem esticou demais?", "Corda velha. Tinha que acontecer."],
			"law_rope_tie": ["Amarrei de novo. Pode vir.", "Corda nova. Quero ver você puxar.", "Quem cai, puxa o outro pra cima."],
			"law_winded": ["Sem fôlego? Senta, respira.", "O ar aqui é meu."],
			"law_polar": ["Olha a aurora!", "O céu acendeu de novo."],
		},
	},
	"caldeira": {
		"name": "A FERREIRA DA CALDEIRA",
		"tint": Color(1.0, 0.62, 0.32),
		"events": {
			"start": [
				"Entra, entra. Cuidado com o chão, ele ainda tá quente.",
				"Toda coroa que existe passou por esta bigorna. Toda.",
				"Você chegou na hora. A fornada tá quase no ponto.",
				"Senta não. Aqui ninguém senta. Aqui se trabalha.",
			],
			"win": [
				"Nada quebrou. Só estava esperando a próxima fornada.",
				"Hm. Saiu torta. Volta pro fogo e sai melhor.",
				"Pode levar. Mas fui eu que fiz, tá? Não esquece.",
			],
			"lose": [
				"Peça mole não aguenta a forja.",
				"Volta pro molde. Quem sabe sai coisa melhor.",
				"Derreteu. Acontece com quem não é temperado.",
			],
			"capture_boss": ["Pro caldeirão essa.", "Vira metal de novo.", "Martelada certa, peça a menos."],
			"piece_lost": [
				"Ai! Essa tava quase pronta!",
				"Arranhou o acabamento!",
				"Tudo bem. Tenho molde pra mais umas mil.",
			],
			"promote_player": ["Coroa sem forja? Quem fez essa porcaria?", "Coroou sozinho? Deixa eu ver o acabamento."],
			"promote_boss": ["Essa saiu do meu martelo. Olha o brilho.", "Coroa nova, direto da bigorna."],
			"card_player": ["Papel perto do fogo? Corajoso.", "Truque bonito. Pena que queima.", "Isso aí não aguenta a temperatura daqui."],
		},
	},
}

static func boss_name(biome: String) -> String:
	return str(DATA.get(biome, DATA["floresta"]).get("name", "CHEFE"))

static func boss_tint(biome: String) -> Color:
	return DATA.get(biome, DATA["floresta"]).get("tint", Color.WHITE)

# Sorteia uma fala do evento (a específica da lei vem primeiro). `last` evita
# repetir a mesma fala em sequência. Devolve "" se não houver.
static func pick(biome: String, event: String, law_id: String = "", last: String = "") -> String:
	var events: Dictionary = DATA.get(biome, DATA["floresta"])["events"]
	var key: String = event
	if event == "start" and events.has("start_" + law_id):
		key = "start_" + law_id
	var pool: Array = events.get(key, [])
	if pool.is_empty():
		return ""
	var options: Array = pool.filter(func(s): return s != last)
	if options.is_empty():
		options = pool
	return str(options[randi() % options.size()])
