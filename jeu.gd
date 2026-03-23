extends Control

const SCENE_CARTE = preload("res://Carte2.tscn")

const SCENE_STATS = preload("res://Stats.tscn")

const SCENE_BOUTIQUE = preload("res://Boutique.tscn")

const SCENE_ALBUM = preload("res://Album.tscn")

# --- INTERFACE ---
@onready var main_joueur = %MainDuJoueur
@onready var main_adversaire = %MainAdversaire
@onready var tapis = %Tapis
@onready var ligne_joueur = %LigneJoueur
@onready var ligne_adversaire = %LigneAdversaire

@onready var label_message = %MessageResultat
@onready var btn_passer = %BoutonPasser
@onready var label_compteur_joueur = %CompteurJoueur
@onready var label_compteur_adversaire = %CompteurAdversaire
@onready var label_chrono = %Chrono
@onready var menu_demarrage = %MenuDemarrage

# UI Bonus
@onready var indicateur_bonus_adv = %IndicateurBonusAdv
@onready var panel_joker = %PanelJoker 
@onready var btn_valider_echange = %BtnValiderEchange
@onready var btn_retour_menu = %BtnRetourMenu

# Règles
@onready var panel_regles = %PanelRegles
@onready var voile_regles = %VoileRegles
@onready var btn_ouvrir_regles = %BtnOuvrirRegles
@onready var btn_fermer_regles = %BtnFermerRegles
@onready var btn_regles_in_game = %BtnReglesInGame

#Overlay abandon in game et les boutons associés
@onready var overlay_abandon = $OverlayAbandon # Ton ColorRect noir transparent
@onready var btn_abandonner_partie = $BtnAbandonner # Le bouton visible pendant le jeu
@onready var btn_oui = %BtnOui
@onready var btn_non = %BtnNon

#Carte Bonus du Joueur
@onready var carte_bonus_visuelle = %CarteBonusJoueur # Le nouveau TextureButton

@onready var btn_quitter = %BtnQuitter

@onready var btn_stats = %BtnStats

@onready var btn_boutique = %BtnBoutique

@onready var btn_album = %BtnAlbum

# Dictionnaire des textures de bonus (adaptez les chemins vers vos fichiers)
const TEXTURES_BONUS = {
	"ESPIONNAGE": preload("res://bonus/espionnage.png"),
	"VOL": preload("res://bonus/vol.png"),
	"BOOST": preload("res://bonus/boost.png"),
	"JOKER": preload("res://bonus/joker.png"),
	"REMPLACEMENT": preload("res://bonus/remplacement.png"),
	"DOS": preload("res://bonus/dosbonus.png") # Votre futur dos de carte bonus
}

# --- DONNÉES ---
var deck_base = [] 
var deck_manche = []

# --- STATISTIQUES DE PARTIE ---
var stats_partie = {"manches": []}  # Chaque manche = { "pile_joueur": [], "pile_adversaire": [], "tours_gagnes_joueur": 0, "tours_gagnes_adversaire": 0 }
var stats_manche_courante = {}

# --- ÉTAT DU MATCH ---
var score_manches_j = 0
var score_manches_adv = 0
var manches_pour_gagner = 1 
var minute_jeu = 0 
var pile_gagnees_joueur = [] 
var pile_gagnees_adversaire = []

# --- ÉTAT DU TOUR ---
var tour_en_cours = false
var joueur_a_l_initiative = true 
var en_attente_renfort = false
var renfort_joueur_carte = null
var renfort_adversaire_carte = null
var carte_duel_joueur = null
var carte_duel_adversaire = null

var can_player_play : bool = false

# --- BONUS ---
const TYPES_BONUS = ["ESPIONNAGE", "VOL", "BOOST", "JOKER", "REMPLACEMENT"]
var bonus_joueur = ""
var bonus_adversaire = ""
var bonus_joueur_dispo = false
var bonus_adversaire_dispo = false

var boost_actif_joueur = 0
var boost_actif_adversaire = 0
var bonus_joue_ce_tour_joueur = ""      
var bonus_joue_ce_tour_adversaire = "" 

# Modes Spéciaux
var mode_vol_actif = false
var vol_etape = 0 
var carte_a_echanger_joueur = null

var mode_remplacement_actif = false
var cartes_a_remplacer = []

# --- MÉMOIRE POUR LE JOKER ---
var memoire_ia_vol = { "carte_ia": null, "carte_joueur": null }
var memoire_ia_remplacement = []

# --- MÉMOIRE POUR LE JOKER ---
var memoire_joueur_vol = { "carte_ia": null, "carte_joueur": null }
var memoire_joueur_remplacement = [] 

func _ready():
	randomize()
	menu_demarrage.visible = true
	panel_regles.visible = false
	panel_joker.visible = false
	carte_bonus_visuelle.visible = false
	indicateur_bonus_adv.visible = false
	btn_passer.visible = false
	btn_stats.visible = false
	btn_valider_echange.visible = false
	btn_regles_in_game.visible = false
	btn_abandonner_partie.visible = false
	if OS.has_feature("web"):
		btn_quitter.visible = false

# ==============================================================================
# UTILITAIRES
# ==============================================================================

func set_cartes_joueur_cliquables(peut_cliquer):
	for c in main_joueur.get_children():
		c.set_cliquable(peut_cliquer)

# ==============================================================================
# GESTION MATCH
# ==============================================================================

func _on_btn_bo_1_pressed(): lancer_partie(1)
func _on_btn_bo_3_pressed(): lancer_partie(2)
func _on_btn_bo_5_pressed(): lancer_partie(3)

func lancer_partie(obj):
	stats_partie = { "manches": [] }
	manches_pour_gagner = obj
	score_manches_j = 0
	score_manches_adv = 0
	menu_demarrage.visible = false
	btn_abandonner_partie.visible = true
	label_chrono.visible = true
	commencer_nouvelle_manche()

func commencer_nouvelle_manche():
	minute_jeu = 0
	pile_gagnees_joueur = []
	pile_gagnees_adversaire = []
	stats_manche_courante = {
	"pile_joueur": [],
	"pile_adversaire": [],
	"tours_gagnes_joueur": 0,
	"tours_gagnes_adversaire": 0}
	deck_manche = Collection.deck_base.duplicate()
	deck_manche.shuffle()
	for c in main_joueur.get_children(): c.queue_free()
	for c in main_adversaire.get_children(): c.queue_free()
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()
	await get_tree().create_timer(0.01, false).timeout
	
	bonus_joueur = TYPES_BONUS.pick_random()
	#bonus_joueur = "JOKER"
	var bonus_sans_espionnage = TYPES_BONUS.filter(func(b): return b != "ESPIONNAGE")
	bonus_adversaire = bonus_sans_espionnage.pick_random()
	#bonus_adversaire = "BOOST"
	
	bonus_joueur_dispo = true
	carte_bonus_visuelle.disabled = true
	bonus_adversaire_dispo = true
	# MISE À JOUR VISUELLE
	carte_bonus_visuelle.texture_normal = TEXTURES_BONUS[bonus_joueur]
	carte_bonus_visuelle.visible = true
	label_chrono.visible = true
	# L'adversaire montre son dos de carte bonus
	indicateur_bonus_adv.texture = TEXTURES_BONUS["DOS"]
	indicateur_bonus_adv.visible = true
	btn_regles_in_game.visible = true
	joueur_a_l_initiative = (randi() % 2 == 0)
	#joueur_a_l_initiative = false
	mettre_a_jour_interface_globale()
	piocher_jusqua_cinq()
	set_cartes_joueur_cliquables(false)
	label_message.text = "NOUVELLE MANCHE !"
	await get_tree().create_timer(2.0, false).timeout
	commencer_nouveau_tour()

func mettre_a_jour_interface_globale():
	label_compteur_joueur.text = "Manches: " + str(score_manches_j) + "/" + str(manches_pour_gagner) + "\nCartes: " + str(pile_gagnees_joueur.size())
	label_compteur_adversaire.text = "Manches: " + str(score_manches_adv) + "/" + str(manches_pour_gagner) + "\nCartes: " + str(pile_gagnees_adversaire.size())
	label_chrono.text = "%02d" % minute_jeu + " : 00"

func verifier_fin_manche():
	if minute_jeu > 90 or (deck_manche.size() == 0 and main_joueur.get_child_count() == 0):
		carte_bonus_visuelle.visible = false
		calculer_vainqueur_manche()
		return true
	return false

