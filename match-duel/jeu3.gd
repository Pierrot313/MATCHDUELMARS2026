extends Control

const SCENE_CARTE = preload("res://Carte2.tscn")

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
@onready var btn_bonus = %BtnBonus
@onready var indicateur_bonus_adv = %IndicateurBonusAdv
@onready var panel_joker = %PanelJoker 
@onready var btn_valider_echange = %BtnValiderEchange
@onready var btn_retour_menu = %BtnRetourMenu

# Règles
@onready var panel_regles = %PanelRegles
@onready var btn_ouvrir_regles = %BtnOuvrirRegles
@onready var btn_fermer_regles = %BtnFermerRegles
@onready var btn_regles_in_game = %BtnReglesInGame

# --- DONNÉES ---
var deck_base = [] 
var deck_manche = [] 

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

func _ready():
	randomize()
	charger_donnees()
	menu_demarrage.visible = true
	panel_regles.visible = false
	panel_joker.visible = false
	btn_bonus.visible = false
	indicateur_bonus_adv.visible = false
	btn_passer.visible = false
	btn_valider_echange.visible = false
	btn_regles_in_game.visible = false

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
	manches_pour_gagner = obj
	score_manches_j = 0
	score_manches_adv = 0
	menu_demarrage.visible = false
	commencer_nouvelle_manche()

func commencer_nouvelle_manche():
	minute_jeu = 0
	pile_gagnees_joueur = []
	pile_gagnees_adversaire = []
	deck_manche = deck_base.duplicate()
	deck_manche.shuffle()
	
	for c in main_joueur.get_children(): c.queue_free()
	for c in main_adversaire.get_children(): c.queue_free()
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()
	
	await get_tree().create_timer(0.1).timeout
	
	bonus_joueur = TYPES_BONUS.pick_random()
	bonus_adversaire = TYPES_BONUS.pick_random()
	
	bonus_joueur_dispo = true
	bonus_adversaire_dispo = true
	
	btn_bonus.text = "BONUS : " + bonus_joueur
	indicateur_bonus_adv.visible = true
	btn_regles_in_game.visible = true
	
	joueur_a_l_initiative = false
	mettre_a_jour_interface_globale()
	piocher_jusqua_cinq()
	
	label_message.text = "NOUVELLE MANCHE !"
	await get_tree().create_timer(2.0).timeout
	commencer_nouveau_tour()

func mettre_a_jour_interface_globale():
	label_compteur_joueur.text = "Manches: " + str(score_manches_j) + "/" + str(manches_pour_gagner) + "\nCartes: " + str(pile_gagnees_joueur.size())
	label_compteur_adversaire.text = "Manches: " + str(score_manches_adv) + "/" + str(manches_pour_gagner) + "\nCartes: " + str(pile_gagnees_adversaire.size())
	label_chrono.text = str(minute_jeu) + "'"

func verifier_fin_manche():
	if minute_jeu > 90 or (deck_manche.size() == 0 and main_joueur.get_child_count() == 0):
		calculer_vainqueur_manche()
		return true
	return false

func calculer_vainqueur_manche():
	print_rich("[b][color=yellow]!!! DÉBUT CALCUL DES SCORES !!![/color][/b]")
	
	tour_en_cours = true
	set_cartes_joueur_cliquables(false)
	label_message.text = "FIN DE LA MANCHE\nCALCUL DU TOP 11..."
	label_message.modulate = Color.YELLOW
	
	await get_tree().create_timer(2.0).timeout
	
	print("Nombre de cartes gagnées par Joueur : ", pile_gagnees_joueur.size())
	print("Nombre de cartes gagnées par Adversaire : ", pile_gagnees_adversaire.size())
	
	var total_j = somme_top_11(pile_gagnees_joueur)
	var total_adv = somme_top_11(pile_gagnees_adversaire)
	
	print("\n========== DÉTAIL DU SCORE ==========")
	print("--- ÉQUIPE JOUEUR ---")
	if pile_gagnees_joueur.size() == 0:
		print("Aucune carte gagnée.")
	else:
		for i in range(min(11, pile_gagnees_joueur.size())):
			var c = pile_gagnees_joueur[i]
			print(str(i+1) + ". " + c["nom"] + " (Note: " + str(c["note"]) + ")")

	print("\n--- ÉQUIPE ADVERSAIRE ---")
	if pile_gagnees_adversaire.size() == 0:
		print("Aucune carte gagnée.")
	else:
		for i in range(min(11, pile_gagnees_adversaire.size())):
			var c = pile_gagnees_adversaire[i]
			print(str(i+1) + ". " + c["nom"] + " (Note: " + str(c["note"]) + ")")
	print("=====================================\n")

	var txt = "J: " + str(total_j) + " pts  VS  Adv: " + str(total_adv) + " pts\n"
	if total_j > total_adv:
		score_manches_j += 1
		txt += "TU GAGNES LA MANCHE !"
		label_message.modulate = Color.GREEN
	elif total_adv > total_j:
		score_manches_adv += 1
		txt += "L'ADVERSAIRE GAGNE LA MANCHE..."
		label_message.modulate = Color.RED
	else:
		score_manches_j += 1
		txt += "ÉGALITÉ (AVANTAGE JOUEUR)"
	label_message.text = txt
	mettre_a_jour_interface_globale()
	await get_tree().create_timer(4.0).timeout
	verifier_fin_partie_globale()

