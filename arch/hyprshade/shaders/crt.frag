#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec2 tc = v_texcoord;

    // Distance from the center
    float dx = abs(0.5-tc.x);
    float dy = abs(0.5-tc.y);

    // Square it to smooth the edges
    dx *= dx;
    dy *= dy;

    tc.x -= 0.5;
    tc.x *= 1.0 + (dy * 0.03);
    tc.x += 0.5;

    tc.y -= 0.5;
    tc.y *= 1.0 + (dx * 0.03);
    tc.y += 0.5;

    // Get texel, and add in scanline if need be
    vec4 cta = texture(tex, tc);

    cta.rgb += sin(tc.y * 1250.0) * 0.02;

    // Cutoff
    if(tc.y > 1.0 || tc.x < 0.0 || tc.x > 1.0 || tc.y < 0.0)
        cta = vec4(0.0);

    // Apply
    fragColor = cta;
}
