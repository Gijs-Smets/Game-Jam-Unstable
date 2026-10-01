extends CanvasLayer

# Score tijdens het spelen + eindscherm. Alles wordt in code opgebouwd,
# dus je hoeft in de editor verder niets in te stellen.

var score_label: Label
var overlay: Control
var final_score_label: Label
var prompt_label: Label

func _ready() -> void:
	layer = 10   # altijd boven de rest, onafhankelijk van de zatte camera
	_build_hud()
	_build_game_over()

	Game.score_changed.connect(_on_score_changed)
	Game.game_ended.connect(_on_game_ended)
	_on_score_changed(Game.score)

# ---------- Opbouw ----------

func _make_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(4, int(size / 6.0)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _build_hud() -> void:
	score_label = _make_label("Score: 0", 40)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.position = Vector2(28, 16)
	add_child(score_label)

func _build_game_over() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)

	# Donkere sluier over het beeld
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	box.add_child(_make_label("GAME OVER", 84, Color("#FF5A5F")))
	final_score_label = _make_label("Score: 0", 48)
	box.add_child(final_score_label)

	prompt_label = _make_label("Druk op SPATIE om opnieuw te spelen", 30, Color("#FFD166"))
	prompt_label.visible = false
	box.add_child(prompt_label)

# ---------- Reacties ----------

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_game_ended() -> void:
	score_label.hide()
	final_score_label.text = "Score: %d" % Game.score
	overlay.show()

	# Pas na een korte pauze laten zien dat je kunt herstarten,
	# zodat je niet per ongeluk wegspringt uit het eindscherm.
	await get_tree().create_timer(Game.RESTART_DELAY).timeout
	prompt_label.show()
	var tween := create_tween().set_loops()
	tween.tween_property(prompt_label, "modulate:a", 0.25, 0.6)
	tween.tween_property(prompt_label, "modulate:a", 1.0, 0.6)
