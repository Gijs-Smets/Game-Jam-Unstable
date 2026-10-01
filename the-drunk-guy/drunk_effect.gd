extends CanvasLayer

# Zat-effect over het hele beeld: golven, RGB-verschuiving en dubbelbeeld.
# Sterkte komt uit Game.drunk_strength (0 = normaal, 1 = helemaal zat).
# Zit op een lagere layer dan de UI, dus score en eindscherm blijven scherp.

const SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float distortion : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Golvend beeld
	float wave_x = sin(uv.y * 18.0 + TIME * 3.0) * 0.012 * distortion;
	float wave_y = sin(uv.x * 14.0 + TIME * 2.0) * 0.010 * distortion;

	// Extra kleine trillingen
	wave_x += sin(uv.y * 45.0 + TIME * 5.0) * 0.004 * distortion;
	wave_y += cos(uv.x * 35.0 + TIME * 4.0) * 0.003 * distortion;

	vec2 warped_uv = uv + vec2(wave_x, wave_y);

	// RGB-verschuiving
	float rgb_offset = 0.008 * distortion;
	float r = texture(screen_texture, warped_uv + vec2(rgb_offset, 0.0)).r;
	float g = texture(screen_texture, warped_uv).g;
	float b = texture(screen_texture, warped_uv - vec2(rgb_offset, 0.0)).b;
	vec3 color = vec3(r, g, b);

	// Dubbelbeeld
	vec2 ghost_offset = vec2(sin(TIME * 1.5) * 0.015, cos(TIME * 1.2) * 0.012) * distortion;
	vec3 ghost = texture(screen_texture, warped_uv + ghost_offset).rgb;
	color = mix(color, ghost, 0.3 * distortion);

	COLOR = vec4(color, 1.0);
}
"""

var shader_mat: ShaderMaterial

func _ready() -> void:
	layer = 5   # onder de UI (layer 10)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = shader_mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	shader_mat.set_shader_parameter("distortion", Game.drunk_strength)