func somme_top_11(pile):
	pile.sort_custom(func(a, b): return a["note"] > b["note"])
	var total = 0
	var nombre_a_compter = min(11, pile.size())
	for i in range(nombre_a_compter): total += pile[i]["note"]
	return total

func verifier_fin_partie_globale():
	if score_manches_j >= manches_pour_gagner:
		label_message.text = "🏆 VICTOIRE ! 🏆"
		label_message.modulate = Color.GOLD
		btn_retour_menu.visible = true
	elif score_manches_adv >= manches_pour_gagner:
		label_message.text = "💀 DÉFAITE 💀"
		label_message.modulate = Color.GRAY
		btn_retour_menu.visible = true
	else:
		commencer_nouvelle_manche()

# ==============================================================================
# LOGIQUE BONUS
# ==============================================================================

func _on_btn_bonus_pressed():
	if not bonus_joueur_dispo: return
	if bonus_joueur == "JOKER": ouvrir_menu_joker()
	else: appliquer_bonus("JOUEUR", bonus_joueur)

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
		btn_voler_bonus.text = "CONTRER ET VOLER\n" + bonus_joue_ce_tour_adversaire
		btn_voler_bonus.modulate = Color.GREEN
	else:
		btn_voler_bonus.disabled = true
		btn_voler_bonus.text = "VOL IMPOSSIBLE\n(" + raison_blocage + ")"
		btn_voler_bonus.modulate = Color.WHITE

func _on_btn_joker_espion_pressed(): appliquer_bonus("JOUEUR", "ESPIONNAGE")
func _on_btn_joker_vol_pressed(): appliquer_bonus("JOUEUR", "VOL")
func _on_btn_joker_boost_pressed(): appliquer_bonus("JOUEUR", "BOOST")
func _on_btn_joker_voler_bonus_pressed(): appliquer_bonus("JOUEUR", "VOL_BONUS_ADVERSE")
func _on_btn_joker_remplacement_pressed(): appliquer_bonus("JOUEUR", "REMPLACEMENT")

func annuler_effet_vol_ia():
	print("--- DÉBUT ANNULATION VOL ---")
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

func appliquer_bonus(qui, type):
	if qui == "JOUEUR":
		panel_joker.visible = false
		bonus_joueur_dispo = false
		btn_bonus.visible = false
		
		if type == "VOL_BONUS_ADVERSE":
			var bonus_cible = bonus_joue_ce_tour_adversaire
			var succes_annulation = false
			
			if bonus_cible == "BOOST":
				boost_actif_adversaire = 0
				label_message.text = "BOOST ADVERSE ANNULÉ ET VOLÉ !"
				succes_annulation = true
			elif bonus_cible == "VOL":
				if annuler_effet_vol_ia():
					label_message.text = "ÉCHANGE ANNULÉ ! TU RÉCUPÈRES TA CARTE."
					succes_annulation = true
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
		bonus_adversaire_dispo = false
		indicateur_bonus_adv.visible = false
		label_message.text = "L'ADVERSAIRE JOUE : " + type
		bonus_joue_ce_tour_adversaire = type
		
		match type:
			"BOOST": boost_actif_adversaire = 3
			"VOL": effet_vol_ia()
			"REMPLACEMENT": effet_remplacement_ia()
		
		await get_tree().create_timer(3.0).timeout