func calculer_vainqueur_manche():
	print_rich("[b][color=yellow]!!! DÉBUT CALCUL DES SCORES !!![/color][/b]")
	tour_en_cours = true
	set_cartes_joueur_cliquables(false)
	# Initialisation du texte riche (on vide et on remet le modulate à blanc) [cite: 5, 27]
	label_message.clear()
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))
	label_message.text = "FIN DE LA MANCHE\nCALCUL DU TOP 11..."
	btn_regles_in_game.disabled = true
	#await get_tree().create_timer(2.0).timeout
	await get_tree().create_timer(2.0, false).timeout
	var total_j = somme_top_11(pile_gagnees_joueur)
	var total_adv = somme_top_11(pile_gagnees_adversaire) 
	# Détermination des couleurs BBCode
	var col_j = "white"
	var col_adv = "white"
	var message_final = ""
	if total_j > total_adv:
		score_manches_j += 1 
		col_j = "green"
		col_adv = "red"
		message_final = "TU GAGNES LA MANCHE !"
	elif total_adv > total_j:
		score_manches_adv += 1 
		col_adv = "green"
		col_j = "red"
		message_final = "L'ADVERSAIRE GAGNE LA MANCHE..."
	else:
		# En cas d'égalité (avantage joueur selon ta règle) [cite: 8]
		score_manches_j += 1
		col_j = "green"
		col_adv = "white"
		message_final = "ÉGALITÉ (AVANTAGE JOUEUR)"
	# Construction de l'affichage vertical en BBCode 
	label_message.clear()
	var texte_riche = "[center]"
	texte_riche += "[color=" + col_adv + "]" + str(total_adv) + "[/color]\n" # Score IA en haut
	texte_riche += "VS\n"
	texte_riche += "[color=" + col_j + "]" + str(total_j) + "[/color]\n" # Score Joueur en bas
	texte_riche += message_final
	texte_riche += "[/center]"
	label_message.append_text(texte_riche) 
	stats_manche_courante["pile_joueur"] = pile_gagnees_joueur.duplicate()
	stats_manche_courante["pile_adversaire"] = pile_gagnees_adversaire.duplicate()
	stats_partie["manches"].append(stats_manche_courante.duplicate(true))
	mettre_a_jour_interface_globale()
	if score_manches_j >= manches_pour_gagner or score_manches_adv >= manches_pour_gagner:
		btn_abandonner_partie.visible = false
	await get_tree().create_timer(3.0, false).timeout
	btn_regles_in_game.disabled = false
	verifier_fin_partie_globale() 

func somme_top_11(pile):
	pile.sort_custom(func(a, b): return a["note"] > b["note"])
	var total = 0
	var nombre_a_compter = min(11, pile.size())
	for i in range(nombre_a_compter): total += pile[i]["note"]
	return total

func verifier_fin_partie_globale():
	if score_manches_j >= manches_pour_gagner:
		var pts = Collection.calculer_points_partie(manches_pour_gagner, score_manches_j, score_manches_adv)
		Collection.ajouter_points(pts)
		label_message.text = "🏆 VICTOIRE ! 🏆"
		label_message.add_theme_color_override("default_color", Color("GOLD"))
		btn_retour_menu.visible = true
		btn_stats.visible = true
		btn_abandonner_partie.visible = false
		btn_regles_in_game.visible = false
	elif score_manches_adv >= manches_pour_gagner:
		var pts = Collection.calculer_points_partie(manches_pour_gagner, score_manches_j, score_manches_adv)
		Collection.ajouter_points(pts)
		label_message.text = "💀 DÉFAITE 💀"
		label_message.add_theme_color_override("default_color", Color("GRAY"))
		btn_retour_menu.visible = true
		btn_stats.visible = true
		btn_abandonner_partie.visible = false
		btn_regles_in_game.visible = false
	else:
		commencer_nouvelle_manche()

# ==============================================================================
# LOGIQUE BONUS
# ==============================================================================

func ouvrir_menu_joker():
	panel_joker.visible = true
	var btn_voler_bonus = %BtnJokerVolerBonus 
	var raison_blocage = ""
	var contre_possible = false
	
	if bonus_joue_ce_tour_adversaire == "":
		raison_blocage = "AUCUN BONUS\nACTIF CE TOUR"
	elif bonus_joue_ce_tour_adversaire == "ESPIONNAGE":
		raison_blocage = "ESPIONNAGE\nNON VOLABLE"
	else:
		contre_possible = true
	
	if contre_possible:
		btn_voler_bonus.disabled = false
		#btn_voler_bonus.text = "CONTRER ET VOLER\n" + bonus_joue_ce_tour_adversaire
		#btn_voler_bonus.modulate = Color.GREEN
	else:
		btn_voler_bonus.visible = false
		#btn_voler_bonus.disabled = true
		#btn_voler_bonus.text = "VOL IMPOSSIBLE\n(" + raison_blocage + ")"
		#btn_voler_bonus.modulate = Color.WHITE

func _on_btn_joker_espion_pressed(): appliquer_bonus("JOUEUR", "ESPIONNAGE")
func _on_btn_joker_vol_pressed(): appliquer_bonus("JOUEUR", "VOL")
func _on_btn_joker_boost_pressed(): appliquer_bonus("JOUEUR", "BOOST")
func _on_btn_joker_voler_bonus_pressed(): appliquer_bonus("JOUEUR", "VOL_BONUS_ADVERSE")
func _on_btn_joker_remplacement_pressed(): appliquer_bonus("JOUEUR", "REMPLACEMENT")

func annuler_effet_vol_ia():
	print("--- DÉBUT ANNULATION VOL IA---")
	var c_ia = memoire_ia_vol.get("carte_ia")
	var c_joueur = memoire_ia_vol.get("carte_joueur")
	if carte_duel_adversaire != null and carte_duel_adversaire == c_joueur:
		print("Annulation impossible : La carte est déjà jouée sur le tapis.")
		return false
	if is_instance_valid(c_joueur):
		print("Retour carte Joueur : ", c_joueur.infos.nom)
		c_joueur.reparent(main_joueur)
		c_joueur.rendre_visible(true)
	else:
		print("Erreur : La carte joueur n'existe plus.")
	if is_instance_valid(c_ia):
		print("Retour carte IA : ", c_ia.infos.nom)
		c_ia.reparent(main_adversaire)
		c_ia.rendre_visible(true) 
	else:
		print("Erreur : La carte IA n'existe plus.")
	print("--- FIN ANNULATION RÉUSSIE ---")
	return true

func annuler_effet_vol_joueur():
	print("--- DÉBUT ANNULATION VOL JOUEUR ---")
	# On suppose que tu as stocké les cartes dans un dictionnaire lors du vol
	var c_ia = memoire_joueur_vol.get("carte_ia") # La carte que l'IA a perdue
	var c_joueur = memoire_joueur_vol.get("carte_joueur") # La carte que le joueur a donnée
	# Sécurité : Si le joueur a déjà posé la carte volée sur le tapis
	if carte_duel_joueur != null and carte_duel_joueur == c_ia:
		print("Annulation impossible la carte volée est déjà jouée.")
		return false
	# Rendre la carte à l'IA
	if is_instance_valid(c_ia):
		print("Retour carte à l'IA : ", c_ia.infos.nom)
		c_ia.reparent(main_adversaire)
		c_ia.rendre_visible(false) # On recache la carte chez l'IA
	# Rendre sa propre carte au joueur
	if is_instance_valid(c_joueur):
		print("Retour carte au Joueur : ", c_joueur.infos.nom)
		c_joueur.reparent(main_joueur)
		c_joueur.rendre_visible(true)
	print("--- FIN ANNULATION RÉUSSIE ---")
	return true

func annuler_effet_remplacement_ia():
	var cartes_restaurees = 0
	for paire in memoire_ia_remplacement:
		var info_vieux = paire["ancien"]
		var ref_neuf = paire["nouveau"]
		if is_instance_valid(ref_neuf) and ref_neuf != carte_duel_adversaire:
			ref_neuf.queue_free()
			creer_carte(info_vieux, main_adversaire)
			cartes_restaurees += 1
	print("Annulation Remplacement : ", cartes_restaurees, " cartes restaurées.")
	return true
	
func annuler_effet_remplacement_joueur():
	var cartes_restaurees = 0
	# On boucle sur la mémoire des cartes remplacées par le joueur
	for paire in memoire_joueur_remplacement:
		var info_vieux = paire["ancien"] # Les infos (Dict) de l'ancienne carte
		var ref_neuf = paire["nouveau"]  # La référence du bouton (Node) actuel
		# On ne remplace pas si la carte est déjà en duel sur le tapis
		if is_instance_valid(ref_neuf) and ref_neuf != carte_duel_joueur:
			ref_neuf.queue_free() # On supprime la carte piochée
			creer_carte(info_vieux, main_joueur) # On recrée l'ancienne
			cartes_restaurees += 1
	print("Annulation Remplacement : ", cartes_restaurees, " cartes restaurées.")
	return true

