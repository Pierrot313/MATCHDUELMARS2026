extends Control

const SCENE_CARTE = preload("res://Carte2.tscn")

@onready var label_points = %LabelPoints
@onready var btn_fermer_boutique = %BtnFermerBoutique
@onready var panel_resultat = %PanelResultat
@onready var label_resultat = %LabelResultat
@onready var zone_cartes = %ZoneCartes
@onready var btn_fermer_resultat = %BtnFermerResultat
@onready var btn_pack_classique = %BtnPackClassique
@onready var btn_pack_rare = %BtnPackRare
@onready var btn_pack_ultime = %BtnPackUltime
@onready var zone_labels_doublon = %ZoneLabelsDoublon

@onready var label_erreur = %LabelErreur

func _ready():
	mettre_a_jour_points()
	panel_resultat.visible = false

func mettre_a_jour_points():
	label_points.text = "Points : " + str(Collection.points)

func acheter_pack(type_pack: String):
	var cout = 0
	var config = {}
	
	match type_pack:
		"classique":
			cout = Collection.COUT_PACK_CLASSIQUE
			config = Collection.PACK_CLASSIQUE
		"rare":
			cout = Collection.COUT_PACK_RARE
			config = Collection.PACK_RARE
		"ultime":
			cout = Collection.COUT_PACK_ULTIME
			config = Collection.PACK_ULTIME
	
	# Vérification des points
	if Collection.points < cout:
		label_erreur.text = "Pas assez de points ! Il te faut " + str(cout - Collection.points) + " points de plus."
		await get_tree().create_timer(3.0, false).timeout
		label_erreur.text = ""
		return
	
	# Déduction des points
	Collection.ajouter_points(-cout)
	mettre_a_jour_points()
	
	# Tirage des cartes
	var cartes_tirees = tirer_cartes(config)
	
	# Affichage des cartes
	afficher_resultat(cartes_tirees)

func tirer_cartes(config: Dictionary) -> Array:
	var cartes_tirees = []
	
	var probas_garanti = {
		"classique": {
			83: 29.0, 84: 24.8, 85: 16.5, 86: 8.5, 87: 6.5, 88: 4.5,
			89: 2.9, 90: 2.4, 91: 2.0, 92: 1.5, 93: 1.0, 94: 0.3, 95: 0.1
		},
		"rare": {
			85: 30.0, 86: 25.0, 87: 17.0, 88: 8.5, 89: 6.2, 90: 3.8,
			91: 3.1, 92: 2.6, 93: 1.8, 94: 1.5, 95: 0.5
		},
		"ultime": {
			87: 35.0, 88: 23.5, 89: 15.5, 90: 8.5, 91: 6.2, 92: 3.8,
			93: 3.1, 94: 2.6, 95: 1.8
		}
	}
	
	var probas_normal = {
		"classique": {
			77: 17.0, 78: 16.0, 79: 14.0, 80: 12.0, 81: 10.0, 82: 9.0,
			83: 8.0, 84: 6.0, 85: 4.0, 86: 2.0, 87: 1.0, 88: 0.5,
			89: 0.2, 90: 0.134, 91: 0.1, 92: 0.05, 93: 0.01, 94: 0.005, 95: 0.001
		},
		"rare": {
			77: 14.44, 78: 13.0, 79: 12.0, 80: 10.5, 81: 9.0, 82: 8.0,
			83: 7.5, 84: 7.0, 85: 5.8, 86: 4.0, 87: 2.5, 88: 2.0,
			89: 1.5, 90: 1.2, 91: 0.9, 92: 0.5, 93: 0.1, 94: 0.05, 95: 0.01
		},
		"ultime": {
			77: 13.0, 78: 12.0, 79: 11.0, 80: 9.2, 81: 8.0, 82: 6.1,
			83: 6.5, 84: 5.8, 85: 5.3, 86: 6.4, 87: 4.5, 88: 3.5,
			89: 2.7, 90: 2.1, 91: 1.6, 92: 1.0, 93: 0.8, 94: 0.4, 95: 0.1
		}
	}
	
	var mult_normal = {"classique": 1000, "rare": 100, "ultime": 10}
	var type_pack = config["type"]
	
	# --- CARTE GARANTIE (toujours x10, tirage [1;1000]) ---
	var note_garantie = tirer_note(probas_garanti[type_pack], 10)
	var carte_garantie = chercher_carte_par_note(note_garantie, cartes_tirees)
	if carte_garantie != {}:
		cartes_tirees.append(carte_garantie)
	
	# --- 4 CARTES NORMALES ---
	var mult = mult_normal[type_pack]
	for i in range(4):
		var note = tirer_note(probas_normal[type_pack], mult)
		var carte = chercher_carte_par_note(note, cartes_tirees)
		if carte != {}:
			cartes_tirees.append(carte)
	
	return cartes_tirees

