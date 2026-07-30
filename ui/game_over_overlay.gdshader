shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount = 3.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_amount;

	vec4 sum = vec4(0.0);
	sum += texture(screen_texture, SCREEN_UV + vec2(-2.0 * px.x,  0.0)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0, -2.0 * px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(2.0 * px.x, 0.0)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(px.x, px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0, 2.0 * px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)) * 0.12;
	sum += texture(screen_texture, SCREEN_UV) * 0.04;

	COLOR = vec4(sum.rgb, 0.65);
}