func appliquer_bonus(qui, type):
	if qui == "JOUEUR":
		panel_joker.visible = false
		bonus_joueur_dispo = false
		carte_bonus_visuelle.visible = false
		
		if type == "VOL_BONUS_ADVERSE":
			var bonus_cible = bonus_joue_ce_tour_adversaire
			var succes_annulation = false
			if bonus_cible == "BOOST":
				boost_actif_adversaire = 0
				label_message.text = "BOOST ADVERSE ANNULÉ ET VOLÉ !"
				succes_annulation = true
			elif bonus_cible == "VOL":
				if annuler_effet_vol_ia():
					label_message.text = "ÉCHANGE ANNULÉ !\nA TOI DE VOLER !"
				else:
					label_message.text = "CARTE DÉJÀ JOUÉE.\nMAIS TU PEUX VOLER !"
				succes_annulation = true
			elif bonus_cible == "REMPLACEMENT":
				annuler_effet_remplacement_ia()
				label_message.text = "REMPLACEMENT ADVERSE ANNULÉ !"
				succes_annulation = true
			if succes_annulation:
				type = bonus_cible
			else:
				label_message.text = "CONTRE ÉCHOUÉ..."
				return 

		label_message.text = "TU ACTIVES : " + type
		bonus_joue_ce_tour_joueur = type
		
		match type:
			"BOOST": boost_actif_joueur = 3
			"ESPIONNAGE": effet_espionnage_joueur()
			"VOL": demarrer_mode_vol()
			"REMPLACEMENT": demarrer_mode_remplacement()
		return

	else:
		# --- LOGIQUE DE L'ADVERSAIRE (ia)---
		bonus_adversaire_dispo = false
		indicateur_bonus_adv.visible = false
		
		# Cas particulier : L'IA joue son JOKER (Contre-attaque ou Aléatoire)
		if type == "VOL_BONUS_ADVERSE":
			var bonus_cible = bonus_joue_ce_tour_joueur # On regarde ce que le JOUEUR a joué
			# 1. TENTATIVE DE CONTRE (Si le joueur a joué un bonus ce tour)
			if bonus_cible != "" and bonus_cible != null:
				label_message.text = "L'ADVERSAIRE CONTRE TON " + bonus_cible + " !"
				if bonus_cible == "BOOST":
					boost_actif_joueur = 0
					type = "BOOST" # L'IA vole le boost
				elif bonus_cible == "VOL":
					# L'IA annule ton vol (elle te rend ta carte et reprend la sienne)
					annuler_effet_vol_joueur() 
					type = "VOL" # L'IA lance son propre vol
				elif bonus_cible == "REMPLACEMENT":
					annuler_effet_remplacement_joueur()
					type = "REMPLACEMENT" # L'IA lance son remplacement
				await get_tree().create_timer(2, false).timeout
			# 2. UTILISATION ALÉATOIRE (Si le joueur n'a rien joué ou bonus non contrable)
			else:
				var choix_possibles = ["BOOST", "VOL", "REMPLACEMENT"]
				type = choix_possibles.pick_random()
				label_message.text = "L'ADVERSAIRE JOUE SON JOKER : " + type

		# Une fois le 'type' final déterminé (soit par le bonus de base, soit par le Joker)
		label_message.text = "L'ADVERSAIRE JOUE : " + type
		bonus_joue_ce_tour_adversaire = type
		
		match type:
			"BOOST": 
				boost_actif_adversaire = 3
				# On choisit stratégiquement la carte qui recevra le boost
				# Mais on ne la pose sur le tapis QUE si l'IA engage (aucune carte joueur présente).
				# Si l'IA joue en second, c'est adversaire_repond() qui gère le choix et le dépôt.
				if carte_duel_joueur == null:
					var carte_boost = choisir_carte_cible_boost_ia()
					if carte_boost != null:
						preparer_duel_ia(carte_boost)
				# Sinon : le boost est actif, adversaire_repond() utilisera choisir_carte_cible_boost_ia
			"VOL": 
				effet_vol_ia()
			"REMPLACEMENT": 
				await effet_remplacement_ia()
		
		await get_tree().create_timer(1.5, false).timeout

func choisir_carte_a_jouer_ia(avec_joker: bool = false):
	var cartes = main_adversaire.get_children()
	var cartes_gagnantes = []
	var cartes_perdantes = []
	for c in cartes:
		# --- SIMULATION DU SCORE JOUEUR ---
		var n_j = calculer_score(carte_duel_joueur, c)
		# SI L'IA UTILISE SON JOKER : On retire ton boost du calcul
		if avec_joker and boost_actif_joueur > 0:
			n_j -= boost_actif_joueur
		# --- SIMULATION DU SCORE IA ---
		var n_ia = calculer_score(c, carte_duel_joueur)
		# SI L'IA UTILISE SON JOKER : Elle s'ajoute +3 (puisqu'elle te le vole)
		if avec_joker:
			n_ia += 3
		# --- CLASSEMENT ---
		if n_ia > n_j:
			cartes_gagnantes.append({"node": c, "score": n_ia})
		else:
			cartes_perdantes.append({"node": c, "score": n_ia})
	# --- LOGIQUE DE CHOIX FINAL ---
	if cartes_gagnantes.size() > 0:
		# L'IA est maligne : elle joue la PLUS PETITE carte qui gagne
		cartes_gagnantes.sort_custom(func(a, b): return a.score < b.score)
		return cartes_gagnantes[0].node
	else:
		# Si aucune ne gagne, elle sacrifie sa MOINS BONNE carte
		cartes_perdantes.sort_custom(func(a, b): return a.score < b.score)
		return cartes_perdantes[0].node

func annuler_bonus_adverse(qui_vole):
	if qui_vole == "JOUEUR": boost_actif_adversaire = 0

func effet_espionnage_joueur():
	for c in main_adversaire.get_children(): c.rendre_visible(true)
	#await get_tree().create_timer(5.0).timeout
	await get_tree().create_timer(5.0, false).timeout
	for c in main_adversaire.get_children(): c.rendre_visible(false)

func demarrer_mode_vol():
	label_message.text = "BONUS VOL : CHOISIS TA CARTE À ÉCHANGER"
	mode_vol_actif = true
	vol_etape = 1
	set_cartes_joueur_cliquables(true)
	var adverses = main_adversaire.get_children()
	adverses.shuffle()
	if adverses.size() > 0: adverses[0].rendre_visible(true)
	if adverses.size() > 1: adverses[1].rendre_visible(true)

func obtenir_groupes_nationalites(cartes):
	var groupes = {}
	for c in cartes:
		var nat = c.infos["nationalite"]
		if not groupes.has(nat): groupes[nat] = []
		groupes[nat].append(c)
	return groupes

func effet_vol_ia():
	if main_joueur.get_child_count() == 0 or main_adversaire.get_child_count() == 0:
		return

	var cartes_ia = main_adversaire.get_children()
	var cartes_joueur = main_joueur.get_children()
	
	# --- ÉTAPE 1 : CHOIX DE LA CARTE À DONNER (IA -> JOUEUR) ---
	var carte_a_donner = null
	var groupes = obtenir_groupes_nationalites(cartes_ia)
	var paires = []
	var hors_paires = []
	
	for nat in groupes:
		if groupes[nat].size() >= 2:
			paires.append(groupes[nat])
		else:
			hors_paires.append(groupes[nat][0])

	# Cas 1 : Deux paires de nationalités
	if paires.size() == 2 and cartes_ia.size() == 5:
		# Il reste logiquement 1 carte hors paire
		var restante = hors_paires[0]
		if restante.infos["note"] <= 83:
			carte_a_donner = restante
		else:
			carte_a_donner = chercher_pire_carte(cartes_ia)

	# Cas 2 : Une seule paire de nationalité
	elif paires.size() == 1:
		var les_trois_autres = []
		for c in cartes_ia:
			if c not in paires[0]: les_trois_autres.append(c)
		
		var toutes_sup_85 = true
		for c in les_trois_autres:
			if c.infos["note"] < 85: toutes_sup_85 = false
		
		if toutes_sup_85:
			carte_a_donner = chercher_pire_carte(cartes_ia)
		else:
			carte_a_donner = chercher_pire_carte(les_trois_autres)

	# Cas 3 : Aucune paire
	else:
		var note_min = 100
		for c in cartes_ia: note_min = min(note_min, c.infos["note"])
		
		var candidats_min = []
		for c in cartes_ia:
			if c.infos["note"] == note_min: candidats_min.append(c)
		
		carte_a_donner = candidats_min.pick_random()

	# --- ÉTAPE 2 : CHOIX DE LA CARTE À VOLER (JOUEUR -> IA) ---
	var carte_a_voler = null
	var indices_test = range(cartes_joueur.size())
	indices_test.shuffle()
	
	# On en prend deux au hasard pour le test des 86+
	var test1 = cartes_joueur[indices_test[0]]
	var test2 = cartes_joueur[indices_test[1]]
	var n1 = test1.infos["note"]
	var n2 = test2.infos["note"]

	if n1 >= 86 or n2 >= 86:
		if n1 >= 86 and n2 >= 86:
			if n1 > n2: carte_a_voler = test1
			elif n2 > n1: carte_a_voler = test2
			else: carte_a_voler = [test1, test2].pick_random()
		elif n1 >= 86:
			carte_a_voler = test1
		else:
			carte_a_voler = test2
	else:
		# On pioche au hasard parmi les 3 qui n'ont pas été testées
		var reste_joueur = []
		for i in range(2, indices_test.size()):
			reste_joueur.append(cartes_joueur[indices_test[i]])
		carte_a_voler = reste_joueur.pick_random()

	# --- ÉTAPE 3 : EXÉCUTION DE L'ÉCHANGE ---
	proceder_echange(carte_a_donner, carte_a_voler)

# Fonction utilitaire pour trouver la note la plus basse dans une liste
func chercher_pire_carte(liste_cartes):
	var pire = liste_cartes[0]
	for c in liste_cartes:
		if c.infos["note"] < pire.infos["note"]:
			pire = c
	return pire

func proceder_echange(ia_donne, ia_vole):
	# On réutilise ta logique de reparenting
	ia_donne.reparent(main_joueur)
	ia_vole.reparent(main_adversaire)
	
	ia_donne.rendre_visible(true)
	ia_vole.rendre_visible(false)
	
	# Reconnexion des signaux
	if not ia_donne.carte_cliquee.is_connected(_on_carte_jouee):
		ia_donne.carte_cliquee.connect(_on_carte_jouee)
	if not ia_vole.carte_cliquee.is_connected(_on_carte_jouee):
		ia_vole.carte_cliquee.connect(_on_carte_jouee)
	
	print("IA a donné: ", ia_donne.infos["nom"], " et a volé: ", ia_vole.infos["nom"])

func demarrer_mode_remplacement():
	label_message.text = "SÉLECTIONNE JUSQU'À 4 CARTES À JETER"
	mode_remplacement_actif = true
	cartes_a_remplacer.clear()
	btn_valider_echange.visible = true
	set_cartes_joueur_cliquables(true)

