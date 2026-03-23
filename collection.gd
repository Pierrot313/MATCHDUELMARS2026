extends Node

# ==============================================================================
# CONSTANTES - POINTS PAR PARTIE
# ==============================================================================

const POINTS_BO1 = {
	"victoire": 300,
	"defaite": 100
}

const POINTS_BO3 = {
	"victoire_2_0": 600,
	"victoire_2_1": 450,
	"defaite": 200
}

const POINTS_BO5 = {
	"victoire_3_0": 1000,
	"victoire_3_1": 850,
	"victoire_3_2": 700,
	"defaite": 300
}

# ==============================================================================
# CONSTANTES - PACKS
# ==============================================================================

const COUT_PACK_CLASSIQUE = 500
const COUT_PACK_RARE = 750
const COUT_PACK_ULTIME = 1000

const PACK_CLASSIQUE = {
	"nb_cartes": 5,
	"type": "classique"
}

const PACK_RARE = {
	"nb_cartes": 5,
	"type": "rare"
}

const PACK_ULTIME = {
	"nb_cartes": 5,
	"type": "ultime"
}

const POINTS_DOUBLON = 25

# ==============================================================================
# CONSTANTES - ALBUM
# ==============================================================================

const SEUIL_GRANDE_NATION = 8
const SEUIL_PETITE_NATION = 2
const MAX_CARTES_PAR_PAGE_MOYENNE = 16

# ==============================================================================
# DONNÉES EN MÉMOIRE
# ==============================================================================

var points : int = 0
var cartes_possedees : Dictionary = {}

# ==============================================================================
# SAUVEGARDE / CHARGEMENT
# ==============================================================================

const CHEMIN_SAUVEGARDE = "user://sauvegarde.json"

func _ready():
	charger_donnees()
	charger()
	print("Cartes possédées au démarrage : ", cartes_possedees)

func sauvegarder():
	var data = {
		"points": points,
		"cartes_possedees": cartes_possedees
	}
	var fichier = FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.WRITE)
	if fichier == null:
		print("ERREUR : impossible d'ouvrir le fichier de sauvegarde")
		return
	fichier.store_string(JSON.stringify(data))
	fichier.close()
	print("Sauvegarde effectuée : ", points, " points | ", cartes_possedees.size(), " cartes")

func charger():
	if not FileAccess.file_exists(CHEMIN_SAUVEGARDE):
		print("Pas de sauvegarde existante, on repart de zéro")
		return
	var fichier = FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.READ)
	if fichier == null:
		print("ERREUR : impossible de lire le fichier de sauvegarde")
		return
	var contenu = fichier.get_as_text()
	fichier.close()
	var data = JSON.parse_string(contenu)
	if data == null:
		print("ERREUR : fichier de sauvegarde corrompu")
		return
	points = data.get("points", 0)
	cartes_possedees = data.get("cartes_possedees", {})
	print("Chargement effectué : ", points, " points | ", cartes_possedees.size(), " cartes")

# ==============================================================================
# GESTION DES POINTS
# ==============================================================================

func ajouter_points(montant: int):
	points += montant
	sauvegarder()
	print("Points ajoutés : +", montant, " | Total : ", points)

func calculer_points_partie(mode: int, score_j: int, score_adv: int) -> int:
	# mode : 1 = Bo1, 2 = Bo3, 3 = Bo5
	var pts = 0
	if mode == 1:
		if score_j > score_adv:
			pts = POINTS_BO1["victoire"]
		else:
			pts = POINTS_BO1["defaite"]
	elif mode == 2:
		if score_j > score_adv:
			if score_adv == 0:
				pts = POINTS_BO3["victoire_2_0"]
			else:
				pts = POINTS_BO3["victoire_2_1"]
		else:
			pts = POINTS_BO3["defaite"]
	elif mode == 3:
		if score_j > score_adv:
			if score_adv == 0:
				pts = POINTS_BO5["victoire_3_0"]
			elif score_adv == 1:
				pts = POINTS_BO5["victoire_3_1"]
			else:
				pts = POINTS_BO5["victoire_3_2"]
		else:
			pts = POINTS_BO5["defaite"]
	return pts

# ==============================================================================
# GESTION DES CARTES
# ==============================================================================

