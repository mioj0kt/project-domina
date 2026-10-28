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
				"Mais um broto querendo cruzar a minha mata...",
				"Eu já era velho quando seus avós eram sementes.",
				"Sente, forasteiro. As raízes têm paciência.",
			],
			"start_frog_devourer": ["Meu amigo sapo anda faminto hoje.", "Cuidado com as moscas... e com a língua."],
			"start_owl_night": ["A coruja decide quando é noite. Eu só aviso.", "Quando a noite cair, feche os olhos. Ou não."],
			"start_closing_forest": ["A mata fecha os caminhos... devagar, mas fecha.", "Cada árvore é uma porta que se tranca."],
			"start_vines": ["Os cipós sabem o caminho. Você, não.", "Cuidado onde pisa, mudinha."],
			"start_fireflies": ["Siga as luzes... se tiver coragem.", "Vaga-lumes mentem bonito."],
			"start_hungry_roots": ["As raízes têm fome. Sempre tiveram.", "Não é o chão que tremeu. São elas."],
			"win": [
				"Hm... as raízes cederam. Por hoje.",
				"Você corta fundo, broto. Pode passar.",
				"A mata vai se lembrar de você.",
			],
			"lose": [
				"Mais um adubo para o meu jardim.",
				"Volte quando for mais que uma muda.",
				"As árvores nem precisaram se mexer.",
			],
			"capture_boss": ["Caiu como folha no outono.", "Mais uma para as raízes.", "Foi só um sopro..."],
			"piece_lost": [
				"Ai! Isso doeu nas minhas raízes!",
				"Cuidado com a casca, forasteiro!",
				"Uma folha a menos. A árvore continua.",
			],
			"promote_player": ["Uma coroa de galhos? Que pretensão.", "Hmpf... coroada. Pequena realeza."],
			"promote_boss": ["Até árvore velha floresce.", "Coroa de musgo: a melhor de todas."],
			"card_player": ["Truques de forasteiro...", "Cartas? A floresta não precisa disso.", "Hm, essa eu não conhecia."],
			"law_night": ["Shhh... é a hora da coruja."],
			"law_dawn": ["O sol volta. A coruja dorme."],
			"law_vines": ["Os cipós mudaram de ideia.", "Eles se movem quando ninguém olha."],
			"law_trees": ["Mais uma árvore para fechar o caminho.", "A mata cresce... e você encolhe."],
			"law_devour": ["Hora do almoço do meu amigo!", "Nhac! Ouviu isso?"],
		},
	},
	"deserto": {
		"name": "O FARAÓ VAIDOSO",
		"tint": Color(1.0, 0.8, 0.35),
		"events": {
			"start": [
				"Ajoelhe-se diante do FARAÓ! Ou ao menos jogue direito.",
				"Quatro mil anos esperando um rival digno... e vem você.",
				"Admire: eu.",
			],
			"start_scorching_sun": ["O Sol é meu espelho, e ele ADORA me ver vencer.", "Passou protetor, mortal?"],
			"start_sandstorm": ["A tempestade? Apenas meu cabelo ao vento.", "Fechem os olhos. Ou não: a vista é boa."],
			"start_quicksand": ["Cuidado onde pisa. A areia me obedece.", "Já ouviu falar de areia movediça? Ela ouviu de você."],
			"start_hourglass": ["O tempo é meu escravo, mortal.", "Tic-tac... o seu tempo acaba antes do meu."],
			"start_sarcophagi": ["Meus ancestrais acordam... de MAU humor.", "Respeite a família. Ela morde."],
			"start_cacti": ["Cactos! Delicados... e muito, muito espinhentos.", "Meu jardineiro é um gênio. Não toque nele."],
			"win": [
				"IMPOSSÍVEL! Que o escultor refaça o meu busto!",
				"Hmpf. Anote nos hieróglifos que eu deixei você ganhar.",
				"Meu reino de areia... desmorona.",
			],
			"lose": [
				"Como esperado. Sou perfeito.",
				"Mais um para a minha coleção de múmias.",
				"Pode aplaudir. Aplauda.",
			],
			"capture_boss": ["Magnífico! Eu sou magnífico.", "Em nome do Sol: feito.", "Tão fácil quanto ser lindo."],
			"piece_lost": [
				"Como OUSA tocar nas MINHAS peças?!",
				"Esse arranhão será cobrado em ouro.",
				"Insolente! Sabe quem eu sou?!",
			],
			"promote_player": ["Uma coroa? Pff... a minha é maior.", "Coroada! Que gracinha. Barata."],
			"promote_boss": ["Realeza reconhece realeza: EU.", "A coroa nasceu para mim."],
			"card_player": ["Truquezinhos baratos!", "Cartas? Meu escriba usa para anotar a conta.", "Hm... isso foi quase inteligente."],
			"law_sun": ["Sinta o abraço do deus Sol!", "Quentinho, não é?"],
			"law_storm": ["Areia nos olhos! Meu perfume favorito.", "Ventinho agradável, hein?"],
			"law_quicksand": ["A areia se move. Ela gosta de mim.", "Olha o chão, olha o chão..."],
			"law_hourglass": ["Tic-tac... o tempo acaba, mortal.", "A areia escorre. A sua sorte também."],
			"law_cactus": ["Um cacto! Meu jardineiro é um gênio.", "Espinhos: a moda do deserto."],
			"law_sarcophagus": ["Mais um parente acordando...", "Visitas! Que bom."],
			"law_mummy": ["Levante-se, primo! Temos convidado!", "A família cresce. E bate."],
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