func _on_btn_valider_echange_pressed():
	mode_remplacement_actif = false
	btn_valider_echange.visible = false
	# 1. ON PRÉPARE LA MÉMOIRE (On vide l'ancienne pour ce tour)
	memoire_joueur_remplacement = []
	var infos_anciennes_cartes = []
	# 2. ON SAUVEGARDE LES INFOS AVANT DE SUPPRIMER
	for c in cartes_a_remplacer:
		if is_instance_valid(c):
			# On duplique le dictionnaire des données pour ne pas perdre l'info
			infos_anciennes_cartes.append(c.infos.duplicate())
			deck_manche = deck_manche.filter(func(info): return info["nom"] != c.infos["nom"])
			c.queue_free()
	# Petit délai pour laisser Godot nettoyer les nœuds
	await get_tree().create_timer(0.2, false).timeout
	# 3. ON PIOCHE ET ON LIE DANS LA MÉMOIRE
	for info_vieux in infos_anciennes_cartes:
		if deck_manche.size() > 0:
			var nouvelle_info = deck_manche.pop_front()
			# On crée la carte et on RÉCUPÈRE la référence du nouveau nœud
			var nouveau_noeud = creer_carte(nouvelle_info, main_joueur)
			# ON ENREGISTRE LA PAIRE POUR L'IA
			memoire_joueur_remplacement.append({
				"ancien": info_vieux,
				"nouveau": nouveau_noeud})
	label_message.text = "MAIN RENOUVELÉE ! À TOI DE JOUER."
	cartes_a_remplacer.clear()
	set_cartes_joueur_cliquables(true)

func effet_remplacement_ia():
	memoire_ia_remplacement = []
	var candidates = []
	
	# 1. On repère toutes les cartes < 85
	for c in main_adversaire.get_children():
		if c.infos["note"] < 85:
			candidates.append(c)
	
	# 2. ON TRIE : de la plus petite note à la plus grande
	candidates.sort_custom(func(a, b): return a.infos["note"] < b.infos["note"])
	
	# 3. On ne garde que les 4 pires (les 4 premières après le tri)
	var a_jeter = []
	var limite = min(candidates.size(), 4)
	for i in range(limite):
		a_jeter.append(candidates[i])
	
	# --- Reste de ta logique ---
	if a_jeter.size() > 0:
		label_message.text = "L'ADVERSAIRE REMPLACE " + str(a_jeter.size()) + " CARTE(S) !"
		var infos_anciennes = []
		var refs_nouvelles = []
		for c in a_jeter:
			infos_anciennes.append(c.infos)
			c.queue_free()
			
		await get_tree().create_timer(2.0, false).timeout
		
		for i in range(a_jeter.size()):
			if deck_manche.size() > 0:
				var nouv = creer_carte(deck_manche.pop_front(), main_adversaire)
				refs_nouvelles.append(nouv)
				
		var nb_paires = min(infos_anciennes.size(), refs_nouvelles.size())
		for i in range(nb_paires):
			memoire_ia_remplacement.append({ "ancien": infos_anciennes[i], "nouveau": refs_nouvelles[i] })
	else:
		label_message.text = "L'ADVERSAIRE GARDE SA MAIN."

# ==============================================================================
# BOUCLE DE JEU
# ==============================================================================

func commencer_nouveau_tour():
	if verifier_fin_manche(): return
	renfort_joueur_carte = null; renfort_adversaire_carte = null
	carte_duel_joueur = null; carte_duel_adversaire = null
	en_attente_renfort = false; btn_passer.visible = false
	boost_actif_joueur = 0; boost_actif_adversaire = 0
	bonus_joue_ce_tour_joueur = ""; bonus_joue_ce_tour_adversaire = ""
	tour_en_cours = true
	set_cartes_joueur_cliquables(false) # Désactivé au début de chaque tour
	
	if joueur_a_l_initiative:
		label_message.text = "C'EST À TOI !"
		label_message.add_theme_color_override("default_color", Color("f3f3f3"))
		#label_message.modulate = Color.GREEN
		if bonus_joueur_dispo == true:
			carte_bonus_visuelle.visible = true
			carte_bonus_visuelle.disabled = false
		else:
			carte_bonus_visuelle.visible = false
			carte_bonus_visuelle.disabled = true
		tour_en_cours = false
		set_cartes_joueur_cliquables(true) # Le joueur peut jouer
	else:
		label_message.text = "L'ADVERSAIRE ENGAGE !"
		label_message.add_theme_color_override("default_color", Color("f3f3f3"))
		#label_message.modulate = Color.ORANGE
		carte_bonus_visuelle.disabled = true
		#carte_bonus_visuelle.visible = false
		await get_tree().create_timer(1.0, false).timeout
		adversaire_engage_le_tour()

func _on_carte_jouee(carte):
	# 1. GESTION MODE REMPLACEMENT
	if mode_remplacement_actif:
		if carte.get_parent() == main_joueur:
			if carte in cartes_a_remplacer:
				cartes_a_remplacer.erase(carte)
				carte.modulate = Color.WHITE
			else:
				if cartes_a_remplacer.size() < 4:
					cartes_a_remplacer.append(carte)
					carte.modulate = Color(1, 0, 0, 0.5)
		return
	# 2. GESTION MODE VOL
	if mode_vol_actif:
		gerer_clic_vol(carte)
		return
	# 3. SÉCURITÉ
	if carte.get_parent() != main_joueur: return
	# 4. RENFORT
	if en_attente_renfort:
		jouer_renfort_joueur(carte)
		return
	# 5. TOUR NORMAL
	if tour_en_cours: return
	carte_bonus_visuelle.disabled = true
	#carte_bonus_visuelle.visible = false
	tour_en_cours = true
	set_cartes_joueur_cliquables(false) # Désactive dès qu'une carte est jouée
	carte.reparent(ligne_joueur)
	carte_duel_joueur = carte
	if carte_duel_adversaire != null:
		label_message.text = "DUEL !"
		#await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.5, false).timeout
		verifier_bataille_speciale_et_renfort()
	else:
		label_message.text = "L'ADVERSAIRE RÉFLÉCHIT..."
		#await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.5, false).timeout
		adversaire_repond()

func gerer_clic_vol(carte):
	if vol_etape == 1:
		if carte.get_parent() == main_joueur:
			carte_a_echanger_joueur = carte
			label_message.text = "CHOISIS LA CARTE ADVERSE À VOLER"
			for c in main_adversaire.get_children():
				c.mouse_filter = Control.MOUSE_FILTER_STOP
			vol_etape = 2
	elif vol_etape == 2:
		if carte.get_parent() == main_adversaire:
			var carte_adverse = carte
			memoire_joueur_vol = {
				"carte_ia": carte_adverse,
				"carte_joueur": carte_a_echanger_joueur}
			carte_a_echanger_joueur.reparent(main_adversaire)
			carte_adverse.reparent(main_joueur)
			carte_a_echanger_joueur.rendre_visible(false)
			carte_adverse.rendre_visible(true)
			for c in main_adversaire.get_children():
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not carte_a_echanger_joueur.carte_cliquee.is_connected(_on_carte_jouee):
				carte_a_echanger_joueur.carte_cliquee.connect(_on_carte_jouee)
			if not carte_adverse.carte_cliquee.is_connected(_on_carte_jouee):
				carte_adverse.carte_cliquee.connect(_on_carte_jouee)
			mode_vol_actif = false
			label_message.text = "ÉCHANGE EFFECTUÉ ! JOUE TA CARTE."
			for c in main_adversaire.get_children(): c.rendre_visible(false)
			set_cartes_joueur_cliquables(true)

func adversaire_engage_le_tour():
	await ia_decide_bonus()
	if main_adversaire.get_child_count() == 0: return
	if carte_duel_adversaire != null:
		label_message.text = "À TOI DE RÉPONDRE !"
		label_message.add_theme_color_override("default_color", Color("f3f3f3"))
		if bonus_joueur_dispo == true:
			carte_bonus_visuelle.visible = true
			carte_bonus_visuelle.disabled = false
		tour_en_cours = false
		set_cartes_joueur_cliquables(true)
		return
	var cartes = main_adversaire.get_children()
	var strategie = randi() % 3
	var carte = null

	match strategie:
		0:
			var meilleur_score = -1
			for c in cartes:
				if c.infos["note"] > meilleur_score:
					meilleur_score = c.infos["note"]
					carte = c
		1:
			var candidates = []
			for c in cartes:
				var nat = c.infos["nationalite"]
				for autre in cartes:
					if autre != c and autre.infos["nationalite"] == nat:
						candidates.append(c)
						break
			if candidates.size() > 0:
				carte = candidates.pick_random()
			else:
				carte = cartes.pick_random()
		2:
			carte = cartes.pick_random()

	carte.reparent(ligne_adversaire)
	carte.rendre_visible(true)
	carte_duel_adversaire = carte
	label_message.text = "À TOI DE RÉPONDRE !"
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))
	if bonus_joueur_dispo == true:
		carte_bonus_visuelle.visible = true
		carte_bonus_visuelle.disabled = false
	tour_en_cours = false
	set_cartes_joueur_cliquables(true) # Le joueur peut répondre

