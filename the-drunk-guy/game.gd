extends Node

signal game_started
signal game_ended
signal score_changed(new_score)

const DRUNK_MAX_SCORE := 15      # bij zoveel obstakels is hij volledig zat (test: 5)
const DRUNK_GROW_SPEED := 0.4    # hoe snel het effect naar het nieuwe niveau groeit
const MAX_SPEED_BONUS := 0.5      # bij volledig zat loopt hij 50% sneller (0.5 = +50%)
const RESTART_DELAY := 0.6       # seconden na game over voordat je kunt herstarten

var running := false
var score := 0
var time := 0.0                  # alleen nog als "klok" voor de sinusbewegingen
var drunk_strength := 0.0
var speed_factor := 1.0          # 1.0 = normale snelheid, groeit mee met de dronkenheid
var ended_at := 0.0              # tijdstip (s) van de laatste game over

func _ready() -> void:
	start_game()

func start_game() -> void:
	score = 0
	time = 0.0
	drunk_strength = 0.0
	speed_factor = 1.0
	running = true
	game_started.emit()

func _process(delta: float) -> void:
	if not running:
		return
	time += delta
	# Doel hangt af van de score, en schuift er soepel naartoe
	var target: float = clampf(float(score) / DRUNK_MAX_SCORE, 0.0, 1.0)
	drunk_strength = move_toward(drunk_strength, target, DRUNK_GROW_SPEED * delta)
	# Snelheid volgt dezelfde zachte fade als het zat-effect
	speed_factor = 1.0 + MAX_SPEED_BONUS * drunk_strength

func add_score(amount: int = 1) -> void:
	if not running:
		return
	score += amount
	score_changed.emit(score)
	print("Score: ", score, " | dronkenheid-doel: ", snappedf(clampf(float(score) / DRUNK_MAX_SCORE, 0.0, 1.0), 0.01))

func end_game() -> void:
	if not running:
		return
	running = false
	ended_at = Time.get_ticks_msec() / 1000.0
	game_ended.emit()
	print("GAME OVER - score: ", score)

func restart() -> void:
	get_tree().reload_current_scene()
	start_game()

func _unhandled_input(event: InputEvent) -> void:
	if running or not event.is_action_pressed("ui_accept"):
		return
	if Time.get_ticks_msec() / 1000.0 - ended_at >= RESTART_DELAY:
		restart()
