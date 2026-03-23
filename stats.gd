extends Control

const SCENE_CARTE = preload("res://Carte2.tscn")

@onready var recap_joueur = %RecapJoueur
@onready var recap_adversaire = %RecapAdversaire
@onready var recap_manche_joueur = %RecapMancheJoueur
@onready var recap_manche_adversaire = %RecapMancheAdversaire
@onready var boutons_manche = %BoutonsManche
#@onready var top11_joueur = %Top11Joueur
#@onready var top11_adversaire = %Top11Adversaire
@onready var score_top11_joueur = %ScoreJoueur
@onready var score_top11_adversaire = %ScoreAdversaire
@onready var btn_fermer = %BtnFermerStats

@onready var ligne_adv1 = %LigneAdv1
@onready var ligne_adv2 = %LigneAdv2

@onready var ligne_jou1 = %LigneJou1
@onready var ligne_jou2 = %LigneJou2

var donnees_partie = {}
var manche_selectionnee = 0

func initialiser(stats: Dictionary):
	donnees_partie = stats
	afficher_recap_global()
	generer_boutons_manches()
	if donnees_partie["manches"].size() > 0:
		selectionner_manche(0)

func afficher_recap_global():
	var total_cartes_j = 0
	var total_cartes_adv = 0
	var total_tours_j = 0
	var total_tours_adv = 0
	
	for manche in donnees_partie["manches"]:
		total_cartes_j += manche["pile_joueur"].size()
		total_cartes_adv += manche["pile_adversaire"].size()
		total_tours_j += manche["tours_gagnes_joueur"]
		total_tours_adv += manche["tours_gagnes_adversaire"]
	
	recap_joueur.text = "JOUEUR\n%d cartes gagnées, %d tours gagnés" % [total_cartes_j, total_tours_j]
	recap_adversaire.text = "ADVERSAIRE\n%d cartes gagnées, %d tours gagnés" % [total_cartes_adv, total_tours_adv]

func generer_boutons_manches():
	for enfant in boutons_manche.get_children():
		enfant.queue_free()
	
	for i in range(donnees_partie["manches"].size()):
		var btn = Button.new()
		btn.text = "Manche %d" % (i + 1)
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(105, 0)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color("#2856b9")
		style_normal.corner_detail = 8
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color("#12327f")
		style_normal.border_blend = false
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_left = 5
		style_normal.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", style_normal)
		
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color("#2856b9")
		style_pressed.corner_detail = 8
		style_pressed.border_width_left = 2
		style_pressed.border_width_top = 2
		style_pressed.border_width_right = 2
		style_pressed.border_width_bottom = 2
		style_pressed.border_color = Color("#cccccc")
		style_pressed.border_blend = false
		style_pressed.corner_radius_top_left = 5
		style_pressed.corner_radius_top_right = 5
		style_pressed.corner_radius_bottom_left = 5
		style_pressed.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("pressed", style_pressed)
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color("#2856b9")
		style_hover.corner_detail = 8
		style_hover.border_width_left = 2
		style_hover.border_width_top = 2
		style_hover.border_width_right = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = Color("#cccccc")
		style_hover.border_blend = false
		style_hover.corner_radius_top_left = 5
		style_hover.corner_radius_top_right = 5
		style_hover.corner_radius_bottom_left = 5
		style_hover.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("hover", style_hover)
		
		var style_hover_pressed = StyleBoxFlat.new()
		style_hover_pressed.bg_color = Color("#2856b9")
		style_hover_pressed.corner_detail = 8
		style_hover_pressed.border_width_left = 2
		style_hover_pressed.border_width_top = 2
		style_hover_pressed.border_width_right = 2
		style_hover_pressed.border_width_bottom = 2
		style_hover_pressed.border_color = Color("#12327f")
		style_hover_pressed.border_blend = false
		style_hover_pressed.corner_radius_top_left = 5
		style_hover_pressed.corner_radius_top_right = 5
		style_hover_pressed.corner_radius_bottom_left = 5
		style_hover_pressed.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("hover_pressed", style_hover_pressed)
		
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.button_down.connect(func():
			var style_click = StyleBoxFlat.new()
			style_click.bg_color = Color("#2856b9")
			style_click.corner_detail = 8
			style_click.border_width_left = 2
			style_click.border_width_top = 2
			style_click.border_width_right = 2
			style_click.border_width_bottom = 2
			style_click.border_color = Color("#cccccc")
			style_click.border_blend = false
			style_click.corner_radius_top_left = 5
			style_click.corner_radius_top_right = 5
			style_click.corner_radius_bottom_left = 5
			style_click.corner_radius_bottom_right = 5
			btn.add_theme_stylebox_override("pressed", style_click)
		)
		
		btn.pressed.connect(selectionner_manche.bind(i))
		boutons_manche.add_child(btn)