func adversaire_repond():
	await ia_decide_bonus()
	if main_adversaire.get_child_count() == 0: return
	var cartes = main_adversaire.get_children()
	var carte = null
	var info_j = carte_duel_joueur.infos
	var note_j = info_j["note"]

	# --- CAS SPÉCIAL : L'IA a un boost actif (joué ce tour ou volé via Joker) ---
	# On utilise la fonction dédiée qui sait choisir la meilleure cible du boost
	if boost_actif_adversaire > 0:
		carte = choisir_carte_cible_boost_ia()
		if carte != null:
			carte.reparent(ligne_adversaire)
			carte.rendre_visible(true)
			carte_duel_adversaire = carte
			await get_tree().create_timer(0.5, false).timeout
			verifier_bataille_speciale_et_renfort()
			return

	# --- 2. TRI DES CARTES GAGNANTES ---
	var cartes_gagnantes = []
	for c in cartes:
		var n_ia = calculer_score(c, carte_duel_joueur)
		var n_j  = calculer_score(carte_duel_joueur, c)
		if n_ia > n_j:
			cartes_gagnantes.append(c)

	# --- 3. LOGIQUE DE DÉCISION ---
	if cartes_gagnantes.size() > 0:
		if note_j > 85:
			var gagnante_avec_renfort = null
			for c in cartes_gagnantes:
				for autre in cartes:
					if autre != c and autre.infos["nationalite"] == c.infos["nationalite"]:
						gagnante_avec_renfort = c
						break
				if gagnante_avec_renfort: break
			if gagnante_avec_renfort:
				carte = gagnante_avec_renfort
			else:
				carte = chercher_meilleure_carte(cartes_gagnantes)
		else:
			carte = chercher_pire_carte(cartes_gagnantes)
	else:
		# --- L'IA NE PEUT PAS GAGNER NORMALEMENT ---
		var cartes_bataille = []
		for c in cartes:
#			var p_ia = str(c.infos["poste"]).to_upper()
			var n_ia = calculer_score(c, carte_duel_joueur)
			var n_j  = calculer_score(carte_duel_joueur, c)
			var diff = abs(n_ia - n_j)

			# Condition A : égalité réelle après bonus
			if n_ia == n_j:
				cartes_bataille.append(c)
			# Condition B : même nationalité, écart <= 4, et l'IA ne perd pas
			elif c.infos["nationalite"] == info_j["nationalite"] and diff <= 4 and n_ia >= n_j:
				cartes_bataille.append(c)
		if cartes_bataille.size() > 0:
			carte = cartes_bataille.pick_random()
			print("IA désespérée : Tente de provoquer une BATAILLE")
		else:
			if str(info_j["legende"]).to_upper() != "OUI":
				var note_min = 100
				for c in cartes: note_min = min(note_min, c.infos["note"])
				var pires_cartes = []
				for c in cartes:
					if c.infos["note"] == note_min: pires_cartes.append(c)
				carte = pires_cartes.pick_random()
				print("IA désespérée : Économise ses forces (joue le minimum)")
			else:
				var cartes_legende_bataille = []
				for c in cartes:
					var n_ia = calculer_score(c, carte_duel_joueur)
					var n_j  = calculer_score(carte_duel_joueur, c)
					var diff = abs(n_ia - n_j)
					if str(c.infos["legende"]).to_upper() == "OUI" and diff <= 4 and n_ia >= n_j:
						cartes_legende_bataille.append(c)
				if cartes_legende_bataille.size() > 0:
					carte = cartes_legende_bataille.pick_random()
					print("IA tente sa chance avec une bataille de légende")
				else:
					carte = chercher_pire_carte(cartes)
					print("IA joue sa pire carte")

	# --- 4. EXÉCUTION ---
	if carte == null:
		print("ERREUR : aucune carte sélectionnée, fallback sur la pire carte")
		carte = chercher_pire_carte(cartes)
	carte.reparent(ligne_adversaire)
	carte.rendre_visible(true)
	carte_duel_adversaire = carte
	await get_tree().create_timer(0.5, false).timeout
	verifier_bataille_speciale_et_renfort()

func chercher_meilleure_carte(liste):
	var best = liste[0]
	for c in liste:
		if c.infos["note"] > best.infos["note"]: best = c
	return best

# Choisit stratégiquement quelle carte de l'IA doit recevoir le boost (+3)
# Si l'IA joue en PREMIÈRE (pas de carte joueur posée) : boost la carte avec la note la plus haute
# Si l'IA joue en SECONDE (carte joueur déjà posée) : cherche la plus petite carte qui bat la carte adverse avec le boost
# Pose une carte IA choisie sur la ligne de duel (utilisé quand l'IA engage en jouant son BOOST)
func preparer_duel_ia(carte: Node):
	if carte == null or not is_instance_valid(carte):
		return
	carte.reparent(ligne_adversaire)
	carte.rendre_visible(true)
	carte_duel_adversaire = carte

func choisir_carte_cible_boost_ia(_boost_vole_depuis_joueur: bool = false) -> Node:
	var cartes = main_adversaire.get_children()
	if cartes.size() == 0:
		return null
	# --- CAS 1 : L'IA JOUE EN PREMIÈRE (aucune carte adverse posée) ---
	if carte_duel_joueur == null:
		# On boost la carte avec la note la plus élevée (maximise la menace)
		var note_max = 0
		for c in cartes:
			if c.infos["note"] > note_max:
				note_max = c.infos["note"]
		var meilleures = []
		for c in cartes:
			if c.infos["note"] == note_max:
				meilleures.append(c)
		var meilleure = meilleures.pick_random()
		print("IA choisit la cible du boost (1er) : ", meilleure.infos["nom"])
		return meilleure
	# --- CAS 2 : L'IA JOUE EN SECONDE (carte joueur déjà posée sur le tapis) ---
	# On recalcule le score joueur avec les bonus de poste uniquement (sans boost puisqu'annulé)
	# On simule "carte_duel_adversaire = c" pour le calcul de poste
	# La fonction calculer_score utilise carte_duel_joueur/adversaire, donc on calcule manuellement
	var cartes_gagnantes_sures = []
	var cartes_perdantes = []
	var cartes_nationalite_bataille = []
	var cartes_egalite_bataille = []
	
	for c in cartes:
		# Score joueur : note de base + bonus de poste VS cette carte IA (sans boost car annulé)
		var p_j = str(carte_duel_joueur.infos["poste"]).to_upper()
		var p_ia = str(c.infos["poste"]).to_upper()
		
		var score_j = carte_duel_joueur.infos["note"]
		if p_j == "ATTAQUANT" and p_ia == "GARDIEN": score_j += 2
		elif p_j == "GARDIEN" and p_ia == "MILIEU": score_j += 2
		elif p_j == "MILIEU" and p_ia == "DEFENSEUR": score_j += 2
		elif p_j == "DEFENSEUR" and p_ia == "ATTAQUANT": score_j += 2
		
		# Score IA : note de base + bonus de poste + boost (+3)
		var score_ia = c.infos["note"] + 3
		if p_ia == "ATTAQUANT" and p_j == "GARDIEN": score_ia += 2
		elif p_ia == "GARDIEN" and p_j == "MILIEU": score_ia += 2
		elif p_ia == "MILIEU" and p_j == "DEFENSEUR": score_ia += 2
		elif p_ia == "DEFENSEUR" and p_j == "ATTAQUANT": score_ia += 2
		
		if score_ia > score_j:
			# Vérifier si ce duel déclencherait une bataille (même nationalité, écart <= 4)
			var meme_nat = c.infos["nationalite"] == carte_duel_joueur.infos["nationalite"]
			var ecart = abs(score_ia - score_j)
			if meme_nat and ecart <= 4:
				cartes_nationalite_bataille.append({"node": c, "score": score_ia})
			else:
				cartes_gagnantes_sures.append({"node": c, "score": score_ia})
		elif score_ia == score_j:
			cartes_egalite_bataille.append({"node": c, "score": score_ia})
		else:
			cartes_perdantes.append({"node": c, "score": score_ia})
	
	if cartes_gagnantes_sures.size() > 0:
		var carte_choisie = cartes_gagnantes_sures.pick_random()
		print("IA choisit la cible du boost (2e, gagne avec) : ", carte_choisie.node.infos["nom"])
		return carte_choisie.node
	elif cartes_egalite_bataille.size() > 0:
		cartes_egalite_bataille.sort_custom(func(a, b): return a.score < b.score)
		print("IA choisit la cible du boost (2e, égalité → bataille) : ", cartes_egalite_bataille[0].node.infos["nom"])
		return cartes_egalite_bataille[0].node
	elif cartes_nationalite_bataille.size() > 0:
		cartes_nationalite_bataille.sort_custom(func(a, b): return a.score < b.score)
		print("IA choisit la cible du boost (2e, victoire avec risque bataille) : ", cartes_nationalite_bataille[0].node.infos["nom"])
		return cartes_nationalite_bataille[0].node
	else:
		# Aucune carte ne gagne même avec le boost : on sacrifie la pire
		cartes_perdantes.sort_custom(func(a, b): return a.score < b.score)
		print("IA choisit la cible du boost (2e, sacrifice pire carte) : ", cartes_perdantes[0].node.infos["nom"])
		return cartes_perdantes[0].node

func ia_decide_bonus():
	if not bonus_adversaire_dispo: return
	if bonus_adversaire == "BOOST":
		await ia_decide_boost()
	elif bonus_adversaire == "REMPLACEMENT":
		await ia_decide_remplacement()
	elif bonus_adversaire == "VOL":
		await ia_decide_vol()
	elif bonus_adversaire == "JOKER":
		await ia_decide_joker()

