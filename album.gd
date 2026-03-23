extends Control

const SCENE_CARTE = preload("res://Carte2.tscn")
const TEXTURE_INCONNU = preload("res://inconnu.jpg")

@onready var btn_precedent = %BtnPrecedent
@onready var btn_suivant = %BtnSuivant
@onready var zone_album = %ZoneAlbum
@onready var btn_fermer = %BtnFermerAlbum
@onready var label_page = %LabelPage

var pages = []
var page_courante = 0

func _ready():
	pages = Collection.calculer_pages_album()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	afficher_page(0)

func afficher_page(index: int):
	page_courante = index
	
	# Vide la zone
	for c in zone_album.get_children():
		c.queue_free()
	
	await get_tree().process_frame
	
	var page = pages[index]
	label_page.text = str(index + 1) + " / " + str(pages.size())
	
	btn_precedent.visible = index > 0
	btn_suivant.visible = index < pages.size() - 1
	
	match page["layout"]:
		"grande":
			await afficher_layout_grande(page)
		"moyenne":
			await afficher_layout_moyenne(page)
		"petite":
			await afficher_layout_petite(page)

func afficher_layout_grande(page: Dictionary):
	var nation = page["nations"][0]
	afficher_section(nation["joueurs"], zone_album)

func afficher_layout_moyenne(page: Dictionary):
	for nation in page["nations"]:
		# Séparateur de nationalité
		var separateur = ColorRect.new()
		separateur.custom_minimum_size = Vector2(0, 4)
		separateur.color = Color(1, 1, 1, 0.3)
		zone_album.add_child(separateur)
		
		afficher_section(nation["joueurs"], zone_album)

func afficher_layout_petite(page: Dictionary):
	for nation in page["nations"]:
		var separateur = ColorRect.new()
		separateur.custom_minimum_size = Vector2(0, 4)
		separateur.color = Color(1, 1, 1, 0.3)
		zone_album.add_child(separateur)
		
		afficher_section(nation["joueurs"], zone_album)

func afficher_section(joueurs: Array, parent: Node):
	var grid = GridContainer.new()
	grid.columns = 4
	parent.add_child(grid)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var largeur_zone = zone_album.size.x
	var largeur_dispo = largeur_zone / 4 - 8
	var ratio = 120.0 / 175.0
	var hauteur_dispo = largeur_dispo / ratio
	
	for info in joueurs:
		if Collection.possede_carte(info["nom"]):
			var carte = SCENE_CARTE.instantiate()
			carte.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			grid.add_child(carte)
			carte.set_cliquable(false)
			carte.rendre_visible(true)
			await get_tree().process_frame
			await get_tree().process_frame
			carte.custom_minimum_size = Vector2(largeur_dispo, hauteur_dispo)
			carte.size = Vector2(largeur_dispo, hauteur_dispo)
			carte.remplir_infos(info)
		else:
			var texture_rect = TextureRect.new()
			texture_rect.texture = TEXTURE_INCONNU
			texture_rect.custom_minimum_size = Vector2(largeur_dispo, hauteur_dispo)
			texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
			grid.add_child(texture_rect)

func _on_btn_precedent_pressed():
	if page_courante > 0:
		afficher_page(page_courante - 1)

func _on_btn_suivant_pressed():
	if page_courante < pages.size() - 1:
		afficher_page(page_courante + 1)

func _on_btn_fermer_album_pressed():
	queue_free()