func annuler_bonus_adverse(qui_vole):
	if qui_vole == "JOUEUR": boost_actif_adversaire = 0

func effet_espionnage_joueur():
	for c in main_adversaire.get_children(): c.rendre_visible(true)
	await get_tree().create_timer(5.0).timeout
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

func effet_vol_ia():
	if main_joueur.get_child_count() > 0 and main_adversaire.get_child_count() > 0:
		var pire_ia = main_adversaire.get_children()[0] 
		var cible_joueur = main_joueur.get_children().pick_random()
		
		memoire_ia_vol = { "carte_ia": pire_ia, "carte_joueur": cible_joueur }
		print("Vol enregistré en mémoire : IA=", pire_ia.name, " / Joueur=", cible_joueur.name)
		
		pire_ia.reparent(main_joueur)
		cible_joueur.reparent(main_adversaire)
		pire_ia.rendre_visible(true)
		cible_joueur.rendre_visible(false)
		
		if not pire_ia.carte_cliquee.is_connected(_on_carte_jouee):
			pire_ia.carte_cliquee.connect(_on_carte_jouee)
		if not cible_joueur.carte_cliquee.is_connected(_on_carte_jouee):
			cible_joueur.carte_cliquee.connect(_on_carte_jouee)

func demarrer_mode_remplacement():
	label_message.text = "SÉLECTIONNE JUSQU'À 4 CARTES À JETER"
	mode_remplacement_actif = true
	cartes_a_remplacer.clear()
	btn_valider_echange.visible = true
	set_cartes_joueur_cliquables(true)

func _on_btn_valider_echange_pressed():
	mode_remplacement_actif = false
	btn_valider_echange.visible = false
	var nb_a_piocher = cartes_a_remplacer.size()
	for c in cartes_a_remplacer:
		c.queue_free()
	await get_tree().create_timer(0.2).timeout
	for i in range(nb_a_piocher):
		if deck_manche.size() > 0:
			creer_carte(deck_manche.pop_front(), main_joueur)
	label_message.text = "MAIN RENOUVELÉE ! À TOI DE JOUER."
	cartes_a_remplacer.clear()
	set_cartes_joueur_cliquables(true)

func effet_remplacement_ia():
	memoire_ia_remplacement = []
	var a_jeter = []
	for c in main_adversaire.get_children():
		if c.infos["note"] < 85:
			a_jeter.append(c)
	
	if a_jeter.size() > 4: a_jeter.resize(4)
	
	if a_jeter.size() > 0:
		label_message.text = "L'ADVERSAIRE REMPLACE " + str(a_jeter.size()) + " CARTES !"
		var infos_anciennes = []
		var refs_nouvelles = []
		
		for c in a_jeter:
			infos_anciennes.append(c.infos)
			c.queue_free()
		
		await get_tree().create_timer(0.2).timeout
		
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
		label_message.text = str(minute_jeu) + "' : C'EST À TOI !"
		label_message.modulate = Color.GREEN
		if bonus_joueur_dispo: btn_bonus.visible = true
		tour_en_cours = false
		set_cartes_joueur_cliquables(true) # Le joueur peut jouer
	else:
		label_message.text = str(minute_jeu) + "' : L'ADVERSAIRE ENGAGE..."
		label_message.modulate = Color.ORANGE
		btn_bonus.visible = false
		await get_tree().create_timer(1.0).timeout
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
	btn_bonus.visible = false
	tour_en_cours = true
	set_cartes_joueur_cliquables(false) # Désactive dès qu'une carte est jouée
	carte.reparent(ligne_joueur)
	carte_duel_joueur = carte
	if carte_duel_adversaire != null:
		label_message.text = "DUEL !"
		await get_tree().create_timer(0.5).timeout
		verifier_bataille_speciale_et_renfort()
	else:
		label_message.text = "L'ADVERSAIRE RÉFLÉCHIT..."
		await get_tree().create_timer(0.5).timeout
		adversaire_repond()