func ia_decide_joker():
	# --- CAS 1 : LE JOUEUR VIENT DE JOUER SON BONUS CE TOUR ---
	if bonus_joue_ce_tour_joueur in ["VOL", "REMPLACEMENT", "VOL_BONUS_ADVERSE"]:
		await appliquer_bonus("ADVERSAIRE", "VOL_BONUS_ADVERSE")
		return
	elif bonus_joue_ce_tour_joueur == "BOOST":
		if vaut_le_coup_voler_boost():
			boost_actif_joueur = 0
			await appliquer_bonus("ADVERSAIRE", "VOL_BONUS_ADVERSE")
		return
	else:
		# Bonus non volable (ESPIONNAGE) → on essaie les bonus normaux
		await ia_decide_boost()
		if not bonus_adversaire_dispo: return
		await ia_decide_remplacement()
		if not bonus_adversaire_dispo: return
		await ia_decide_vol()
	# --- CAS 2 : JOUEUR A JOUÉ SON BONUS UN TOUR PRÉCÉDENT OU NE L'A PAS ENCORE JOUÉ ---
	if carte_duel_joueur == null:
		# L'IA joue en premier
		await ia_decide_remplacement()
		if not bonus_adversaire_dispo: return
		await ia_decide_vol()
		if not bonus_adversaire_dispo: return
		# Boost : meilleure carte dans [87;89] et seule de sa nationalité
		var cartes = main_adversaire.get_children()
		var meilleure = chercher_meilleure_carte(cartes)
		if meilleure.infos["note"] >= 87 and meilleure.infos["note"] <= 89:
			var nat = meilleure.infos["nationalite"]
			var seule = true
			for c in cartes:
				if c != meilleure and c.infos["nationalite"] == nat:
					seule = false
					break
			if seule:
				await ia_decide_boost()
	else:
		# L'IA joue en second
		await ia_decide_boost()
		if not bonus_adversaire_dispo: return
		await ia_decide_remplacement()
		if not bonus_adversaire_dispo: return
		await ia_decide_vol()

func vaut_le_coup_voler_boost() -> bool:
	if carte_duel_joueur == null: return false
	
	var cartes = main_adversaire.get_children()
	if cartes.size() == 0: return false
	
	# --- SITUATION ACTUELLE (avec boost joueur actif) ---
	var meilleur_score_actuel = -1
	for c in cartes:
		var s_ia = calculer_score(c, carte_duel_joueur)
		#var s_j = calculer_score(carte_duel_joueur, c)
		if s_ia > meilleur_score_actuel:
			meilleur_score_actuel = s_ia
	
	# L'IA gagne déjà sans rien faire → pas besoin de voler
	var meilleure = chercher_meilleure_carte(cartes)
	var score_j_actuel = calculer_score(carte_duel_joueur, meilleure)
	if meilleur_score_actuel > score_j_actuel: return false
	
	# --- SIMULATION : IA vole le boost (ia +3, joueur -3) ---
	var meilleur_score_apres_vol = -1
	var meilleure_carte_apres_vol = null
	for c in cartes:
		# Score IA avec +3
		var s_ia = c.infos["note"] + 3
		var p1 = str(c.infos["poste"]).to_upper()
		var p2 = str(carte_duel_joueur.infos["poste"]).to_upper()
		if p1 == "ATTAQUANT" and p2 == "GARDIEN": s_ia += 2
		elif p1 == "GARDIEN" and p2 == "MILIEU": s_ia += 2
		elif p1 == "MILIEU" and p2 == "DEFENSEUR": s_ia += 2
		elif p1 == "DEFENSEUR" and p2 == "ATTAQUANT": s_ia += 2
		if s_ia > meilleur_score_apres_vol:
			meilleur_score_apres_vol = s_ia
			meilleure_carte_apres_vol = c
	
	# Score joueur sans son boost (-3)
	var score_j_apres_vol = calculer_score(carte_duel_joueur, meilleure_carte_apres_vol) - boost_actif_joueur
	var p_j = str(carte_duel_joueur.infos["poste"]).to_upper()
	var p_ia = str(meilleure_carte_apres_vol.infos["poste"]).to_upper()
	if p_j == "ATTAQUANT" and p_ia == "GARDIEN": score_j_apres_vol += 2
	elif p_j == "GARDIEN" and p_ia == "MILIEU": score_j_apres_vol += 2
	elif p_j == "MILIEU" and p_ia == "DEFENSEUR": score_j_apres_vol += 2
	elif p_j == "DEFENSEUR" and p_ia == "ATTAQUANT": score_j_apres_vol += 2
	
	# Vaut le coup si l'IA passe de perdante à gagnante
	if meilleur_score_apres_vol > score_j_apres_vol and carte_duel_joueur.infos["note"] >=86: return true
	# Égalité → 33% de chance
	if meilleur_score_apres_vol == score_j_apres_vol and carte_duel_joueur.infos["note"] >=86 : return (randi() % 100) < 33
	# L'IA perd même après le vol → false
	return false

func ia_decide_boost():
	# --- CAS 1 : L'IA ENGAGE EN PREMIER ---
	if carte_duel_joueur == null:
		var cartes_fortes = []
		for c in main_adversaire.get_children():
			if c.infos["note"] >= 87:
				cartes_fortes.append(c)
		if cartes_fortes.size() == 0: return
		
		var chance = 10 if minute_jeu <= 55 else 60
		if (randi() % 100) >= chance: return
		
		await appliquer_bonus("ADVERSAIRE", "BOOST")
	# --- CAS 2 : L'IA RÉPOND EN SECOND ---
	else:
		var carte_j_note = carte_duel_joueur.infos["note"]
		# Meilleur score IA sans boost
		var meilleur_sans_boost = -1
		var meilleure_carte_sans_boost = null
		for c in main_adversaire.get_children():
			var s = calculer_score(c, carte_duel_joueur)
			if s > meilleur_sans_boost:
				meilleur_sans_boost = s
				meilleure_carte_sans_boost = c
		# Score réel de la carte joueur (avec bonus de poste inclus)
		var score_j = calculer_score(carte_duel_joueur, meilleure_carte_sans_boost)  # ← on passe la carte IA comme adversaire pour calculer le poste
		# L'IA peut gagner sans boost → elle ne l'utilise pas
		if meilleur_sans_boost > score_j: return
		# Meilleur score IA avec boost, en recalculant score_j pour chaque carte adverse
		var meilleur_avec_boost = -1
		var meilleure_carte_avec_boost = null
		for c in main_adversaire.get_children():
			var s_ia = calculer_score(c, carte_duel_joueur) + 3
			if s_ia > meilleur_avec_boost:
				meilleur_avec_boost = s_ia
				meilleure_carte_avec_boost = c
		# Recalcule score_j face à la meilleure carte avec boost
		var score_j_vs_boost = calculer_score(carte_duel_joueur, meilleure_carte_avec_boost)
		if meilleur_avec_boost > score_j_vs_boost and carte_j_note >= 87:
			await appliquer_bonus("ADVERSAIRE", "BOOST")
		elif meilleur_avec_boost == score_j_vs_boost and carte_j_note >= 87:
			if (randi() % 100) < 80:
				await appliquer_bonus("ADVERSAIRE", "BOOST")

func ia_decide_remplacement():
	var cartes = main_adversaire.get_children()
	if cartes.size() == 0: return
	# --- CAS OBLIGATOIRE : minute_jeu >= 90 ---
	if minute_jeu >= 90:
		await appliquer_bonus("ADVERSAIRE", "REMPLACEMENT")
		return
	# --- CAS 1 : minute_jeu <= 50 ---
	if minute_jeu <= 55:
		# Au moins 4 cartes <= 82
		var cartes_faibles = []
		for c in cartes:
			if c.infos["note"] <= 82:
				cartes_faibles.append(c)
		if cartes_faibles.size() < 4: return
		# Toutes les cartes de la main ont une nationalité différente
		var nationalites = []
		var toutes_differentes = true
		for c in cartes:
			var nat = c.infos["nationalite"]
			if nat in nationalites:
				toutes_differentes = false
				break
			nationalites.append(nat)
		if not toutes_differentes: return
		await appliquer_bonus("ADVERSAIRE", "REMPLACEMENT")
	# --- CAS 2 : minute_jeu > 50 ---
	else:
		# Au moins 3 cartes <= 82
		var cartes_faibles = []
		for c in cartes:
			if c.infos["note"] <= 82:
				cartes_faibles.append(c)
		if cartes_faibles.size() < 3: return
		# Les cartes faibles ont toutes une nationalité différente des autres cartes de la main
		var nationalites_autres = []
		for c in cartes:
			if c not in cartes_faibles:
				nationalites_autres.append(c.infos["nationalite"])
		var faibles_isolees = true
		for c in cartes_faibles:
			if c.infos["nationalite"] in nationalites_autres:
				faibles_isolees = false
				break
		if not faibles_isolees: return
		await appliquer_bonus("ADVERSAIRE", "REMPLACEMENT")
		
func ia_decide_vol():
	var cartes = main_adversaire.get_children()
	if cartes.size() == 0: return
	# --- CAS OBLIGATOIRE : minute_jeu >= 90 ---
	if minute_jeu >= 90:
		await appliquer_bonus("ADVERSAIRE", "VOL")
		return
	# --- RECHERCHE D'UNE CARTE ISOLÉE <= 79 ---
	var carte_isolee = null
	for c in cartes:
		if c.infos["note"] > 81: continue
		var nat = c.infos["nationalite"]
		var est_isolee = true
		for autre in cartes:
			if autre != c and autre.infos["nationalite"] == nat:
				est_isolee = false
				break
		if est_isolee:
			carte_isolee = c
			break
	if carte_isolee == null: return
	# --- CAS 1 : L'IA JOUE EN PREMIER ---
	if carte_duel_joueur == null:
		await appliquer_bonus("ADVERSAIRE", "VOL")
		return
	# --- CAS 2 : L'IA JOUE EN SECOND ---
	var note_brute_joueur = carte_duel_joueur.infos["note"]
	if note_brute_joueur <= 85:
		if (randi() % 100) < 33:
			await appliquer_bonus("ADVERSAIRE", "VOL")

