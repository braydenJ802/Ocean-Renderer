#ifndef MATH_EXTENSIONS_INCLUDED
#define MATH_EXTENSIONS_INCLUDED

const float INV_PI = 0.31830988618;
const float FLT_MIN = 1e-6;

float sq(float x) {
    return x * x;
}

float dotsq(vec3 y) {
	return dot(y,y);
}

vec2 v2sq(vec2 x) {
	return vec2(sq(x[0]),sq(x[1]));
}

vec3 v3sq(vec3 x) {
	return vec3(sq(x[0]),sq(x[1]),sq(x[2]));
}

float SafeDiv(float numerator, float denominator) {
    if (abs(denominator) < 0.00001) {
        return 0.0;
    }
    return numerator / denominator;
}
#endif