func gerer_clic_vol(carte):
	if vol_etape == 1:
		if carte.get_parent() == main_joueur:
			carte_a_echanger_joueur = carte
			label_message.text = "CHOISIS LA CARTE ADVERSE À VOLER"
			vol_etape = 2
	elif vol_etape == 2:
		if carte.get_parent() == main_adversaire:
			var carte_adverse = carte
			carte_a_echanger_joueur.reparent(main_adversaire)
			carte_adverse.reparent(main_joueur)
			carte_a_echanger_joueur.rendre_visible(false)
			carte_adverse.rendre_visible(true)
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
			print("IA engage : stratégie FORCE (", carte.infos["nom"], ")")
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
				print("IA engage : stratégie RENFORT (", carte.infos["nom"], ")")
			else:
				carte = cartes.pick_random()
				print("IA engage : stratégie RENFORT → repli ALÉATOIRE (", carte.infos["nom"], ")")
		2:
			carte = cartes.pick_random()
			print("IA engage : stratégie ALÉATOIRE (", carte.infos["nom"], ")")

	carte.reparent(ligne_adversaire)
	carte.rendre_visible(true)
	carte_duel_adversaire = carte
	label_message.text = "À TOI DE RÉPONDRE !"
	label_message.modulate = Color.WHITE
	if bonus_joueur_dispo: btn_bonus.visible = true
	tour_en_cours = false
	set_cartes_joueur_cliquables(true) # Le joueur peut répondre

func adversaire_repond():
	await ia_decide_bonus()
	if main_adversaire.get_child_count() == 0: return

	var cartes = main_adversaire.get_children()
	var carte = null
	var p_j = str(carte_duel_joueur.infos["poste"]).to_upper()

	var calc = func(c):
		var s = c.infos["note"]
		var p_ia = str(c.infos["poste"]).to_upper()
		if p_ia == "ATTAQUANT" and p_j == "GARDIEN": s += 2
		elif p_ia == "GARDIEN" and p_j == "MILIEU": s += 2
		elif p_ia == "MILIEU" and p_j == "DEFENSEUR": s += 2
		elif p_ia == "DEFENSEUR" and p_j == "ATTAQUANT": s += 2
		return s

	var score_joueur = carte_duel_joueur.infos["note"]
	var cartes_gagnantes = []
	for c in cartes:
		if calc.call(c) > score_joueur:
			cartes_gagnantes.append(c)

	if cartes_gagnantes.size() > 0:
		if score_joueur > 85:
			var gagnante_avec_renfort = null
			for c in cartes_gagnantes:
				for autre in cartes:
					if autre != c and autre.infos["nationalite"] == c.infos["nationalite"]:
						gagnante_avec_renfort = c
						break
				if gagnante_avec_renfort: break
			if gagnante_avec_renfort:
				carte = gagnante_avec_renfort
				print("IA répond (forte) : GAGNE + RENFORT (", carte.infos["nom"], ")")
			else:
				var best = -1
				for c in cartes_gagnantes:
					if c.infos["note"] > best:
						best = c.infos["note"]
						carte = c
				print("IA répond (forte) : MEILLEURE GAGNANTE (", carte.infos["nom"], ")")
		else:
			var moins_bonne = cartes_gagnantes[0]
			for c in cartes_gagnantes:
				if c.infos["note"] < moins_bonne.infos["note"]:
					moins_bonne = c
			carte = moins_bonne
			print("IA répond (faible) : GAGNE ÉCONOMIQUEMENT (", carte.infos["nom"], ")")
	else:
		var best = -1
		for c in cartes:
			if c.infos["note"] > best:
				best = c.infos["note"]
				carte = c
		print("IA répond : MEILLEURE CARTE (perd quand même) (", carte.infos["nom"], ")")

	carte.reparent(ligne_adversaire)
	carte.rendre_visible(true)
	carte_duel_adversaire = carte
	await get_tree().create_timer(0.5).timeout
	verifier_bataille_speciale_et_renfort()

func ia_decide_bonus():
	if not bonus_adversaire_dispo: return
	var chance_actuelle = 0
	if minute_jeu <= 30: chance_actuelle = 15
	elif minute_jeu <= 65: chance_actuelle = 30
	else: chance_actuelle = 50
	if (randi() % 100) < chance_actuelle:
		if bonus_adversaire == "JOKER":
			var bonus_volables = ["BOOST", "VOL", "REMPLACEMENT"]
			if bonus_joue_ce_tour_joueur in bonus_volables:
				await appliquer_bonus("ADVERSAIRE", "VOL_BONUS_ADVERSE")
			else:
				var choix = ["BOOST", "VOL", "REMPLACEMENT"].pick_random()
				await appliquer_bonus("ADVERSAIRE", choix)
		else:
			await appliquer_bonus("ADVERSAIRE", bonus_adversaire)

