extends Panel

signal carte_cliquee(la_carte_elle_meme)
var infos = {}

@onready var label_nom = $BandeauNom/Nom
@onready var label_poste = $BandeauHaut/Poste
@onready var label_note = $BandeauHaut/Note
#@onready var label_nationalite = $BandeauBas/Nationalite
@onready var texture_drapeau = $BandeauBas/Drapeau
@onready var label_numero = $BandeauBas/Numero
@onready var label_icone = $CadreLegende/LabelLegende
@onready var cadre_legende = $CadreLegende
@onready var cadre_normal = $CadreNormal
@onready var photo_joueur = $PhotoJoueur
@onready var dos = $Dos

# Abréviations des postes
const ABREV_POSTE = {
	"GARDIEN": "GK",
	"DEFENSEUR": "DEF",
	"MILIEU": "MIL",
	"ATTAQUANT": "ATT"
}

func _ready():
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Cette option aide à découper le contenu textuel, 
	# mais pour le Sprite2D, assure-toi d'avoir mis "Clip Children" sur "Clip Only" dans l'Inspecteur.
	clip_contents = true

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		carte_cliquee.emit(self)

func remplir_infos(donnees_carte):
	infos = donnees_carte
	label_nom.text = donnees_carte["nom"].to_upper()
	# Poste en abrégé
	var poste_maj = str(donnees_carte["poste"]).to_upper()
	label_poste.text = ABREV_POSTE.get(poste_maj, donnees_carte["poste"])
	label_note.text = str(donnees_carte["note"])
	label_numero.text = str(donnees_carte.get("numero", ""))
	#label_nationalite.text = donnees_carte["nationalite"]
	charger_drapeau(donnees_carte["nationalite"])
	# Image du joueur
	charger_photo(donnees_carte["nom"])
	# Légende / Icône
	var est_legende = false
	if typeof(donnees_carte["legende"]) == TYPE_BOOL:
		est_legende = donnees_carte["legende"]
	elif str(donnees_carte["legende"]).to_lower() == "oui":
		est_legende = true
	label_icone.visible = est_legende
	cadre_legende.visible = est_legende
	changer_style_selon_poste(donnees_carte["poste"], est_legende)
	
func charger_drapeau(code_pays):
	var chemin = "res://drapeaux/" + str(code_pays).to_upper() + ".png"
	
	if ResourceLoader.exists(chemin):
		texture_drapeau.texture = load(chemin)
	else:
		# Optionnel : mettre un drapeau par défaut ou rien si le fichier manque
		texture_drapeau.texture = null 
		print("Drapeau manquant pour : ", code_pays)

func charger_photo(nom_joueur):
	var nom_fichier = nom_joueur.replace(" ", "_") + ".jpg"
	var chemin = "res://joueurs/" + nom_fichier
	
	if ResourceLoader.exists(chemin):
		photo_joueur.texture = load(chemin)
		ajuster_taille_photo_manuellement()
	else:
		photo_joueur.texture = load("res://joueurs/default.png")
		ajuster_taille_photo_manuellement()

func changer_style_selon_poste(poste, est_legende):
	var style = get_theme_stylebox("panel").duplicate()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.bg_color = Color(1, 1, 1, 1)
	
	if est_legende:
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color("#f0c040")
		style.border_blend = false
		cadre_legende.visible = true
		cadre_normal.visible = false
	else:
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		cadre_normal.visible = true
		cadre_legende.visible = true
	
	add_theme_stylebox_override("panel", style)

func rendre_visible(est_visible):
	dos.visible = not est_visible

func set_cliquable(peut_cliquer):
	if peut_cliquer:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
func ajuster_taille_photo_manuellement(taille_forcee: Vector2 = Vector2.ZERO):
	if photo_joueur.texture == null: return
	var taille_image = photo_joueur.texture.get_size()
	# Toujours utiliser la taille de référence 120x175
	var taille_carte = Vector2(120, 175)
	var ratio_y = taille_carte.y / taille_image.y
	photo_joueur.scale = Vector2(ratio_y, ratio_y)
	photo_joueur.position = taille_carte / 2
	
func ajuster_echelle(taille_cible: Vector2):
	var scale_x = taille_cible.x / 120.0  # 120 = taille de référence
	var scale_y = taille_cible.y / 175.0  # 175 = taille de référence
	# Scale global de toute la carte
	scale = Vector2(scale_x, scale_y)
	# Remet la taille à la bonne valeur après le scale
	custom_minimum_size = taille_cible
	size = taille_cible
	ajuster_taille_photo_manuellement(Vector2(120, 175))
	
func reveler_au_survol():
	mouse_entered.connect(func():
		rendre_visible(true))
