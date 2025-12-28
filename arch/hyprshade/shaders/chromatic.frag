#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

#define STRENGTH 0.0027

void main() {
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = (v_texcoord - center) * STRENGTH;

    float rSquared = dot(offset, offset);
    float distortion = 1.0 + 1.0 * rSquared;
    vec2 distortedOffset = offset * distortion;

    vec2 redOffset = distortedOffset;
    vec2 blueOffset = distortedOffset;

    vec4 redColor = texture(tex, v_texcoord + redOffset);
    vec4 blueColor = texture(tex, v_texcoord + blueOffset);

    fragColor = vec4(redColor.r, texture(tex, v_texcoord).g, blueColor.b, 1.0);
}