func verifier_bataille_speciale_et_renfort():
	var type = check_bataille_speciale(carte_duel_joueur, carte_duel_adversaire)
	if type != "NON":
		label_message.text = "BATAILLE SPÉCIALE : " + type
		label_message.modulate = Color.GOLD
		await get_tree().create_timer(1.5).timeout
		var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
		var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
		lancer_bataille(s1, s2)
		return
	verifier_phase_renfort()

func check_bataille_speciale(c1, c2):
	if c1 == null or c2 == null: return "NON"
	var l1 = str(c1.infos["legende"]).to_lower() in ["oui", "true", "vrai"]
	var l2 = str(c2.infos["legende"]).to_lower() in ["oui", "true", "vrai"]
	if l1 and l2: return "LÉGENDES"
	if c1.infos["nationalite"] == c2.infos["nationalite"]:
		if abs(c1.infos["note"] - c2.infos["note"]) <= 5: return "DERBY"
	return "NON"

func verifier_phase_renfort():
	var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
	var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
	label_message.text = str(s1) + " VS " + str(s2)
	label_message.modulate = Color.WHITE
	await get_tree().create_timer(1.0).timeout
	
	var difficulte = false
	if joueur_a_l_initiative and s1 <= s2: difficulte = true
	if not joueur_a_l_initiative and s2 <= s1: difficulte = true
	
	if difficulte: lancer_demande_renfort(s1, s2)
	else: calculer_score_final_avec_renforts()

func lancer_demande_renfort(s1, s2):
	if joueur_a_l_initiative: verifier_renfort_possible_joueur(s1, s2)
	else: verifier_renfort_possible_adversaire()

func verifier_renfort_possible_joueur(s1, s2):
	if carte_duel_joueur == null: _on_bouton_passer_pressed(); return
	var nat = carte_duel_joueur.infos["nationalite"]
	var possible = false
	for c in main_joueur.get_children():
		if c.infos["nationalite"] == nat:
			possible = true
			c.modulate = Color.YELLOW
			c.set_cliquable(true) # Active uniquement les cartes de renfort
	if possible:
		label_message.text = "RENFORT POSSIBLE (" + nat + ")"
		btn_passer.visible = true
		en_attente_renfort = true
	else:
		label_message.text = "PAS DE RENFORT..."
		await get_tree().create_timer(1.0).timeout
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
	for c in main_adversaire.get_children(): if c.infos["nationalite"] == nat: cand = c
	if cand:
		label_message.text = "L'ADVERSAIRE RENFORCE !"
		await get_tree().create_timer(1.0).timeout
		cand.reparent(ligne_adversaire); cand.rendre_visible(true)
		renfort_adversaire_carte = cand
	else:
		label_message.text = "L'ADVERSAIRE PASSE..."
		await get_tree().create_timer(1.0).timeout
		renfort_adversaire_carte = null
	passer_la_main_apres_renfort_adversaire()

func passer_la_main_apres_renfort_adversaire():
	if joueur_a_l_initiative: calculer_score_final_avec_renforts()
	else:
		if renfort_adversaire_carte:
			var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
			var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur) + renfort_adversaire_carte.infos["note"]
			verifier_renfort_possible_joueur(s1, s2)
		else: calculer_score_final_avec_renforts()

func calculer_score_final_avec_renforts():
	var s1 = calculer_score(carte_duel_joueur, carte_duel_adversaire)
	var s2 = calculer_score(carte_duel_adversaire, carte_duel_joueur)
	if renfort_joueur_carte: s1 += renfort_joueur_carte.infos["note"]
	if renfort_adversaire_carte: s2 += renfort_adversaire_carte.infos["note"]
	if s1 == s2: lancer_bataille(s1, s2)
	else: finir_le_tour(s1, s2)