func verifier_bataille_speciale_et_renfort():
	print("[VERIF_BATAILLE] bonus_joue_j=", bonus_joue_ce_tour_joueur, 
	  " | bonus_joue_adv=", bonus_joue_ce_tour_adversaire,
	  " | bonus_j=", bonus_joueur, 
	  " | bonus_adv=", bonus_adversaire,
	  " | boost_j=", boost_actif_joueur, 
	  " | boost_adv=", boost_actif_adversaire)
	preparer_boost_joker()
	var type = check_bataille_speciale(carte_duel_joueur, carte_duel_adversaire)
	if type != "NON":
		label_message.text = "BATAILLE SPÉCIALE : " + type
		label_message.add_theme_color_override("default_color", Color("f3f3f3"))
		#await get_tree().create_timer(1.5).timeout
		await get_tree().create_timer(1.5, false).timeout
		#var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
		#var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
		lancer_bataille()
		return
	verifier_phase_renfort()

func check_bataille_speciale(c1, c2):
	if c1 == null or c2 == null: return "NON"
	# --- 1. CALCUL DES SCORES RÉELS (INCLUANT BOOST ET POSTE) ---
	var s1 = calculer_score(c1, c2)
	var s2 = calculer_score(c2, c1)
	# --- 2. VÉRIFICATION DES LÉGENDES ---
	# Utilisation de la syntaxe ["clef"] pour éviter l'erreur d'index
	var l1 = str(c1.infos["legende"]).to_lower() in ["oui", "true", "vrai"]
	var l2 = str(c2.infos["legende"]).to_lower() in ["oui", "true", "vrai"]
	if l1 and l2: 
		return "LÉGENDES"
	# --- 3. VÉRIFICATION DU DERBY ---
	if c1.infos["nationalite"] == c2.infos["nationalite"]:
		# On compare l'écart des scores calculés (s1 et s2)
		if abs(s1 - s2) <= 4: 
			return "DERBY"
	return "NON"

func verifier_phase_renfort():
	var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
	var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
	label_message.text = str(s1) + " VS " + str(s2)
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))
	#await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0, false).timeout
	
	var difficulte = false
	if joueur_a_l_initiative and s1 <= s2: difficulte = true
	if not joueur_a_l_initiative and s2 <= s1: difficulte = true
	
	if difficulte: lancer_demande_renfort()
	else: calculer_score_final_avec_renforts()

func lancer_demande_renfort():
	if joueur_a_l_initiative: verifier_renfort_possible_joueur()
	else: verifier_renfort_possible_adversaire()

func verifier_renfort_possible_joueur():
	if carte_duel_joueur == null: _on_bouton_passer_pressed(); return
	var nat = carte_duel_joueur.infos["nationalite"]
	var possible = false
	for c in main_joueur.get_children():
		if c.infos["nationalite"] == nat:
			possible = true
			#c.modulate = Color.YELLOW
			c.set_cliquable(true) # Active uniquement les cartes de renfort
	if possible:
		label_message.text = "RENFORT POSSIBLE"
		btn_passer.visible = true
		en_attente_renfort = true
	else:
		label_message.text = "PAS DE RENFORT EN MAIN"
		#await get_tree().create_timer(1.0).timeout
		await get_tree().create_timer(1.0, false).timeout
		_on_bouton_passer_pressed()

func jouer_renfort_joueur(c):
	if c.infos["nationalite"] != carte_duel_joueur.infos["nationalite"]: return
	c.reparent(ligne_joueur)
	renfort_joueur_carte = c
	fin_renfort_joueur()

func _on_bouton_passer_pressed():
	renfort_joueur_carte = null
	fin_renfort_joueur()

func fin_renfort_joueur():
	en_attente_renfort = false
	btn_passer.visible = false
	for c in main_joueur.get_children():
		c.modulate = Color.WHITE
		c.set_cliquable(false) # Désactive après le renfort
	if joueur_a_l_initiative:
		if renfort_joueur_carte: verifier_renfort_possible_adversaire()
		else: calculer_score_final_avec_renforts()
	else:
		calculer_score_final_avec_renforts()

func verifier_renfort_possible_adversaire():
	if carte_duel_adversaire == null: passer_la_main_apres_renfort_adversaire(); return
	var nat = carte_duel_adversaire.infos["nationalite"]
	var cand = null
	for c in main_adversaire.get_children():
		if c.infos["nationalite"] == nat: cand = c
	
	if cand:
		# On simule le score avec renfort
		var score_ia_avec_renfort = calculer_score(carte_duel_adversaire, carte_duel_joueur) + cand.infos["note"]
		var score_j_avec_renfort  = calculer_score(carte_duel_joueur, carte_duel_adversaire) + (renfort_joueur_carte.infos["note"] if renfort_joueur_carte else 0)
		
		var renfort_permet_gagner = score_ia_avec_renfort > score_j_avec_renfort
		var renfort_est_sacrifice = cand.infos["note"] <= 84

		if renfort_permet_gagner or renfort_est_sacrifice:
			label_message.text = "L'ADVERSAIRE RENFORCE !"
			await get_tree().create_timer(1.0, false).timeout
			cand.reparent(ligne_adversaire)
			cand.rendre_visible(true)
			renfort_adversaire_carte = cand
		else:
			# Le renfort ne fait pas gagner et la carte est trop précieuse
			label_message.text = "L'ADVERSAIRE PASSE..."
			await get_tree().create_timer(1.0, false).timeout
			renfort_adversaire_carte = null
	else:
		label_message.text = "L'ADVERSAIRE PASSE..."
		await get_tree().create_timer(1.0, false).timeout
		renfort_adversaire_carte = null
	
	passer_la_main_apres_renfort_adversaire()

func passer_la_main_apres_renfort_adversaire():
	if joueur_a_l_initiative: calculer_score_final_avec_renforts()
	else:
		if renfort_adversaire_carte:
			#var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
			#var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur) + renfort_adversaire_carte.infos["note"]
			verifier_renfort_possible_joueur()
		else: calculer_score_final_avec_renforts()

func calculer_score_final_avec_renforts():
	var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
	var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
	if renfort_joueur_carte: s1 += renfort_joueur_carte.infos["note"]
	if renfort_adversaire_carte: s2 += renfort_adversaire_carte.infos["note"]
	if s1 == s2: lancer_bataille()
	else: finir_le_tour(s1, s2)

func lancer_bataille():
	label_message.text = "!!! BATAILLE !!!"
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))
	#await get_tree().create_timer(1.5).timeout
	await get_tree().create_timer(1.5, false).timeout
	
	if deck_manche.size() < 4:
		label_message.text = "FIN DU DECK"; calculer_vainqueur_manche(); return

	# On réinitialise le modulate global à blanc pour laisser le BBCode gérer les couleurs
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))

	# Scores initiaux (Duel de départ)
	var v1_init = calculer_score(carte_duel_joueur, carte_duel_adversaire)
	var v2_init = calculer_score(carte_duel_adversaire, carte_duel_joueur)
	
	# --- CALCUL DU JAUNE (SI BONUS) ---
	var txt_v1 = str(v1_init)
	if v1_init > carte_duel_joueur.infos["note"]:
		txt_v1 = "[color=yellow]" + txt_v1 + "[/color]"
		
	var txt_v2 = str(v2_init)
	if v2_init > carte_duel_adversaire.infos["note"]:
		txt_v2 = "[color=yellow]" + txt_v2 + "[/color]"

	# Tirage des cartes de bataille
	var bataille_j = []
	var bataille_adv = []
	for i in range(2):
		var info = deck_manche.pop_front()
		creer_carte(info, ligne_joueur)
		bataille_j.append(info["note"])
	for i in range(2):
		var info = deck_manche.pop_front()
		var c = creer_carte(info, ligne_adversaire)
		c.rendre_visible(true)
		bataille_adv.append(info["note"])

	var total_j = v1_init + bataille_j[0] + bataille_j[1]
	var total_adv = v2_init + bataille_adv[0] + bataille_adv[1]

	# --- COULEURS DES SCORES FINAUX ---
	var col_j = "white"
	var col_adv = "white"
	if total_j > total_adv:
		col_j = "green"; col_adv = "red"
	elif total_adv > total_j:
		col_adv = "green"; col_j = "red"

	# --- CONSTRUCTION DU TEXTE RICHE ---
	# Ligne Adversaire (Haut)
	var detail_adv = txt_v2 + " + " + str(bataille_adv[0]) + " + " + str(bataille_adv[1]) 
	var final_adv = " = [color=" + col_adv + "]" + str(total_adv) + "[/color]"
	
	# Ligne Joueur (Bas)
	var detail_j = txt_v1 + " + " + str(bataille_j[0]) + " + " + str(bataille_j[1])
	var final_j = " = [color=" + col_j + "]" + str(total_j) + "[/color]"

	# On applique au RichTextLabel (Utilise .append_text ou .text selon ta version)
	label_message.clear()
	label_message.append_text("[center]" + detail_adv + final_adv + "\n\n" + detail_j + final_j + "[/center]")

	#await get_tree().create_timer(5.0).timeout
	await get_tree().create_timer(3.0, false).timeout
	finir_le_tour(total_j, total_adv)

