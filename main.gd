extends Node2D
# Zat Runner - een dronken jongen rent door een wankele nachtelijke stad.
# Raak iets aan = game over. Score = overleefde tijd. Godot 4.x (GDScript).

const W := 960.0
const H := 540.0
const GROUND_Y := 440.0
const BOY_HOME := 240.0
const GRAVITY := 2200.0
const JUMP_V := 840.0

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 0.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 14.0 + TIME * 2.0) * 0.006 * intensity;
	uv.y += sin(uv.x * 10.0 + TIME * 1.6) * 0.005 * intensity;
	vec2 off = vec2(sin(TIME * 1.3), cos(TIME * 0.9)) * 0.012 * intensity;
	float r = texture(screen_texture, uv + off).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - off).b;
	vec3 col = vec3(r, g, b);
	vec3 ghost = texture(screen_texture, uv + off * 3.0).rgb;
	col = mix(col, ghost, 0.25 * clamp(intensity, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

class Obstacle:
	var kind := 0        # 0 bierkratten, 1 zwarte kat, 2 duif, 3 neonbord
	var base_x := 0.0
	var base_y := 0.0
	var x := 0.0
	var y := 0.0
	var extra := 0.0     # extra snelheid naar de speler toe
	var size := Vector2.ONE
	var phase := 0.0
	var text := ""

var t := 0.0             # overleefde tijd = score
var anim_t := 0.0        # loopt altijd door (wobbel-effecten)
var alive := true
var dead_timer := 0.0
var dead_vy := 0.0

var boy_x := BOY_HOME
var boy_y := GROUND_Y
var boy_vx := 0.0
var boy_vy := 0.0
var on_ground := true
var jump_buffer := 0.0
var pending_jump := 0.0

var scroll := 0.0
var speed := 380.0
var last_arrival := 1.5
var stumble_in := 3.0
var best := 0.0
var obstacles: Array = []

var camera: Camera2D
var shader_mat: ShaderMaterial
var time_label: Label
var best_label: Label
var msg_label: Label
var flash: ColorRect
var flash_a := 0.0


func _ready() -> void:
	randomize()
	best = load_best()

	camera = Camera2D.new()
	camera.position = Vector2(W / 2, H / 2)
	add_child(camera)
	camera.make_current()

	# Scherm-effect: golvend beeld met dubbel zicht
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 10
	add_child(fx_layer)
	var fx_rect := ColorRect.new()
	fx_rect.size = Vector2(W, H)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_CODE
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = sh
	fx_rect.material = shader_mat
	fx_layer.add_child(fx_rect)

	# HUD (niet vervormd)
	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)

	flash = ColorRect.new()
	flash.size = Vector2(W, H)
	flash.color = Color(1, 0, 0, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)

	time_label = make_label(32)
	time_label.position = Vector2(16, 10)
	time_label.text = "0.00 s"
	hud.add_child(time_label)

	best_label = make_label(24)
	best_label.position = Vector2(0, 14)
	best_label.size = Vector2(W - 16, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.text = "Record: %.2f s" % best
	hud.add_child(best_label)

	msg_label = make_label(30)
	msg_label.position = Vector2(0, 110)
	msg_label.size = Vector2(W, 320)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.text = "Je bent zat.\nSPATIE / ↑ = springen\n← → = bijsturen\nRaak NIETS aan!"
	hud.add_child(msg_label)


func make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _process(delta: float) -> void:
	anim_t += delta
	if alive:
		update_game(delta)
	else:
		dead_timer += delta
		# jongen hupt omhoog en valt uit beeld
		dead_vy += 1800.0 * delta
		boy_y += dead_vy * delta
		flash_a = maxf(0.0, flash_a - delta * 1.5)
		flash.color.a = flash_a * 0.5
		if dead_timer > 0.6 and Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()
	update_camera()
	queue_redraw()


func update_game(delta: float) -> void:
	t += delta
	var chaos := clampf(t / 40.0, 0.0, 1.0)   # 0 -> 1 na 40 seconden
	speed = minf(380.0 + t * 7.0, 760.0)
	scroll += speed * delta

	if t > 3.5 and msg_label.text.begins_with("Je bent"):
		msg_label.text = ""

	# --- Zwabberen: de jongen drijft heen en weer, jij stuurt bij ---
	var input := Input.get_axis("ui_left", "ui_right")
	var sway := sin(t * 1.7) * 0.6 + sin(t * 0.9 + 2.0) * 0.8 + sin(t * 3.3) * 0.3
	var drunk := sway * (60.0 + 90.0 * chaos)
	var target := input * 260.0 + drunk + (BOY_HOME - boy_x) * 0.9
	boy_vx = lerpf(boy_vx, target, 1.0 - exp(-3.0 * delta))

	stumble_in -= delta
	if stumble_in <= 0.0:
		boy_vx += randf_range(-1.0, 1.0) * (220.0 + 120.0 * chaos)
		stumble_in = randf_range(2.5, 5.0)
	boy_x = clampf(boy_x + boy_vx * delta, 30.0, 700.0)

	# --- Springen (dronken: wisselende hoogte en soms vertraagd) ---
	jump_buffer -= delta
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		jump_buffer = 0.12
	if on_ground and jump_buffer > 0.0 and pending_jump <= 0.0:
		jump_buffer = 0.0
		if randf() < 0.25 * chaos:
			pending_jump = 0.14
		else:
			start_jump()
	if pending_jump > 0.0:
		pending_jump -= delta
		if pending_jump <= 0.0 and on_ground:
			start_jump()
	if (Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")) and boy_vy < -300.0:
		boy_vy *= 0.5   # korter indrukken = lager springen

	boy_vy += GRAVITY * delta
	boy_y += boy_vy * delta
	if boy_y >= GROUND_Y:
		boy_y = GROUND_Y
		boy_vy = 0.0
		on_ground = true
	else:
		on_ground = false

	# --- Obstakels ---
	if last_arrival - t < 1.2:
		spawn_obstacle(chaos)

	for o: Obstacle in obstacles:
		o.base_x -= (speed + o.extra) * delta
		o.x = o.base_x
		match o.kind:
			0:
				o.x += sin(t * 1.8 + o.phase) * (5.0 + 18.0 * chaos)
			1:
				o.y = GROUND_Y - o.size.y / 2.0 - absf(sin(t * 6.0 + o.phase)) * (6.0 + 12.0 * chaos)
			2:
				o.y = minf(o.base_y + sin(t * 4.0 + o.phase) * (8.0 + 16.0 * chaos), GROUND_Y - 18.0)
			3:
				o.y = o.base_y + sin(t * 2.4 + o.phase) * (8.0 + 14.0 * chaos)
		if hits(o):
			die()
			break
	obstacles = obstacles.filter(func(o): return o.base_x > -140.0)

	time_label.text = "%.2f s" % t


func start_jump() -> void:
	boy_vy = -JUMP_V * randf_range(0.93, 1.06)
	on_ground = false


func spawn_obstacle(chaos: float) -> void:
	var o := Obstacle.new()
	var r := randi() % 10
	if r < 4:
		o.kind = 0
	elif r < 7:
		o.kind = 1
	elif r < 9:
		o.kind = 2
	else:
		o.kind = 3
	o.phase = randf() * TAU
	match o.kind:
		0:
			var h := randi_range(2, 3) * 35.0
			o.size = Vector2(56, h)
			o.y = GROUND_Y - h / 2.0
		1:
			o.size = Vector2(44, 30)
			o.y = GROUND_Y - 15.0
			o.extra = 90.0
		2:
			o.size = Vector2(50, 28)
			o.base_y = GROUND_Y - randf_range(30.0, 44.0)
			o.y = o.base_y
			o.extra = 260.0
		3:
			var texts: Array[String] = ["BAR", "OPEN", "24/7", "SHOTS"]
			o.text = texts[randi() % texts.size()]
			o.size = Vector2(74, 34)
			o.base_y = GROUND_Y - 105.0
			o.y = o.base_y
	# Zorg dat de tijd tussen obstakels eerlijk blijft, ook bij snellere types
	var v := speed + o.extra
	var gap := randf_range(1.05, 1.7) - 0.2 * chaos
	var arrival := maxf(last_arrival + gap, t + (W + 80.0 - BOY_HOME) / v)
	o.base_x = BOY_HOME + (arrival - t) * v
	o.x = o.base_x
	last_arrival = arrival
	obstacles.append(o)


func hits(o: Obstacle) -> bool:
	var r := Rect2(o.x - o.size.x / 2 + 4, o.y - o.size.y / 2 + 4, o.size.x - 8, o.size.y - 8)
	var b := Rect2(boy_x - 11, boy_y - 50, 22, 48)
	return r.intersects(b)


func die() -> void:
	if not alive:
		return
	alive = false
	dead_vy = -650.0
	flash_a = 1.0
	var extra := ""
	if t > best:
		best = t
		save_best()
		extra = "  NIEUW RECORD!"
	msg_label.text = "GAME OVER\n\nTijd: %.2f s\nRecord: %.2f s%s\n\nSPATIE = opnieuw" % [t, best, extra]


func update_camera() -> void:
	var chaos := clampf(t / 40.0, 0.0, 1.0)
	var k := 0.3 + chaos * 1.0
	if not alive:
		k *= 0.3
	camera.rotation = (sin(anim_t * 0.8) * 0.04 + sin(anim_t * 2.1) * 0.015) * k
	var z := 1.0 + (sin(anim_t * 1.3) * 0.03 + 0.03) * k
	camera.zoom = Vector2(z, z)
	camera.position = Vector2(W / 2, H / 2) + Vector2(sin(anim_t * 1.1) * 14.0, cos(anim_t * 0.7) * 10.0) * k
	shader_mat.set_shader_parameter("intensity", 0.4 + chaos * 1.6)


# ---------------------------------------------------------------- tekenen

func hash01(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


func _draw() -> void:
	var chaos := clampf(t / 40.0, 0.0, 1.0)
	draw_background(chaos)
	draw_ground()
	for o: Obstacle in obstacles:
		draw_obstacle(o)
	draw_boy(chaos)


func draw_background(chaos: float) -> void:
	# nachtlucht, kleurt steeds vreemder
	var top_c := Color.from_hsv(fposmod(0.68 + chaos * 0.12 * sin(anim_t * 0.5), 1.0), 0.8, 0.16)
	var bot_c := Color.from_hsv(fposmod(0.82 + chaos * 0.10 * sin(anim_t * 0.4 + 1.0), 1.0), 0.6, 0.5)
	draw_rect(Rect2(-600, -600, W + 1200, 600), top_c)
	var steps := 14
	for i in range(steps):
		var y0 := GROUND_Y * i / steps
		draw_rect(Rect2(-600, y0, W + 1200, GROUND_Y / steps + 1.0), top_c.lerp(bot_c, float(i) / (steps - 1)))
	draw_rect(Rect2(-600, GROUND_Y, W + 1200, 700), bot_c)

	# sterren
	for i in range(45):
		var sx := fposmod(hash01(i) * 1300.0 - scroll * 0.02, 1300.0) - 170.0
		var sy := hash01(i + 100) * 300.0
		var a := 0.5 + 0.5 * sin(anim_t * 2.0 + float(i))
		draw_rect(Rect2(sx, sy, 2, 2), Color(1, 1, 1, 0.3 + 0.5 * a))

	# maan, met een spookmaan als je zat genoeg bent
	var mp := Vector2(780, 95)
	draw_circle(mp + Vector2(sin(anim_t * 0.7), cos(anim_t * 0.9)) * 34.0 * chaos, 40.0, Color(0.95, 0.93, 0.8, 0.25 * chaos))
	draw_circle(mp, 40.0, Color("#f1ecc8"))
	draw_circle(mp + Vector2(-12, -8), 7.0, Color("#d8d2a8"))
	draw_circle(mp + Vector2(10, 12), 9.0, Color("#d8d2a8"))
	draw_circle(mp + Vector2(14, -14), 4.0, Color("#d8d2a8"))

	# skyline in twee lagen
	draw_buildings(0.12, 120.0, Color("#17122d"), 120.0, 170.0, 0, false)
	draw_buildings(0.30, 210.0, Color("#241a42"), 130.0, 150.0, 500, true)


func draw_buildings(par: float, tile: float, col: Color, min_h: float, var_h: float, seed_off: int, windows: bool) -> void:
	var s := scroll * par
	var c := int(s / tile)
	for i in range(-1, int(W / tile) + 3):
		var idx := i + c
		var hh := hash01(idx + seed_off)
		var h := min_h + hh * var_h
		var x := i * tile - fmod(s, tile)
		var w := tile - 6.0
		var top := GROUND_Y - h
		draw_rect(Rect2(x, top, w, h + 40.0), col)
		if not windows:
			continue
		var cols := int(w / 30.0)
		var rows := int((h - 30.0) / 34.0)
		for r in range(rows):
			for k in range(cols):
				var hv := hash01(idx * 31 + r * 7 + k + seed_off)
				if hv > 0.55:
					if hv > 0.93 and sin(anim_t * 9.0 + hv * 50.0) > 0.0:
						continue   # kapotte lamp flikkert
					draw_rect(Rect2(x + 12 + k * 30.0, top + 24 + r * 34.0, 14, 18), Color(1.0, 0.85, 0.45, 0.85))
		if hh > 0.55:   # neonstrip op de gevel
			var nc := Color.from_hsv(hash01(idx + 77), 0.8, 1.0)
			var pulse := 0.6 + 0.4 * sin(anim_t * 3.0 + hh * 20.0)
			draw_rect(Rect2(x + 14, top + 6, w - 28, 12), Color(nc, 0.25 * pulse))
			draw_rect(Rect2(x + 18, top + 10, w - 36, 4), Color(nc, pulse))


func draw_ground() -> void:
	# stoep
	draw_rect(Rect2(-600, GROUND_Y, W + 1200, 16), Color("#8d8aa0"))
	draw_rect(Rect2(-600, GROUND_Y, W + 1200, 3), Color("#b9b6cc"))
	var off := fmod(scroll, 64.0)
	for i in range(-10, 26):
		var x := i * 64.0 - off
		draw_line(Vector2(x, GROUND_Y + 3), Vector2(x, GROUND_Y + 16), Color("#5f5c75"), 2.0)
	# asfalt met doorgetrokken lijn
	draw_rect(Rect2(-600, GROUND_Y + 16, W + 1200, 400), Color("#23232e"))
	draw_rect(Rect2(-600, GROUND_Y + 16, W + 1200, 3), Color("#14141c"))
	var doff := fmod(scroll, 90.0)
	for i in range(-2, 14):
		draw_rect(Rect2(i * 90.0 - doff, GROUND_Y + 62, 50, 5), Color("#d8b630"))


func draw_obstacle(o: Obstacle) -> void:
	var p := Vector2(o.x, o.y)
	match o.kind:
		0:  # stapel bierkratten
			var n := int(round(o.size.y / 35.0))
			var bottom := p.y + o.size.y / 2.0
			for i in range(n):
				var cx := p.x + sin(t * 2.0 + o.phase + i) * 3.0 * i
				var cy := bottom - 35.0 * (i + 1)
				var rc := Rect2(cx - 28, cy, 56, 35)
				draw_rect(rc, Color("#d08a2e"))
				draw_rect(Rect2(cx - 28, cy + 12, 56, 4), Color("#a8681a"))
				draw_rect(Rect2(cx - 28, cy + 24, 56, 4), Color("#a8681a"))
				draw_rect(rc, Color("#5a3410"), false, 3.0)
			var topc := bottom - 35.0 * n
			for k in range(4):
				draw_rect(Rect2(p.x - 23 + k * 14.0, topc - 10, 5, 10), Color("#3f7a3a"))
				draw_rect(Rect2(p.x - 24 + k * 14.0, topc - 12, 7, 3), Color("#e0b030"))
		1:  # zwarte kat die op je afrent
			var fur := Color("#22222c")
			var run := scroll * 0.12 + o.phase
			for i in range(4):
				var lx := p.x - 14.0 + i * 9.0
				var lo := sin(run + i * 1.6) * 4.0
				draw_rect(Rect2(lx - 2 + lo, p.y + 6, 4, 9), fur)
			draw_rect(Rect2(p.x - 14, p.y - 8, 30, 16), fur)
			draw_circle(p + Vector2(16, 0), 8.0, fur)
			draw_circle(p + Vector2(-18, -6), 9.0, fur)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-25, -12), p + Vector2(-21, -24), p + Vector2(-15, -14)]), fur)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -14), p + Vector2(-12, -24), p + Vector2(-10, -12)]), fur)
			draw_polyline(PackedVector2Array([p + Vector2(20, -4), p + Vector2(28, -14 + sin(anim_t * 8.0) * 3.0), p + Vector2(30, -28 + sin(anim_t * 6.0) * 5.0)]), fur, 4.0)
			draw_circle(p + Vector2(-23, -8), 2.5, Color("#ffe14a"))
			draw_circle(p + Vector2(-15, -8), 2.5, Color("#ffe14a"))
		2:  # duif die laag scheert
			var f := sin(anim_t * 18.0 + o.phase)
			draw_colored_polygon(PackedVector2Array([p + Vector2(10, 0), p + Vector2(25, -3), p + Vector2(25, 5)]), Color("#6e7488"))
			draw_circle(p, 13.0, Color("#9aa0b0"))
			draw_circle(p + Vector2(-14, -6), 7.0, Color("#7e8498"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-20, -7), p + Vector2(-27, -4), p + Vector2(-20, -2)]), Color("#e0a030"))
			draw_circle(p + Vector2(-15, -8), 1.8, Color.BLACK)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(14, -4), p + Vector2(8, -4 - f * 24.0)]), Color("#7e8498"))
		3:  # neonbord aan kettingen
			var neon := Color.from_hsv(fposmod(o.phase / TAU, 1.0), 0.7, 1.0)
			var pulse := 0.7 + 0.3 * sin(anim_t * 9.0 + o.phase)
			draw_line(p + Vector2(-26, -17), p + Vector2(-26, -700), Color("#555566"), 2.0)
			draw_line(p + Vector2(26, -17), p + Vector2(26, -700), Color("#555566"), 2.0)
			var rc := Rect2(p.x - 37, p.y - 17, 74, 34)
			draw_rect(rc.grow(7.0), Color(neon, 0.15 * pulse))
			draw_rect(rc, Color("#14141f"))
			draw_rect(rc, Color(neon, pulse), false, 3.0)
			draw_string(ThemeDB.fallback_font, Vector2(p.x - 37, p.y + 7), o.text, HORIZONTAL_ALIGNMENT_CENTER, 74, 20, Color(neon, pulse))


