shader_type canvas_item;

uniform float alpha_show : hint_range(0.5, 1.0, 0.1) = 1.0;
uniform float alpha_hide : hint_range(0.0, 0.5, 0.1) = 0.0;
uniform float strength : hint_range(1.0, 200.0, 0.1) = 200.0;


void fragment() {
	if (COLOR.a > 0.0) {
		float alpha_ratio = (sin(UV.y * strength) + 1.0) * 0.5;
		float alpha_range = alpha_show - alpha_hide;
		COLOR.a = alpha_hide + alpha_range * alpha_ratio;
	}
}
