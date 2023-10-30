#ifndef SPHERICAL_HARMONICS_INCLUDED
#define SPHERICAL_HARMONICS_INCLUDED


// SH Basis coefs
const float kSHBasis0 = 0.28209479177387814347; // {0, 0} : 1/2 * sqrt(1/Pi)
const float kSHBasis1 = 0.48860251190291992159; // {1, 0} : 1/2 * sqrt(3/Pi)
const float kSHBasis2 = 1.09254843059207907054; // {2,-2} : 1/2 * sqrt(15/Pi)
const float kSHBasis3 = 0.31539156525252000603; // {2, 0} : 1/4 * sqrt(5/Pi)
const float kSHBasis4 = 0.54627421529603953527; // {2, 2} : 1/4 * sqrt(15/Pi)
const float kSHBasisCoef[] = { kSHBasis0, -kSHBasis1, kSHBasis1, -kSHBasis1, kSHBasis2, -kSHBasis2, kSHBasis3, -kSHBasis2, kSHBasis4 };

// Clamped cosine convolution coefs (pre-divided by PI)
const float kClampedCosine0 = 1.0;
const float kClampedCosine1 = 2.0 / 3.0;
const float kClampedCosine2 = 1.0 / 4.0;
const float kClampedCosineCoefs[] = { kClampedCosine0, kClampedCosine1, kClampedCosine1, kClampedCosine1, kClampedCosine2, kClampedCosine2, kClampedCosine2, kClampedCosine2, kClampedCosine2 };

vec3 SHEvalLinearL0L1(vec3 N, vec4 shAr, vec4 shAg, vec4 shAb) {
	vec4 vA = vec4(N, 1.0);
	vec3 x1;
	x1.r = dot(shAr, vA);
	x1.g = dot(shAg, vA);
	x1.b = dot(shAb, vA);
	return x1;
}

vec3 SHEvalLinearL2(vec3 N, vec4 shBr, vec4 shBg, vec4 shBb, vec4 shC) {
	vec3 x2;
	vec4 vB = N.xyzz * N.yzzx;
	x2.r = dot(shBr, vB);
	x2.g = dot(shBg, vB);
	x2.b = dot(shBb, vB);
	float vC = N.x * N.x - N.y * N.y;
	vec3 x3 = shC.rgb * vC;
	return x2 + x3;
}

vec3 SampleSH9(vec4 SHCoefficients[7], vec3 N) {
	vec4 shAr = SHCoefficients[0];
	vec4 shAg = SHCoefficients[1];
	vec4 shAb = SHCoefficients[2];
	vec4 shBr = SHCoefficients[3];
	vec4 shBg = SHCoefficients[4];
	vec4 shBb = SHCoefficients[5];
	vec4 shCr = SHCoefficients[6];
	vec3 res = SHEvalLinearL0L1(N, shAr, shAg, shAb);
	res += SHEvalLinearL2(N, shBr, shBg, shBb, shCr);
	return res;
}


vec3 SampleSH4_L1(vec4 SHCoefficients[3], vec3 N) {
	vec4 shAr = SHCoefficients[0];
	vec4 shAg = SHCoefficients[1];
	vec4 shAb = SHCoefficients[2];
	vec3 res = SHEvalLinearL0L1(N, shAr, shAg, shAb); // Removed the .xyz
	return res;
}


void GetCornetteShanksPhaseFunction(out vec3 zh, float anisotropy) {
	float g = anisotropy;
	zh.x = 0.282095;
	zh.y = 0.293162 * g * (4.0 + (g * g)) / (2.0 + (g * g));
	zh.z = (0.126157 + 1.44179 * (g * g) + 0.324403 * (g * g) * (g * g)) / (2.0 + (g * g));
}

void ConvolveZonal(inout float sh[27], vec3 zh) {
	for (int l = 0; l <= 2; l++) {
		float n = sqrt((4.0 * PI) / (2.0 * float(l) + 1.0));
		float k = zh[l];
		float p = n * k;
		for (int m = -l; m <= l; m++) {
			int i = l * (l + 1) + m;
			for (int c = 0; c < 3; c++) {
				sh[c * 9 + i] = sh[c * 9 + i] * p;
			}
		}
	}
}

#endif // SPHERICAL_HARMONICS_INCLUDED