func ajouter_carte(nom: String) -> bool:
	# Retourne true si c'est un doublon
	if cartes_possedees.has(nom):
		cartes_possedees[nom] += 1
		ajouter_points(POINTS_DOUBLON)
		sauvegarder()
		print("Doublon : ", nom, " | +", POINTS_DOUBLON, " points")
		return true
	else:
		cartes_possedees[nom] = 1
		sauvegarder()
		print("Nouvelle carte : ", nom)
		return false

func possede_carte(nom: String) -> bool:
	return cartes_possedees.has(nom) and cartes_possedees[nom] > 0

func nb_exemplaires(nom: String) -> int:
	return cartes_possedees.get(nom, 0)


# ==============================================================================
# DECK DE BASE
# ==============================================================================

var deck_base = []

func charger_donnees():
	var fichier = FileAccess.open("res://joueurs.csv", FileAccess.READ)
	if fichier == null: return
	fichier.get_csv_line(";")
	while fichier.get_position() < fichier.get_length():
		var ligne = fichier.get_csv_line(";")
		if ligne.size() < 6 or ligne[0] == "": continue
		var info = { "nom": ligne[0], "nationalite": ligne[1], "note": int(ligne[2]), "poste": ligne[3], "legende": ligne[4], "numero": ligne[5] }
		deck_base.append(info)

# ==============================================================================
# ALBUM
# ==============================================================================

func calculer_pages_album() -> Array:
	var pages = []
	
	# Groupe les joueurs par nationalité
	var par_nation = {}
	for info in deck_base:
		var nat = info["nationalite"]
		if not par_nation.has(nat):
			par_nation[nat] = []
		par_nation[nat].append(info)
	
	# Trie chaque nationalité par note décroissante
	for nat in par_nation:
		par_nation[nat].sort_custom(func(a, b): return a["note"] > b["note"])
	
	# Sépare en 3 groupes
	var grandes = {}
	var moyennes = {}
	var petites = {}
	
	for nat in par_nation:
		var nb = par_nation[nat].size()
		if nb >= SEUIL_GRANDE_NATION:
			grandes[nat] = par_nation[nat]
		elif nb <= SEUIL_PETITE_NATION:
			petites[nat] = par_nation[nat]
		else:
			moyennes[nat] = par_nation[nat]
	
	# --- PAGES GRANDES NATIONS ---
	# Trie par nombre de joueurs décroissant
	var grandes_triees = grandes.keys()
	grandes_triees.sort_custom(func(a, b): return grandes[a].size() > grandes[b].size())
	for nat in grandes_triees:
		pages.append({
			"layout": "grande",
			"nations": [{"nationalite": nat, "joueurs": grandes[nat]}]
		})
	
	# --- PAGES NATIONS MOYENNES ---
	# Regroupe jusqu'à MAX_CARTES_PAR_PAGE_MOYENNE cartes par page
	var moyennes_triees = moyennes.keys()
	moyennes_triees.sort_custom(func(a, b): return moyennes[a].size() > moyennes[b].size())
	
	var page_courante_moyenne = {"layout": "moyenne", "nations": []}
	var cartes_sur_page = 0
	
	for nat in moyennes_triees:
		var nb = moyennes[nat].size()
		# Arrondit au multiple de 4 supérieur pour les emplacements
		var emplacements = ceil(float(nb) / 4.0) * 4
		
		if cartes_sur_page + emplacements > MAX_CARTES_PAR_PAGE_MOYENNE and page_courante_moyenne["nations"].size() > 0:
			pages.append(page_courante_moyenne)
			page_courante_moyenne = {"layout": "moyenne", "nations": []}
			cartes_sur_page = 0
		
		page_courante_moyenne["nations"].append({
			"nationalite": nat,
			"joueurs": moyennes[nat]
		})
		cartes_sur_page += emplacements
	
	if page_courante_moyenne["nations"].size() > 0:
		pages.append(page_courante_moyenne)
	
	# --- PAGE PETITES NATIONS ---
	if petites.size() > 0:
		var nations_petites = []
		for nat in petites:
			nations_petites.append({
				"nationalite": nat,
				"joueurs": petites[nat]
			})
		pages.append({
			"layout": "petite",
			"nations": nations_petites
		})
	
	return pages
