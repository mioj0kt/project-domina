class_name BossDialogue
extends RefCounted
# Personalidade, voz e falas dos Chefes (um por bioma). Para ajustar o tom ou o nome
# de um chefe, é só editar este arquivo.
#
# Cada chefe tem um jeito próprio de falar (e de soar):
#   Musgo (floresta)       : avô da roça, lento, esquecido, cochila no meio da fala;
#                            mede tudo em estações. Voz de madeira grave, fala devagar.
#   Faraó (deserto)        : fala de si na 3ª pessoa, CAPS quando se empolga, vive do
#                            próprio reflexo e exige aplauso. Voz de metal dourado.
#   Garimpeiro (mina)      : cego, ouve tudo; repete palavras como eco, sussurra, conta
#                            coisas e conversa com a mina. Voz oca com eco atrás.
#   Montanhista (cume)     : cansado, poucas palavras, gentil e melancólico; conselho
#                            de montanha e um tremor de frio. Voz soprada e trêmula.
#   Ferreira (caldeira)    : mestra de oficina, mandona e perfeccionista; tudo é
#                            fornada, liga, têmpera e acabamento. Voz firme com "tim".
#
# Campos de voz: voice = grupo do Sfx tocado a cada letra; intro = som da entrada;
# cps = letras por segundo; pause = quanto ela segura nas pontuações (1 = normal);
# pitch_spread = quanto o tom de cada letra varia (fala mais "cantada" ou mais reta).
#
# Eventos:
#   start / start_<id da lei>  : começo do duelo (fala de personalidade e, logo
#                                depois, a que apresenta a lei sorteada)
#   win / lose                 : o JOGADOR venceu / perdeu
#   capture_boss / piece_lost  : o chefe capturou / o jogador capturou
#   multi_capture / boss_combo : o jogador / o chefe capturou 2+ de uma vez
#   boss_low / player_low      : o chefe / o jogador ficou com 3 peças ou menos
#   promote_player / promote_boss
#   card_player                : o jogador usou uma carta
#   sudden_death               : começou a Morte Súbita
#   idle                       : o jogador está pensando há muito tempo
#   law_<tipo>                 : evento da lei do chefe