func lancer_bataille(s1, s2):
	label_message.text = "!!! BATAILLE !!!"
	label_message.modulate = Color.RED
	await get_tree().create_timer(1.5).timeout
	if deck_manche.size() < 4:
		label_message.text = "FIN DU DECK"; calculer_vainqueur_manche(); return

	var sep1 = Control.new(); sep1.custom_minimum_size.x = 50; ligne_joueur.add_child(sep1)
	var sep2 = Control.new(); sep2.custom_minimum_size.x = 50; ligne_adversaire.add_child(sep2)

	for i in range(2):
		var info = deck_manche.pop_front()
		var c = creer_carte(info, ligne_joueur)
		c.modulate = Color(0.7, 1.0, 0.7)
		s1 += info["note"]
	for i in range(2):
		var info = deck_manche.pop_front()
		var c = creer_carte(info, ligne_adversaire)
		c.rendre_visible(true)
		c.modulate = Color(1.0, 0.7, 0.7)
		s2 += info["note"]
	
	label_message.text = str(s1) + " VS " + str(s2)
	label_message.modulate = Color.WHITE
	await get_tree().create_timer(2.5).timeout
	finir_le_tour(s1, s2, true)

func finir_le_tour(s1, s2, bataille=false):
	if s1 > s2:
		label_message.text = "VICTOIRE !"
		label_message.modulate = Color.GREEN
		collecter_cartes_sur_tapis(pile_gagnees_joueur)
	elif s2 > s1:
		label_message.text = "DÉFAITE..."
		label_message.modulate = Color.RED
		collecter_cartes_sur_tapis(pile_gagnees_adversaire)
	else:
		label_message.text = "ÉGALITÉ PARFAITE\nPARTAGE DES POINTS"
		label_message.modulate = Color.CYAN
		for c in ligne_joueur.get_children(): 
			if "infos" in c: pile_gagnees_joueur.append(c.infos)
		for c in ligne_adversaire.get_children(): 
			if "infos" in c: pile_gagnees_adversaire.append(c.infos)
	
	await get_tree().create_timer(2.0).timeout
	
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()
	
	minute_jeu += 5
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

func charger_donnees():
	var fichier = FileAccess.open("res://joueurs.csv", FileAccess.READ)
	if fichier == null: return
	fichier.get_csv_line(";") 
	while fichier.get_position() < fichier.get_length():
		var ligne = fichier.get_csv_line(";")
		if ligne.size() < 6 or ligne[0] == "": continue
		var info = { "nom": ligne[0], "nationalite": ligne[1], "note": int(ligne[2]), "poste": ligne[3], "legende": ligne[4], "numero": ligne[5] }
		deck_base.append(info)

func piocher_jusqua_cinq():
	while main_joueur.get_child_count() < 5 and deck_manche.size() > 0:
		creer_carte(deck_manche.pop_front(), main_joueur)
	while main_adversaire.get_child_count() < 5 and deck_manche.size() > 0:
		creer_carte(deck_manche.pop_front(), main_adversaire)

func creer_carte(info, emplacement):
	var nouvelle_carte = SCENE_CARTE.instantiate()
	emplacement.add_child(nouvelle_carte)
	nouvelle_carte.custom_minimum_size = Vector2(120, 175)
	nouvelle_carte.size = Vector2(120, 175)
	nouvelle_carte.remplir_infos(info)
	if emplacement == main_adversaire:
		nouvelle_carte.rendre_visible(false)
	else:
		nouvelle_carte.rendre_visible(true)
	if not nouvelle_carte.carte_cliquee.is_connected(_on_carte_jouee):
		nouvelle_carte.carte_cliquee.connect(_on_carte_jouee)
	return nouvelle_carte

func _on_btn_retour_menu_pressed():
	btn_retour_menu.visible = false
	btn_regles_in_game.visible = false
	indicateur_bonus_adv.visible = false 
	btn_bonus.visible = false            
	panel_joker.visible = false          
	menu_demarrage.visible = true
	label_message.text = "CHOISIS UN MODE DE JEU"
	label_message.modulate = Color.WHITE
	for c in main_joueur.get_children(): c.queue_free()
	for c in main_adversaire.get_children(): c.queue_free()
	for c in ligne_joueur.get_children(): c.queue_free()
	for c in ligne_adversaire.get_children(): c.queue_free()

func _on_btn_ouvrir_regles_pressed():
	panel_regles.visible = true

func _on_btn_fermer_regles_pressed():
	panel_regles.visible = false

func _on_btn_regles_in_game_pressed():
	panel_regles.visible = true

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		for c in main_adversaire.get_children():
			c.rendre_visible(true)
		print("CHEAT ACTIVÉ : Main adverse visible")