func tirer_note(table_probas: Dictionary, multiplicateur: int) -> int:
	var notes = table_probas.keys()
	notes.sort()
	
	var curseur = 0
	var intervalles = []
	for note in notes:
		var debut = curseur + 1
		var fin = curseur + int(table_probas[note] * multiplicateur)
		intervalles.append({"note": note, "debut": debut, "fin": fin})
		curseur = fin
	
	var tirage = randi_range(1, curseur)
	
	for intervalle in intervalles:
		if tirage >= intervalle["debut"] and tirage <= intervalle["fin"]:
			return intervalle["note"]
	
	return notes.back()

func chercher_carte_par_note(note_cible: int, deja_tirees: Array) -> Dictionary:
	var candidats = []
	for info in Collection.deck_base:
		if info["note"] == note_cible:
			var deja = false
			for tiree in deja_tirees:
				if tiree["nom"] == info["nom"]:
					deja = true
					break
			if not deja:
				candidats.append(info)
	
	if candidats.size() > 0:
		candidats.shuffle()
		return candidats[0]
	
	# Aucune carte à cette note → cherche la note la plus proche
	var notes_dispo = []
	for info in Collection.deck_base:
		var deja = false
		for tiree in deja_tirees:
			if tiree["nom"] == info["nom"]:
				deja = true
				break
		if not deja and not (info["note"] in notes_dispo):
			notes_dispo.append(info["note"])
	
	if notes_dispo.size() == 0:
		return {}
	
	var note_proche = notes_dispo[0]
	for n in notes_dispo:
		if abs(n - note_cible) < abs(note_proche - note_cible):
			note_proche = n
	
	return chercher_carte_par_note(note_proche, deja_tirees)

func afficher_resultat(cartes: Array):
	for c in zone_cartes.get_children():
		c.queue_free()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	for info in cartes:
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		zone_cartes.add_child(vbox)
		
		var carte = SCENE_CARTE.instantiate()
		vbox.add_child(carte)
		carte.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		carte.custom_minimum_size = Vector2(120, 175)
		carte.size = Vector2(120, 175)
		carte.remplir_infos(info)
		carte.rendre_visible(false)
		carte.set_cliquable(false)
		carte.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var lbl = Label.new()
		lbl.custom_minimum_size = Vector2(120, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = ""
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		vbox.add_child(lbl)
		
		var est_doublon = Collection.nb_exemplaires(info["nom"]) > 1
		carte.mouse_entered.connect(func():
			carte.rendre_visible(true)
			if est_doublon:
				lbl.text = "Déjà possédé"
		)
	
	label_resultat.text = ""
	mettre_a_jour_points()
	panel_resultat.visible = true

func _on_btn_fermer_boutique_pressed():
	print("Fermer boutique pressed")
	queue_free()

func _on_btn_fermer_resultat_pressed():
	panel_resultat.visible = false
	zone_cartes.visible = true

func _on_btn_pack_classique_pressed():
	print("Pack classique pressed")
	acheter_pack("classique")

func _on_btn_pack_rare_pressed():
	acheter_pack("rare")

func _on_btn_pack_ultime_pressed():
	acheter_pack("ultime")