func selectionner_manche(index: int):
	manche_selectionnee = index
	var manche = donnees_partie["manches"][index]
	
	var boutons = boutons_manche.get_children()
	for i in range(boutons.size()):
		boutons[i].button_pressed = (i == index)
		
		var couleur_pressed = Color("#cccccc") if i == index else Color("#12327f")
		
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color("#2856b9")
		style_pressed.corner_detail = 8
		style_pressed.border_width_left = 2
		style_pressed.border_width_top = 2
		style_pressed.border_width_right = 2
		style_pressed.border_width_bottom = 2
		style_pressed.border_color = couleur_pressed
		style_pressed.border_blend = false
		style_pressed.corner_radius_top_left = 5
		style_pressed.corner_radius_top_right = 5
		style_pressed.corner_radius_bottom_left = 5
		style_pressed.corner_radius_bottom_right = 5
		boutons[i].add_theme_stylebox_override("pressed", style_pressed)
		
		var style_hover_pressed = style_pressed.duplicate()
		style_hover_pressed.border_color = couleur_pressed
		boutons[i].add_theme_stylebox_override("hover_pressed", style_hover_pressed)
	
	var nb_cartes_j = manche["pile_joueur"].size()
	var nb_cartes_adv = manche["pile_adversaire"].size()
	var tours_j = manche["tours_gagnes_joueur"]
	var tours_adv = manche["tours_gagnes_adversaire"]
	
	recap_manche_joueur.text = "Joueur : %d cartes · %d tours gagnés" % [nb_cartes_j, tours_j]
	recap_manche_adversaire.text = "Adversaire : %d cartes · %d tours gagnés" % [nb_cartes_adv, tours_adv]
	
	await get_tree().process_frame
	await get_tree().process_frame
	await afficher_top11(manche["pile_joueur"], manche["pile_adversaire"])

func afficher_top11(pile_j: Array, pile_adv: Array):
	# Vide les zones
	for c in ligne_adv1.get_children(): c.queue_free()
	for c in ligne_adv2.get_children(): c.queue_free()
	for c in ligne_jou1.get_children(): c.queue_free()
	for c in ligne_jou2.get_children(): c.queue_free()
	await get_tree().process_frame
	
	var top_j = calculer_top11(pile_j)
	var top_adv = calculer_top11(pile_adv)
	
	# Crée les mini-cartes joueur
	var score_jou = 0
	for i in range(top_j.size()):
		# Les 6 premières cartes sur la ligne 1, le reste sur la ligne 2
		var parent_cible = ligne_jou1 if i < 6 else ligne_jou2
		await creer_mini_carte(top_j[i], parent_cible)
		score_jou += top_j[i]["note"]
	
	# Crée les mini-cartes adversaire
	var score_adv = 0
	for i in range(top_adv.size()):
		# Les 6 premières cartes sur la ligne 1, le reste sur la ligne 2
		var parent_cible = ligne_adv1 if i < 6 else ligne_adv2
		await creer_mini_carte(top_adv[i], parent_cible)
		score_adv += top_adv[i]["note"]
		
	score_top11_joueur.text = str(score_jou) + " pts"
	score_top11_adversaire.text = str(score_adv) + " pts"

func calculer_top11(pile: Array) -> Array:
	var copie = pile.duplicate()
	copie.sort_custom(func(a, b): return a["note"] > b["note"])
	return copie.slice(0, min(11, copie.size()))

func creer_mini_carte(info: Dictionary, parent: Node):
	var carte = SCENE_CARTE.instantiate()
	carte.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	parent.add_child(carte)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var colonnes = 6 if parent == ligne_adv1 or parent == ligne_adv2 or parent == ligne_jou1 or parent == ligne_jou2 else 4
	var largeur_dispo = parent.size.x / colonnes - 8
	var hauteur_dispo = parent.size.y - 8  # ← une seule ligne, pas de division
	
	var ratio = 120.0 / 175.0
	var largeur_finale = min(largeur_dispo, hauteur_dispo * ratio)
	var hauteur_finale = largeur_finale / ratio
	
	carte.set_cliquable(false)
	carte.rendre_visible(true)
	carte.ajuster_echelle(Vector2(largeur_finale, hauteur_finale))
	carte.remplir_infos(info)

func _on_btn_fermer_stats_pressed():
	queue_free()
