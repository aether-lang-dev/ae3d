#version 410 core
// taa: written by ae3d.gpu from its quote.

uniform vec2 screen_size;
uniform float blend;
uniform float exposure;
uniform sampler2D screen;
uniform sampler2D velocity;
uniform sampler2D history;

vec3 taa_fold(vec3 c, float exposure) {
    return c / (1.0 + dot(c * exposure, vec3(0.2126, 0.7152, 0.0722)));
}

vec3 taa_unfold(vec3 c, float exposure) {
    return c / max(1.0 - dot(c * exposure, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
}

in vec2 uv;
out vec4 FragColor;

void main() {
    vec2 px = vec2(1.0 / screen_size.x, 1.0 / screen_size.y);
    vec3 current = texture(screen, uv).rgb;
    if (blend >= 0.999) {
        FragColor = vec4(current, 1.0);
        return;
    }
    vec2 prev_uv = uv - texture(velocity, uv).xy;
    if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) {
        FragColor = vec4(current, 1.0);
        return;
    }
    vec3 past = taa_fold(texture(history, prev_uv).rgb, exposure);
    vec3 now = taa_fold(current, exposure);
    vec3 low = now;
    vec3 high = now;
    float y = -1.0;
    while (y <= 1.0) {
        float x = -1.0;
        while (x <= 1.0) {
            if (x != 0.0 || y != 0.0) {
                vec3 c = taa_fold(texture(screen, uv + vec2(x, y) * px).rgb, exposure);
                low = min(low, c);
                high = max(high, c);
            }
            x = x + 1.0;
        }
        y = y + 1.0;
    }
    past = clamp(past, low, high);
    float travel = length((prev_uv - uv) * screen_size);
    float weight = clamp(blend + travel * 0.02, blend, 1.0);
    FragColor = vec4(taa_unfold(mix(past, now, weight), exposure), 1.0);
}
