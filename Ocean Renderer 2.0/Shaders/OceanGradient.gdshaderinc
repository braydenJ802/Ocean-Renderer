
#ifndef OCEAN_GRADIENT_INCLUDED
#define OCEAN_GRADIENT_INCLUDED

const int GRADIENT_MAX_KEYS = 8;

struct Gradient
{
    vec4 colors[GRADIENT_MAX_KEYS];
    int colorsCount;
    bool type;
};

// Default values for the colors array
// Default values for the colors array
const vec4 DEFAULT_COLORS[GRADIENT_MAX_KEYS] = {vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0)};

Gradient CreateGradient(mat4 colorsMatrix1, mat4 colorsMatrix2, float colorsCount, bool type) {
    Gradient g;
    g.colors[0] = colorsMatrix1[0];
    g.colors[1] = colorsMatrix1[1];
    g.colors[2] = colorsMatrix1[2];
    g.colors[3] = colorsMatrix1[3];
    g.colors[4] = colorsMatrix2[0];
    g.colors[5] = colorsMatrix2[1];
    g.colors[6] = colorsMatrix2[2];
    g.colors[7] = colorsMatrix2[3];
    g.colorsCount = int(colorsCount);
    g.type = type;
    return g;
}

vec3 SampleGradient(Gradient grad, float t)
{
    vec3 color = grad.colors[0].rgb;
    
    for (int i = 1; i < GRADIENT_MAX_KEYS; i++)
    {
        float colorPos = clamp((t - grad.colors[i - 1].w) / (grad.colors[i].w - grad.colors[i - 1].w), 0.0, 1.0) * step(float(i), float(grad.colorsCount - 1));
		color = mix(color, grad.colors[i].rgb, mix(colorPos, step(0.01, colorPos), float(grad.type)));

    }
    return color;
}
#endif