const DATA := {
	"floresta": {
		"name": "MUSGO, O ANCIÃO",
		"tint": Color(0.55, 1.0, 0.5),
		"voice": "voz_musgo", "intro": "boss_intro_floresta", "cps": 27.0, "pause": 1.5, "pitch_spread": 0.03,
		"events": {
			"start": [
				"Opa, mais um querendo passar pela minha mata.",
				"Eu já tava aqui quando seus avós nem eram gente, sabia?",
				"Senta aí, menino. As raízes não têm pressa nenhuma.",
				"Fazia tempo que ninguém aparecia. Tava até ficando cansado de ver pássaro.",
				"Quebrou o quê? Nada quebrou. É só outra estação, ué.",
				"Hã? Ah, é você. Eu tava... é... onde é que eu tava mesmo?",
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
				"Tá bom, tá bom. Na próxima primavera eu te pego.",
			],
			"lose": [
				"Mais um pro adubo.",
				"Volta quando deixar de ser muda, tá?",
				"As árvores nem precisaram se mexer, olha só.",
				"Ganhei? Ganhei. Acordei bem na hora.",
			],
			"capture_boss": ["Caiu igual folha em abril.", "Pras raízes essa.", "Foi um sopro só...", "Outono chegou cedo pra você."],
			"piece_lost": [
				"Ai! Essa doeu na raiz!",
				"Pera, pera, cuidado com a casca!",
				"Perdi uma folha. A árvore tá aí ainda.",
				"Era minha preferida. Acho. Esqueci o nome dela.",
			],
			"multi_capture": ["Opa, opa! Que machadada foi essa?!", "Levou meio pomar de uma vez, ladrão!", "Calma, menino! Isso aí é desmatamento!"],
			"boss_combo": ["Hehe. Raiz puxa raiz.", "Uma, duas... perdi a conta. Mas foi bom.", "O velho ainda tem seiva!"],
			"boss_low": ["Hm. Tô ficando careca de folha.", "Inverno, é? Eu já passei por uns mil.", "Tudo bem. Árvore pelada ainda é árvore."],
			"player_low": ["Ih, ficou ralinho, hein.", "Tá sobrando pouco broto aí, menino.", "Já pensou em plantar umas peças novas?"],
			"promote_player": ["Coroa de galho? Que ousadia a sua.", "Coroado, é? Olha a pose do pirralho.", "No meu tempo coroa se ganhava com idade."],
			"promote_boss": ["Até árvore velha dá flor, ué.", "Coroa de musgo. Não tem melhor.", "Florzinha nova no galho velho."],
			"card_player": ["Truquezinho de forasteiro...", "Carta? Aqui na mata ninguém usa isso.", "Hm. Essa eu nunca tinha visto.", "Papel é árvore morta, sabia? Respeito, menino."],
			"sudden_death": ["Hora de o sol se pôr. Bem rapidinho.", "Ih, apressou. Eu odeio pressa.", "Agora é o vento que manda. Segura o chapéu."],
			"idle": ["Pensa, pensa. Eu cochilo enquanto isso... zzz...", "Hã? Ah. Ainda é a sua vez? Eu nem notei.", "Leva o tempo que quiser. Eu tenho uns quinhentos anos.", "Quer um conselho? Eu não lembro de nenhum."],
			"law_night": ["Shh. Já é hora da coruja.", "Escureceu. Vai, tenta adivinhar onde eu tô."],
			"law_dawn": ["Amanheceu. A coruja foi dormir.", "Sol de novo. Eu tava gostando do escuro."],
			"law_vines": ["Os cipós mudaram de ideia de novo.", "Eles andam quando ninguém tá olhando."],
			"law_trees": ["Nasceu mais uma pra fechar o caminho.", "A mata cresce e você fica sem lugar."],
			"law_devour": ["Hora da boia do meu amigo!", "Nhac! Ouviu?"],
		},
	},
	"deserto": {
		"name": "O FARAÓ VAIDOSO",
		"tint": Color(1.0, 0.8, 0.35),
		"voice": "voz_farao", "intro": "boss_intro_deserto", "cps": 34.0, "pause": 1.3, "pitch_spread": 0.06,
		"events": {
			"start": [
				"De joelhos pro FARAÓ! Ou joga direito, que já ajuda.",
				"Quatro mil anos esperando um rival à altura. E aparece você.",
				"Pode olhar. O Faraó deixa.",
				"Nossa, que sorte a sua, ver o Faraó de pertinho.",
				"O mundo girou? Mentira. O Faraó é o centro. O resto que girou.",
				"Um passo de cada vez, plebeu. Realeza não corre.",
			],
			"start_scorching_sun": ["O Sol é meu espelho e ele ADORA me ver ganhando.", "Passou protetor, ou vai assar?"],
			"start_sandstorm": ["Tempestade? É só meu cabelo ao vento.", "Fecha o olho. Ou não, a vista é boa."],
			"start_quicksand": ["Olha o chão. A areia me obedece.", "Já ouviu falar de areia movediça? Ela já ouviu falar de você."],
			"start_hourglass": ["O tempo trabalha pra mim, tá?", "Tic-tac. O seu acaba primeiro."],
			"start_sarcophagi": ["Acordei meus ancestrais. Tão de MAU humor.", "Respeita a família. Eles mordem."],
			"start_cacti": ["Cacto! Bonitinho e cheio de espinho, que nem eu.", "Meu jardineiro é um gênio, não encosta nele."],
			"win": [
				"IMPOSSÍVEL! Mandem refazer o meu busto!",
				"Hmpf. Anota aí nos hieróglifos que o Faraó DEIXOU você ganhar.",
				"Meu reino de areia... tá desmoronando.",
				"Escriba! Apaga isso! Ninguém viu nada!",
			],
			"lose": [
				"Já era de se esperar. O Faraó é perfeito.",
				"Vai pra coleção de múmias.",
				"Pode aplaudir. Aplaude. Mais alto.",
				"Mandem esculpir isso em ouro. Em DOIS ouros.",
			],
			"capture_boss": ["Magnífico! O Faraó é magnífico.", "Pelo Sol, tá feito.", "Fácil, fácil, que nem ser lindo.", "Ajoelha. Ah, ela caiu. Serve também."],
			"piece_lost": [
				"COMO ASSIM encostou nas MINHAS peças?!",
				"Esse arranhão vai sair caro, em ouro.",
				"Atrevido! Sabe quem eu sou?!",
				"Era só uma serva. O Faraó tem milhares. Milhares!",
			],
			"multi_capture": ["GUARDAS! GUARDAS! Alguém faz alguma coisa!", "Isso é um GOLPE de Estado!", "Vou mandar enterrar você numa pirâmide pequena!"],
			"boss_combo": ["Duas de uma vez! Mais rápido que o Sol nascendo!", "Viu? Até minhas jogadas são lindas.", "Aplaude essa. Eu espero."],
			"boss_low": ["O Faraó não está perdendo. Está... economizando.", "Menos peças, mais espaço pro meu brilho.", "Calma, calma. A coroa ainda tá no lugar."],
			"player_low": ["Sobrou pouquinho, hein? Que dó. Dó nenhuma.", "Sua corte tá mais vazia que tumba saqueada.", "Quer se render com elegância? Eu ensino."],
			"promote_player": ["Uma coroa? Pff, a minha é maior.", "Coroou! Que gracinha. Baratinha.", "Coroa de plebeu brilha menos. É ciência."],
			"promote_boss": ["Realeza reconhece realeza. Ou seja, eu.", "A coroa nasceu pra mim, simples assim.", "Mais uma coroa. Combina com a minha."],
			"card_player": ["Truquezinho barato!", "Carta? Meu escriba usa pra anotar conta.", "Hm. Isso foi quase esperto.", "Cartas! Que coisa de quem não tem pirâmide."],
			"sudden_death": ["A areia do relógio tá acabando. A SUA.", "Pressa? O Faraó nunca tem pressa. Mas você devia.", "Agora o Sol vai assistir de perto."],
			"idle": ["O Faraó não espera ninguém. Mas tá esperando. Viu que honra?", "Tá admirando meu perfil? Pode. Mas joga.", "Escriba, anota: o rival travou de emoção.", "Pensa rápido. Minha maquiagem tá derretendo."],
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
		"voice": "voz_garimpeiro", "intro": "boss_intro_mina", "cps": 30.0, "pause": 1.8, "pitch_spread": 0.07,
		"events": {
			"start": [
				"Eu ouvi você chegando... ouvi duas vezes. Duas vezes.",
				"Não precisa acenar. Eu não vejo. Mas escuto tudo. Tudo.",
				"Quebrou? Quem disse que quebrou? Só passou a ter duas faces.",
				"Pisa mais leve. A mina conta tudo pra mim.",
				"Shh. Escuta. A pedra tá falando de você.",
				"Cento e doze passos até aqui. Contei. Contei.",
			],
			"start_lantern": ["Meu lampião não serve pra mim. Serve pra você.", "Olha pra luz. Vai, olha."],
			"start_ricochet": ["Os cristais devolvem tudo. Até você.", "Aqui embaixo nada vai reto. Tudo volta."],
			"start_cave_in": ["Escuta o teto. Ele tá cansado.", "Cuidado onde para. A pedra cai onde quer."],
			"start_rails": ["Os trilhos ainda funcionam. Eu acho.", "Quem embarca na vagoneta não escolhe onde desce."],
			"start_nuggets": ["Ouro no chão! Eu sinto o brilho daqui.", "Três pepitas valem uma coroa. Regra da casa."],
			"win": [
				"Hm. O eco ficou mais baixo. Passa, passa.",
				"Ouvi você ganhar. Duas vezes. Doeu as duas.",
				"A mina é sua por hoje. Só por hoje. Hoje.",
				"Tá. Leva. Mas a mina não esquece. Ela anota na pedra.",
			],
			"lose": [
				"Silêncio. Era o que faltava.",
				"Mais um pedaço pra parede da mina.",
				"Eu nem precisei ver pra saber.",
				"Escutou isso? Foi o fim. O seu. O seu.",
			],
			"capture_boss": ["Escutei o estalo. Era seu.", "Tum! Ouviu? Nem eu.", "Essa ecoou bonito. Bonito.", "Uma a menos. Uma. Contei."],
			"piece_lost": [
				"Ei! Essa era das boas!",
				"Ouvi rachar... foi minha? Foi minha.",
				"Hmpf. Sorte de principiante, sorte de principiante.",
				"Quem fez isso? Eu ouvi. Eu sei que foi você.",
			],
			"multi_capture": ["Crec, crec, crec! Quantas foram? Quantas?!", "Isso foi um desabamento! Um desabamento!", "Para! O eco não dá conta de tanto barulho!"],
			"boss_combo": ["Tum, tum! Duas! Ouviu? Duas!", "O eco gostou dessa. Repete, repete.", "Contei duas. A mina contou três. A mina exagera."],
			"boss_low": ["Tá ficando quieto aqui... quieto demais.", "Ouço menos passos meus. Menos. Menos.", "A mina tá me chamando pro fundo. Ainda não, ainda não."],
			"player_low": ["Seus passos tão ficando sozinhos. Sozinhos.", "Escuto só uns tec-tec do seu lado. Poucos.", "Tá com eco aí. Eco de vazio."],
			"promote_player": ["Coroa? Tô ouvindo ela tilintar.", "Coroou. O eco ficou mais pesado.", "Tlim. Coroa nova. Barulho de ouro roubado."],
			"promote_boss": ["Coroa de cristal. Brilha até no escuro.", "Mais uma pra minha coleção.", "Ouviu o tlim? É meu. É meu."],
			"card_player": ["Papel? Na mina? Vai molhar.", "Escutei a carta. Que barulhinho chato.", "Truque de gente que enxerga.", "Shhh... papel farfalhando. Eu odeio papel farfalhando."],
			"sudden_death": ["O teto tá descendo. Todo. Todo.", "Escuta... o relógio da pedra começou a correr.", "Agora é rápido. A mina não espera."],
			"idle": ["Tá quieto... tá respirando ainda? Respira alto, que eu não vejo.", "Silêncio... eu adoro silêncio. Mas mexe.", "Contando seus segundos. Trinta e um. Trinta e dois.", "Tá aí? Tá aí? Faz um barulho."],
			"law_lantern": ["Olha a luz! Olha a luz!", "Clarão! Eu nem pisquei."],
			"law_crystal": ["Mais um espelho pra você se perder.", "Brotou mais um. Ouvi o tilintar."],
			"law_cave_warn": ["Escuta... o teto tá falando.", "Crec. Crec. Ouviu?"],
			"law_cave_in": ["Desceu! Eu avisei, avisei.", "A mina tem fome de vez em quando."],
			"law_nugget_spawn": ["Pepita nova! Sinto daqui. Sinto.", "Ouro brotou. Pega antes de mim. Se conseguir."],
		},
	},
	"cume": {
		"name": "O ÚLTIMO MONTANHISTA",
		"tint": Color(0.66, 0.88, 1.0),
		"voice": "voz_montanhista", "intro": "boss_intro_cume", "cps": 25.0, "pause": 2.0, "pitch_spread": 0.025,
		"events": {
			"start": [
				"Chegou até aqui? Respira. Daqui pra cima o ar cobra.",
				"Faz tanto tempo que eu subo que esqueci de onde vim.",
				"O cume é logo ali. Sempre foi logo ali.",
				"Não olha pra baixo. Lá embaixo não tem mais nada.",
				"Acabou? Não. Eu ainda estou subindo. Não tem como ter acabado.",
				"B-brr. Senta um pouco. Não, melhor não. Quem senta aqui não levanta.",
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
				"Boa escalada. De verdade. Faz tempo que ninguém chega tão alto.",
			],
			"lose": [
				"A montanha guarda quem cai.",
				"Mais um que não aguentou o frio.",
				"Desce. Lá embaixo é mais quente.",
				"Não é vergonha voltar. Vergonha é não ter subido.",
			],
			"capture_boss": ["Escorregou. Acontece.", "O frio leva um de cada vez.", "Essa ficou na neve.", "Pegada errada. A montanha não perdoa."],
			"piece_lost": [
				"Ei! Essa estava amarrada comigo!",
				"Perdi uma. A montanha cobra de todo mundo.",
				"Hmpf. Foi o vento. Só pode ter sido o vento.",
				"Era da primeira expedição. A última que sobrava.",
			],
			"multi_capture": ["Avalanche sua, é? Bonito. Assustador, mas bonito.", "Levou a cordada inteira. Ai.", "Calma. Isso é montanha, não corrida."],
			"boss_combo": ["Uma, outra. A neve leva em fila.", "Quem anda junto cai junto.", "Desceu tudo de uma vez. Eu avisei do gelo."],
			"boss_low": ["Ficando sozinho de novo. Já me acostumei.", "Poucos na corda. Mas a corda ainda segura.", "Tudo bem. Eu sempre subo sozinho no fim."],
			"player_low": ["Sua cordada tá curta. Cuidado no próximo passo.", "Pouca gente, pouco calor. O frio sente isso.", "Respira. Ainda dá pra descer com dignidade."],
			"promote_player": ["Coroa no frio pesa o dobro.", "Coroou? Lá em cima ninguém repara.", "Bonita. Não deixa congelar."],
			"promote_boss": ["Uma coroa de gelo. Não derrete nunca.", "Chegou embaixo e voltou rainha. Bonito.", "Mais uma no topo. Finalmente alguém chegou."],
			"card_player": ["Papel no vento? Segura firme.", "Truque de gente que mora embaixo.", "Carta molhada de neve não vale nada.", "Isso aí esquenta? Não? Então não serve."],
			"sudden_death": ["O tempo virou. Agora é descer ou ficar.", "Tempestade chegando. Sem tempo pra pensar.", "Ar acabando. Pra nós dois."],
			"idle": ["Tá tudo bem. Eu espero. Esperar é o que eu mais faço.", "B-brr. Pensa logo, que o frio não pensa.", "Olhando o caminho? Faz bem. Só não demora.", "Eu já esperei séculos. Mais um pouco não mata. Ou mata."],
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
		"voice": "voz_ferreira", "intro": "boss_intro_caldeira", "cps": 42.0, "pause": 0.9, "pitch_spread": 0.04,
		"events": {
			"start": [
				"Entra, entra. Cuidado com o chão, ele ainda tá quente.",
				"Toda coroa que existe passou por esta bigorna. Toda.",
				"Você chegou na hora. A fornada tá quase no ponto.",
				"Senta não. Aqui ninguém senta. Aqui se trabalha.",
				"Quebrou? Nada quebrou. Só estava esperando a próxima fornada.",
				"Meu aprendiz falou de você. Tremendo. Ele treme por tudo.",
			],
			"win": [
				"Nada quebrou. Só estava esperando a próxima fornada.",
				"Hm. Saiu torta. Volta pro fogo e sai melhor.",
				"Pode levar. Mas fui eu que fiz, tá? Não esquece.",
				"Tá bom. Acabamento decente. Decente. Não fica se achando.",
			],
			"lose": [
				"Peça mole não aguenta a forja.",
				"Volta pro molde. Quem sabe sai coisa melhor.",
				"Derreteu. Acontece com quem não é temperado.",
				"Próxima! E alguém varre esse chão.",
			],
			"capture_boss": ["Pro caldeirão essa.", "Vira metal de novo.", "Martelada certa, peça a menos.", "Rebarba. Corta fora."],
			"piece_lost": [
				"Ai! Essa tava quase pronta!",
				"Arranhou o acabamento!",
				"Tudo bem. Tenho molde pra mais umas mil.",
				"Liga fraca. Eu sabia. Culpa do aprendiz.",
			],
			"multi_capture": ["Ei! Quem deixou você mexer na minha bancada?!", "Isso foi trabalho de marreta. Mal feito, mas de marreta.", "Três horas de forja pro lixo! Três!"],
			"boss_combo": ["Uma martelada, duas peças. Isso é ofício.", "Viu a técnica? Anota, que eu não repito.", "Batida limpa. Nem faísca sobrou."],
			"boss_low": ["Pouca peça, muita brasa. Ainda dá.", "Tô só esquentando o forno, calma.", "Menos peça, menos retrabalho. Tá ótimo."],
			"player_low": ["Sobrou pouco metal aí. Quer que eu derreta o resto?", "Sua fornada tá rala, aprendiz.", "Com isso aí não faz nem um prego."],
			"promote_player": ["Coroa sem forja? Quem fez essa porcaria?", "Coroou sozinho? Deixa eu ver o acabamento.", "Hm. Rebarba no aro. Eu faria melhor."],
			"promote_boss": ["Essa saiu do meu martelo. Olha o brilho.", "Coroa nova, direto da bigorna.", "Têmpera perfeita. De nada."],
			"card_player": ["Papel perto do fogo? Corajoso.", "Truque bonito. Pena que queima.", "Isso aí não aguenta a temperatura daqui.", "Em vez de carta, aprende a segurar um martelo."],
			"sudden_death": ["Forno no máximo! Agora vai ou racha!", "Sem tempo pra polimento. Bate e pronto.", "O metal esfria rápido. Mexe essas peças!"],
			"idle": ["Vai ficar olhando pro metal até ele esfriar?", "Anda, anda. Forja não espera indeciso.", "Meu aprendiz pensa assim. Por isso ele é aprendiz.", "Bate o martelo ou larga ele. Decide."],
			# Leis da Ferreira
			"start_anvil": ["Tá vendo as bigornas? Quem aguentar em cima delas sai coroado.", "Minhas bigornas tão quentes. Sobe lá, se tiver coragem."],
			"start_foundry": ["Pode quebrar à vontade. Eu derreto e faço de novo.", "Tenho molde pra mais umas mil."],
			"start_crown_price": ["Quer coroa? Eu faço. Mas o metal sai de algum lugar.", "Toda coroa tem preço. Eu cobro em peça."],
			"start_lava_flow": ["Cuidado por onde anda. A lava desce quando quer.", "O vulcão tá de bom humor hoje. Escorre bonito."],
			"start_hammer": ["Toda peça que existe passou pela minha bigorna. E eu pego de volta.", "Escolhe uma pra mim. Ou eu escolho."],
			"start_boiling_cauldron": ["Cada peça que cai esquenta meu caldeirão.", "Briga bastante. O caldeirão adora."],
			"law_crown_price": ["Obrigada pelo metal.", "Uma coroa, uma peça. Negócio justo.", "Derreteu bonito. Coroa paga."],
			"law_anvil_crown": ["Martelada certa!", "Saiu da bigorna brilhando."],
			"law_foundry_pour": ["Fornada nova!", "Derreteu ali, nasceu aqui.", "Viu? Molde pra mais umas mil."],
			"law_lava_warn": ["Ouviu o vulcão? Sai da frente.", "Lá vem escorrendo."],
			"law_hammer_warn": ["Bonita essa coroa. Deixa eu ver de perto.", "Essa coroa é minha. Vem cá."],
			"law_hammer_mark": ["Essa aí vai voltar pra bigorna.", "Pode correr. O martelo vai atrás.", "Tô de olho em você, pequena."],
			"law_hammer": ["De volta pra forja!", "Martelada!"],
			"law_cauldron_warn": ["O caldeirão tá borbulhando...", "Vai transbordar! Corre!"],
			"law_cauldron": ["Espirrou pra todo lado!", "Ops. Fervura demais."],
		},
	},
}

static func _boss(biome: String) -> Dictionary:
	return DATA.get(biome, DATA["floresta"])

static func boss_name(biome: String) -> String:
	return str(_boss(biome).get("name", "CHEFE"))

static func boss_tint(biome: String) -> Color:
	return _boss(biome).get("tint", Color.WHITE)

static func voice(biome: String) -> String:
	return str(_boss(biome).get("voice", "voz_musgo"))

static func intro_sound(biome: String) -> String:
	return str(_boss(biome).get("intro", "boss_intro_floresta"))

static func type_cps(biome: String) -> float:
	return float(_boss(biome).get("cps", 34.0))

static func pause_mul(biome: String) -> float:
	return float(_boss(biome).get("pause", 1.0))

static func pitch_spread(biome: String) -> float:
	return float(_boss(biome).get("pitch_spread", 0.04))

# Sorteia uma fala do evento. `last` evita repetir a mesma fala em sequência.
# Devolve "" se não houver. (No começo do duelo o balão fala primeiro uma fala de
# personalidade ("start") e depois a da lei ("start_<id>") — ver BossBanterView.)
static func pick(biome: String, event: String, _law_id: String = "", last: String = "") -> String:
	var events: Dictionary = _boss(biome)["events"]
	var pool: Array = events.get(event, [])
	if pool.is_empty():
		return ""
	var options: Array = pool.filter(func(s): return s != last)
	if options.is_empty():
		options = pool
	return str(options[randi() % options.size()])