func draw_boy(chaos: float) -> void:
	var skin := Color("#f0c8a0")
	var hoodie := Color("#2aa6a0")
	var hoodie_d := Color("#1d7c78")
	var jeans := Color("#3a5f9a")
	var run := sin(scroll * 0.045)
	var rot := clampf(boy_vx / 500.0, -0.3, 0.3) + sin(anim_t * 5.0) * 0.05
	if not on_ground:
		run = 0.0
	if not alive:
		rot = anim_t * 6.0
		run = 0.0
	else:
		draw_set_transform(Vector2(boy_x, GROUND_Y + 4.0), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))

	draw_set_transform(Vector2(boy_x, boy_y - 29.0), rot, Vector2.ONE)
	# benen + sneakers
	draw_rect(Rect2(-9 - run * 6, 14, 8, 14), jeans)
	draw_rect(Rect2(-11 - run * 6, 26, 13, 5), Color.WHITE)
	draw_rect(Rect2(-11 - run * 6, 28, 13, 2), Color("#d8302f"))
	draw_rect(Rect2(1 + run * 6, 14, 8, 14), jeans)
	draw_rect(Rect2(0 + run * 6, 26, 13, 5), Color.WHITE)
	draw_rect(Rect2(0 + run * 6, 28, 13, 2), Color("#d8302f"))
	# achterste arm + capuchon
	draw_rect(Rect2(-14, -3 + run * 3, 5, 11), hoodie_d)
	draw_rect(Rect2(-14, -10, 7, 10), hoodie_d)
	# hoodie
	draw_rect(Rect2(-10, -7, 20, 20), hoodie)
	draw_rect(Rect2(-6, 4, 12, 3), hoodie_d)
	# voorste arm + biertje
	draw_rect(Rect2(5, -3, 11, 6), hoodie)
	draw_rect(Rect2(14, -4, 5, 6), skin)
	draw_rect(Rect2(14, -18, 6, 18), Color("#b8741a"))
	draw_rect(Rect2(15.5, -25, 3, 8), Color("#b8741a"))
	draw_rect(Rect2(15, -26, 4, 2), Color("#e0b030"))
	# hoofd
	draw_rect(Rect2(-8, -25, 17, 18), skin)
	draw_rect(Rect2(-10, -29, 19, 8), Color("#3a2412"))
	draw_rect(Rect2(-10, -25, 5, 12), Color("#3a2412"))
	draw_rect(Rect2(-7, -33, 4, 5), Color("#3a2412"))
	draw_rect(Rect2(1, -32, 4, 4), Color("#3a2412"))
	draw_circle(Vector2(4, -17), 3.6, Color.WHITE)
	draw_circle(Vector2(4 + sin(anim_t * 3.0) * 1.6, -17 + cos(anim_t * 2.3) * 1.3), 1.7, Color.BLACK)
	draw_rect(Rect2(3, -12, 6, 3), Color("#f08a8a"))
	draw_rect(Rect2(3, -8, 5, 2), Color("#7a3a2a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# duizelige sterretjes boven zijn hoofd
	var st := maxf(chaos, 0.25) if alive else 1.0
	for i in range(3):
		var a := anim_t * 5.0 + i * 2.094
		var sp := Vector2(boy_x + cos(a) * 16.0, boy_y - 70.0 + sin(a) * 4.0)
		draw_circle(sp, 1.5 + 2.0 * st, Color(1.0, 0.9, 0.3, 0.9))


# ---------------------------------------------------------------- opslaan

func load_best() -> float:
	if FileAccess.file_exists("user://best.save"):
		var f := FileAccess.open("user://best.save", FileAccess.READ)
		return f.get_float()
	return 0.0


func save_best() -> void:
	var f := FileAccess.open("user://best.save", FileAccess.WRITE)
	f.store_float(best)
