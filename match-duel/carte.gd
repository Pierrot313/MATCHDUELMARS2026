extends Panel

signal carte_cliquee(la_carte_elle_meme)
var infos = {}

@onready var label_nom = $BandeauNom/Nom
@onready var label_poste = $BandeauHaut/Poste
@onready var label_note = $BandeauHaut/Note
@onready var label_nationalite = $BandeauBas/Nationalite
@onready var label_numero = $BandeauBas/Numero
@onready var cadre_legende = $CadreLegende
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
	label_nationalite.text = donnees_carte["nationalite"]

	# Image du joueur
	charger_photo(donnees_carte["nom"])

	# Légende / Icône
	var est_legende = false
	if typeof(donnees_carte["legende"]) == TYPE_BOOL:
		est_legende = donnees_carte["legende"]
	elif str(donnees_carte["legende"]).to_lower() == "oui":
		est_legende = true
	
	cadre_legende.visible = est_legende
	
	changer_style_selon_poste(donnees_carte["poste"], est_legende)

func charger_photo(nom_joueur):
	# Nettoie le nom pour correspondre au nom de fichier
	var nom_fichier = nom_joueur.replace(" ", "_") + ".png"
	var chemin = "res://joueurs/" + nom_fichier
	
	if ResourceLoader.exists(chemin):
		photo_joueur.texture = load(chemin)
	else:
		# Silhouette par défaut
		photo_joueur.texture = load("res://joueurs/default.png")

func changer_style_selon_poste(poste, est_legende):
	var style = get_theme_stylebox("panel").duplicate()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.bg_color = Color(0, 0, 0, 0)
	
	if est_legende:
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color("#f0c040")
		style.border_blend = false
		cadre_legende.visible = false
	else:
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		cadre_legende.visible = false
	
	add_theme_stylebox_override("panel", style)

func rendre_visible(est_visible):
	dos.visible = not est_visible

func set_cliquable(peut_cliquer):
	if peut_cliquer:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