func finir_le_tour(s1, s2):
	if s1 > s2:
		label_message.text = "VICTOIRE !"
		label_message.add_theme_color_override("default_color", Color("green"))
		collecter_cartes_sur_tapis(pile_gagnees_joueur)
		stats_manche_courante["tours_gagnes_joueur"] += 1
	elif s2 > s1:
		label_message.text = "DÉFAITE..."
		label_message.add_theme_color_override("default_color", Color("red"))
		collecter_cartes_sur_tapis(pile_gagnees_adversaire)
		stats_manche_courante["tours_gagnes_adversaire"] += 1
	else:
		label_message.text = "ÉGALITÉ PARFAITE\nPARTAGE DES POINTS"
		label_message.add_theme_color_override("default_color", Color("f3f3f3"))
		for c in ligne_joueur.get_children(): 
			if "infos" in c: pile_gagnees_joueur.append(c.infos)
		for c in ligne_adversaire.get_children(): 
			if "infos" in c: pile_gagnees_adversaire.append(c.infos)
		stats_manche_courante["tours_gagnes_joueur"] += 1
		stats_manche_courante["tours_gagnes_adversaire"] += 1
	
	#await get_tree().create_timer(2.0).timeout
	await get_tree().create_timer(2.0, false).timeout
	
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()
	
	minute_jeu += 5
	if minute_jeu > 90:
		label_chrono.visible = false
	joueur_a_l_initiative = not joueur_a_l_initiative
	mettre_a_jour_interface_globale()
	piocher_jusqua_cinq()
	commencer_nouveau_tour()

func collecter_cartes_sur_tapis(pile_cible):
	for c in ligne_joueur.get_children(): if "infos" in c: pile_cible.append(c.infos)
	for c in ligne_adversaire.get_children(): if "infos" in c: pile_cible.append(c.infos)

func calculer_score(c1, c2):
	if c1 == null or c2 == null: return 0
	var score = c1.infos["note"]
	if c1 == carte_duel_joueur and boost_actif_joueur > 0: score += boost_actif_joueur
	elif c1 == carte_duel_adversaire and boost_actif_adversaire > 0: score += boost_actif_adversaire
	var p1 = str(c1.infos["poste"]).to_upper(); var p2 = str(c2.infos["poste"]).to_upper()
	if p1=="ATTAQUANT" and p2=="GARDIEN": score+=2
	elif p1=="GARDIEN" and p2=="MILIEU": score+=2
	elif p1=="MILIEU" and p2=="DEFENSEUR": score+=2
	elif p1=="DEFENSEUR" and p2=="ATTAQUANT": score+=2
	return score
	
func preparer_boost_joker():
	print("[PREPARER_BOOST_JOKER] condition1=", (bonus_joue_ce_tour_joueur == "BOOST" and bonus_joue_ce_tour_adversaire == "BOOST" and bonus_adversaire == "JOKER"),
	  " | condition2=", (bonus_joue_ce_tour_adversaire == "BOOST" and bonus_joue_ce_tour_joueur == "BOOST" and bonus_joueur == "JOKER"))
	# Le joueur a joué BOOST, et l'adversaire a joué JOKER en choisissant BOOST → le boost va à l'adversaire
	if bonus_joue_ce_tour_joueur == "BOOST" and bonus_joue_ce_tour_adversaire == "BOOST" and bonus_adversaire == "JOKER":
		boost_actif_adversaire += boost_actif_joueur
		boost_actif_joueur = 0
	# Cas inverse : l'adversaire a joué BOOST, et le joueur a joué JOKER en choisissant BOOST
	elif bonus_joue_ce_tour_adversaire == "BOOST" and bonus_joue_ce_tour_joueur == "BOOST" and bonus_joueur == "JOKER":
		boost_actif_joueur += boost_actif_adversaire
		boost_actif_adversaire = 0

func piocher_jusqua_cinq():
	# --- TEST : ALLER CHERCHER ZIDANE DANS LE DECK DE BASE ---
	#if main_joueur.get_child_count() == 0:
		#var zidane_du_fichier = null
		#for info in Collection.deck_base:
			#if info["nom"] == "stephane": # <--- Vérifie l'orthographe exacte dans ton CSV
				#zidane_du_fichier = info
				#break
		#
		#if zidane_du_fichier != null:
			#creer_carte(zidane_du_fichier, main_joueur)
		#else:
			#print("ERREUR : Zidane non trouvé dans le CSV. Vérifie l'orthographe.")
	while main_joueur.get_child_count() < 5 and deck_manche.size() > 0:
		creer_carte(deck_manche.pop_front(), main_joueur)
	while main_adversaire.get_child_count() < 5 and deck_manche.size() > 0:
		creer_carte(deck_manche.pop_front(), main_adversaire)
	
#func piocher_jusqua_cinq():
	#var mes_choix_ia = ["ait nouri", "maguire", "ibrahimovic", "kubo", "iniesta"]
	#var mes_choix_joueur = ["neymar", "mendes", "beckham", "courtois", "c. ronaldo"]
	#for nom in mes_choix_joueur:
		#var info = trouver_carte_par_nom(nom)
		#if info:
			#creer_carte(info, main_joueur)
	#for nom in mes_choix_ia:
		#var info = trouver_carte_par_nom(nom)
		#if info:
			#creer_carte(info, main_adversaire)

# --- FONCTION UTILITAIRE POUR CHERCHER DANS LE DECK_BASE ---
func trouver_carte_par_nom(nom_recherche: String):
	for info in Collection.deck_base:
		# On compare en minuscules pour éviter les erreurs de frappe
		if info["nom"].to_lower() == nom_recherche.to_lower():
			return info
	print("ATTENTION : La carte ", nom_recherche, " n'existe pas dans le CSV !")
	return null

func creer_carte(info, emplacement):
	var nouvelle_carte = SCENE_CARTE.instantiate()
	emplacement.add_child(nouvelle_carte)
	nouvelle_carte.custom_minimum_size = Vector2(120, 175)
	nouvelle_carte.size = Vector2(120, 175)
	nouvelle_carte.remplir_infos(info)
	if emplacement == main_adversaire:
		nouvelle_carte.rendre_visible(false)
		nouvelle_carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		nouvelle_carte.rendre_visible(true)
	if not nouvelle_carte.carte_cliquee.is_connected(_on_carte_jouee):
		nouvelle_carte.carte_cliquee.connect(_on_carte_jouee)
	return nouvelle_carte

func _on_btn_retour_menu_pressed():
	btn_retour_menu.visible = false
	btn_regles_in_game.visible = false
	indicateur_bonus_adv.visible = false 
	carte_bonus_visuelle.visible = false            
	panel_joker.visible = false
	btn_stats.visible = false         
	menu_demarrage.visible = true
	label_message.text = "CHOISIS UN MODE DE JEU"
	label_message.add_theme_color_override("default_color", Color("f3f3f3"))
	for c in main_joueur.get_children(): c.queue_free()
	for c in main_adversaire.get_children(): c.queue_free()
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()

func _on_btn_ouvrir_regles_pressed():
	panel_regles.visible = true
	voile_regles.visible = false
	btn_quitter.visible = false

func _on_btn_fermer_regles_pressed():
	panel_regles.visible = false
	voile_regles.visible = false
	get_tree().paused = false
	if menu_demarrage.visible == true :
		btn_quitter.visible = true
	else:
		btn_abandonner_partie.visible = true

func _on_btn_regles_in_game_pressed():
	panel_regles.visible = true
	voile_regles.visible = true
	get_tree().paused = true
	#btn_abandonner_partie.visible = false

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		for c in main_adversaire.get_children():
			c.rendre_visible(true)
		print("CHEAT ACTIVÉ : Main adverse visible")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		for c in main_adversaire.get_children():
			c.rendre_visible(false)
		print("CHEAT ACTIVÉ : Main adverse invisible")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_T:
		indicateur_bonus_adv.texture = TEXTURES_BONUS[bonus_adversaire]
		print("CHEAT ACTIVÉ : Bonus adverse visible =", bonus_adversaire)

func _on_carte_bonus_joueur_pressed():
	if not bonus_joueur_dispo: return
	if bonus_joueur == "JOKER": 
		ouvrir_menu_joker()
		bonus_joueur_dispo = false
		carte_bonus_visuelle.visible = false
		carte_bonus_visuelle.disabled = true
	else: 
		appliquer_bonus("JOUEUR", bonus_joueur)
		bonus_joueur_dispo = false
		carte_bonus_visuelle.visible = false
		carte_bonus_visuelle.disabled = true

func _on_btn_abandonner_pressed():
	overlay_abandon.visible = true
	get_tree().paused = true

# Si le joueur clique sur OUI
func _on_btn_oui_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_btn_non_pressed():
	overlay_abandon.visible = false
	get_tree().paused = false

func _on_btn_quitter_pressed():
	# Si on est sur un navigateur (HTML5), on ne peut pas quitter
	if OS.has_feature("web"):
		label_message.text = "Impossible de quitter sur navigateur"
	else:
		# Pour Windows, Mac, Linux, Android, iOS
		get_tree().quit()

func _on_btn_stats_pressed():
	btn_stats.visible = true
	var scene_stats = SCENE_STATS.instantiate()
	get_tree().root.add_child(scene_stats)
	scene_stats.initialiser(stats_partie)

func _on_btn_boutique_pressed():
	var boutique = SCENE_BOUTIQUE.instantiate()
	get_tree().root.add_child(boutique)
	
func _on_btn_album_pressed():
	var album = SCENE_ALBUM.instantiate()
	get_tree().root.add_child(album)
