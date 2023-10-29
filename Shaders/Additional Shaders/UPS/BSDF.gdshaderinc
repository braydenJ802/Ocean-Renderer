#ifndef UNITY_BSDF_INCLUDED
#define UNITY_BSDF_INCLUDED

#include "res://Shaders/Additional Shaders/MathExtensions.gdshaderinc"

// Note: All NDF and diffuse term have a version with and without divide by PI.
// Version with divide by PI are use for direct lighting.
// Version without divide by PI are use for image based lighting where often the PI cancel during importance sampling

//-----------------------------------------------------------------------------
// Help for BSDF evaluation
//-----------------------------------------------------------------------------

// Cosine-weighted BSDF (a BSDF taking the projected solid angle into account).
// If some of the values are monochromatic, the compiler will optimize accordingly.
struct CBSDF
{
	vec3 diffR; // Diffuse  reflection   (T -> MS -> T, same sides)
	vec3 specR; // Specular reflection   (R, RR, TRT, etc)
	vec3 diffT; // Diffuse  transmission (rough T or TT, opposite sides)
	vec3 specT; // Specular transmission (T, TT, TRRT, etc)
};

//-----------------------------------------------------------------------------
// Fresnel term
//-----------------------------------------------------------------------------


const mat3 XYZ_2_REC709_MAT = mat3(
    vec3(3.2404542, -1.5371385, -0.4985314),
    vec3(-0.9692660, 1.8760108, 0.0415560),
    vec3(0.0556434, -0.2040259, 1.0572252)
);

float F_Schlick_f2(float f0, float f90, float u)
{
    float x = 1.0 - u;
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return (f90 - f0) * x5 + f0;
}

float F_Schlick_f1(float f0, float u)
{
    return F_Schlick_f2(f0, 1.0, u);
}

vec3 F_Schlick_v3f2(vec3 f0, float f90, float u)
{
    float x = 1.0 - u;
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return f0 * (1.0 - x5) + (f90 * x5);
}

vec3 F_Schlick_v3f1(vec3 f0, float u)
{
    return F_Schlick_v3f2(f0, 1.0, u);
}

// Does not handle TIR.
float F_Transm_Schlick_f2(float f0, float f90, float u)
{
    float x = 1.0 - u;
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return (1.0 - f90 * x5) - f0 * (1.0 - x5);
}

float F_Transm_Schlick_f1(float f0, float u)
{
    return F_Transm_Schlick_f2(f0, 1.0, u);
}

vec3 F_Transm_Schlick_v3f2(vec3 f0, float f90, float u)
{
    float x = 1.0 - u;
    float x2 = x * x;
    float x5 = x * x2 * x2;
    return (1.0 - f90 * x5) - f0 * (1.0 - x5);
}

vec3 F_Transm_Schlick_v3f1(vec3 f0, float u)
{
    return F_Transm_Schlick_v3f2(f0, 1.0, u);
}


// Compute the cos of critical angle: cos(asin(eta)) == sqrt(1.0 - eta*eta)
// eta == IORMedium/IORSource
// If eta >= 1 the it's an AirMedium interation, otherwise it's MediumAir interation
float CosCriticalAngle(float eta)
{
	return sqrt(max(1.0 - sq(eta), 0.0));
	// For 1 <= IOR <= 4: Max error: 0.0268594
	//return eta >= 1.0 ? 0.0 : (((3.0 + eta) * sqrt(max(0.0, 1.0 - eta))) / (2.0 * sqrt(2.0)));
	// For 1 <= IOR <= 4: Max error: 0.00533065
	//return eta >= 1.0 ? 0.0 : (-((-23.0 - 10.0 * eta + Sq(eta)) * sqrt(max(0.0, 1.0 - eta))) / (16.0 * sqrt(2.0)));
	// For 1 <= IOR <= 4: Max error: 0.00129402
	//return eta >= 1.0 ? 0.0 : (((91.0 + 43.0 * eta - 7.0 * Sq(eta) + pow(eta, 3)) * sqrt(max(0.0, 1.0 - eta))) / (64. * sqrt(2.0)));
}

// Ref: https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
// Fresnel dielectric / dielectric
float F_FresnelDielectric(float ior, float u)
{
	float g = sqrt(ior * ior + u * u - 1.0);

	// The "1.0 - saturate(1.0 - result)" formulation allows to recover form cases where g is undefined, for IORs < 1
	return 1.0 - clamp(1.0 - 0.5 * sq((g - u) / (g + u)) * (1.0 + sq( ((g + u) * u - 1.0) / ((g - u) * u + 1.0) ) ), 0.0, 1.0);
}

// Fresnel dieletric / conductor
// Note: etak2 = etak * etak (optimization for Artist Friendly Metallic Fresnel below)
// eta = eta_t / eta_i and etak = k_t / n_i
vec3 F_FresnelConductor(vec3 eta, vec3 etak2, float cosTheta)
{
	float cosTheta2 = cosTheta * cosTheta;
	float sinTheta2 = 1.0 - cosTheta2;
	vec3 eta2 = eta * eta;

	vec3 t0 = eta2 - etak2 - sinTheta2;
	vec3 a2plusb2 = sqrt(t0 * t0 + 4.0 * eta2 * etak2);
	vec3 t1 = a2plusb2 + cosTheta2;
	vec3 a = sqrt(0.5 * (a2plusb2 + t0));
	vec3 t2 = 2.0 * a * cosTheta;
	vec3 Rs = (t1 - t2) / (t1 + t2);

	vec3 t3 = cosTheta2 * a2plusb2 + sinTheta2 * sinTheta2;
	vec3 t4 = t2 * sinTheta2;
	vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

	return 0.5 * (Rp + Rs);
}

// Conversion FO/IOR

float IorToFresnel0(float transmittedIor, float incidentIor) {
    float ratio = (transmittedIor - incidentIor) / (transmittedIor + incidentIor);
    return ratio * ratio;
}

float IorToFresnel0_AirInterface(float transmittedIor) {
    return IorToFresnel0(transmittedIor, 1.0);
}


// Assume air interface for top
// Note: We don't handle the case fresnel0 == 1
//float Fresnel0ToIor(float fresnel0)
//{
//    float sqrtF0 = sqrt(fresnel0);
//    return (1.0 + sqrtF0) / (1.0 - sqrtF0);
//}
float Fresnel0ToIor(float fresnel0) {
    return (1.0 + sqrt(fresnel0)) / (1.0 - sqrt(fresnel0));
}

// This function is a coarse approximation of computing fresnel0 for a different top than air (here clear coat of IOR 1.5) when we only have fresnel0 with air interface
// This function is equivalent to IorToFresnel0(Fresnel0ToIor(fresnel0), 1.5)
// mean
// float sqrtF0 = sqrt(fresnel0);
// return Sq(1.0 - 5.0 * sqrtF0) / Sq(5.0 - sqrtF0);
// Optimization: Fit of the function (3 mad) for range [0.04 (should return 0), 1 (should return 1)]
float ConvertF0ForAirInterfaceToF0ForClearCoat15(float fresnel0) {
    return clamp(-0.0256868 + fresnel0 * (0.326846 + (0.978946 - 0.283835 * fresnel0) * fresnel0), 0.0, 1.0);
}

// Even coarser approximation of ConvertF0ForAirInterfaceToF0ForClearCoat15 (above) for mobile (2 mad)
float ConvertF0ForAirInterfaceToF0ForClearCoat15Fast(float fresnel0) {
    return clamp(fresnel0 * (fresnel0 * 0.526868 + 0.529324) - 0.0482256, 0.0, 1.0);
}

// Artist Friendly Metallic Fresnel Ref: http://jcgt.org/published/0003/04/03/paper.pdf

vec3 getIorN(vec3 f0, vec3 edgeTint)
{
	vec3 sqrtF0 = sqrt(f0);
	return mix((1.0 - f0) / (1.0 + f0), (1.0 + sqrtF0) / (1.0 - sqrt(f0)), edgeTint);
}

vec3 getIorK2(vec3 f0, vec3 n)
{
	vec3 nf0 = v3sq(n + vec3(1.0)) * f0 - v3sq(f0 - vec3(1.0));
	return nf0 / (1.0 - f0);
}

// same as regular refract except there is not the test for total internal reflection + the vector is flipped for processing
vec3 CoatRefract(vec3 X, vec3 N, float ieta)
{
	float XdotN = clamp(dot(N, X), 0.0, 1.0);
	return ieta * X + (sqrt(1.0 + ieta * ieta * (XdotN * XdotN - 1.0)) - ieta * XdotN) * N;
}

//-----------------------------------------------------------------------------
// Specular BRDF
//-----------------------------------------------------------------------------

float Lambda_GGX(float roughness, vec3 V)
{
	return 0.5 * (sqrt(1.0 + (sq(roughness * V.x) + sq(roughness * V.y)) / sq(V.z)) - 1.0);
}

float D_GGXNoPI(float NdotH, float roughness)
{
	float a2 = sq(roughness);
	float s = (NdotH * a2 - NdotH) * NdotH + 1.0;

	// If roughness is 0, returns (NdotH == 1 ? 1 : 0).
	// That is, it returns 1 for perfect mirror reflection, and 0 otherwise.
	return SafeDiv(a2, s * s);
}

float D_GGX(float NdotH, float roughness)
{
	return INV_PI * D_GGXNoPI(NdotH, roughness);
}

// Ref: Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs, p. 19, 29.
// p. 84 (37/60)
float G_MaskingSmithGGX(float NdotV, float roughness)
{
	// G1(V, H)    = HeavisideStep(VdotH) / (1 + Lambda(V)).
	// Lambda(V)        = -0.5 + 0.5 * sqrt(1 + 1 / a^2).
	// a           = 1 / (roughness * tan(theta)).
	// 1 + Lambda(V)    = 0.5 + 0.5 * sqrt(1 + roughness^2 * tan^2(theta)).
	// tan^2(theta) = (1 - cos^2(theta)) / cos^2(theta) = 1 / cos^2(theta) - 1.
	// Assume that (VdotH > 0), e.i. (acos(LdotV) < Pi).

	return 1.0 / (0.5 + 0.5 * sqrt(1.0 + sq(roughness) * (1.0 / sq(NdotV) - 1.0)));
}

// Precompute part of lambdaV
float GetSmithJointGGXPartLambdaV(float NdotV, float roughness)
{
	float a2 = sq(roughness);
	return sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
}

// Note: V = G / (4 * NdotL * NdotV)
// Ref: http://jcgt.org/published/0003/02/03/paper.pdf
float V_SmithJointGGX_WithPartLambda(float NdotL, float NdotV, float roughness, float partLambdaV)
{
	float a2 = sq(roughness);

	// Original formulation:
	// lambda_v = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5
	// lambda_l = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5
	// G        = 1 / (1 + lambda_v + lambda_l);

	// Reorder code to be more optimal:
	float lambdaV = NdotL * partLambdaV;
	float lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

	// Simplify visibility term: (2.0 * NdotL * NdotV) /  ((4.0 * NdotL * NdotV) * (lambda_v + lambda_l))
	return 0.5 / max(lambdaV + lambdaL, FLT_MIN);
}

float V_SmithJointGGX(float NdotL, float NdotV, float roughness)
{
	float partLambdaV = GetSmithJointGGXPartLambdaV(NdotV, roughness);
	return V_SmithJointGGX_WithPartLambda(NdotL, NdotV, roughness, partLambdaV);
}

// Inline D_GGX() * V_SmithJointGGX() together for better code generation.
float DV_SmithJointGGX_WithPartLambda(float NdotH, float NdotL, float NdotV, float roughness, float partLambdaV)
{
	float a2 = sq(roughness);
	float s = (NdotH * a2 - NdotH) * NdotH + 1.0;

	float lambdaV = NdotL * partLambdaV;
	float lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

	vec2 D = vec2(a2, s * s);            // Fraction without the multiplier (1/Pi)
	vec2 G = vec2(1, lambdaV + lambdaL); // Fraction without the multiplier (1/2)

	// This function is only used for direct lighting.
	// If roughness is 0, the probability of hitting a punctual or directional light is also 0.
	// Therefore, we return 0. The most efficient way to do it is with a max().
	return INV_PI * 0.5 * (D.x * G.x) / max(D.y * G.y, FLT_MIN);
}

float DV_SmithJointGGX(float NdotH, float NdotL, float NdotV, float roughness)
{
	float partLambdaV = GetSmithJointGGXPartLambdaV(NdotV, roughness);
	return DV_SmithJointGGX_WithPartLambda(NdotH, NdotL, NdotV, roughness, partLambdaV);
}

// Precompute a part of LambdaV.
// Note on this linear approximation.
// Exact for roughness values of 0 and 1. Also, exact when the cosine is 0 or 1.
// Otherwise, the worst case relative error is around 10%.
// https://www.desmos.com/calculator/wtp8lnjutx
float GetSmithJointGGXPartLambdaVApprox(float NdotV, float roughness)
{
	float a = roughness;
	return NdotV * (1.0 - a) + a;
}

float V_SmithJointGGXApprox_WithPartLambda(float NdotL, float NdotV, float roughness, float partLambdaV)
{
	float a = roughness;

	float lambdaV = NdotL * partLambdaV;
	float lambdaL = NdotV * (NdotL * (1.0 - a) + a);

	return 0.5 / (lambdaV + lambdaL);
}

float V_SmithJointGGXApprox(float NdotL, float NdotV, float roughness)
{
	float partLambdaV = GetSmithJointGGXPartLambdaVApprox(NdotV, roughness);
	return V_SmithJointGGXApprox_WithPartLambda(NdotL, NdotV, roughness, partLambdaV);
}

// roughnessT -> roughness in tangent direction
// roughnessB -> roughness in bitangent direction
float D_GGXAnisoNoPI(float TdotH, float BdotH, float NdotH, float roughnessT, float roughnessB)
{
	float a2 = roughnessT * roughnessB;
	vec3 v = vec3(roughnessB * TdotH, roughnessT * BdotH, a2 * NdotH);
	float  s = dot(v, v);

	// If roughness is 0, returns (NdotH == 1 ? 1 : 0).
	// That is, it returns 1 for perfect mirror reflection, and 0 otherwise.
	return SafeDiv(a2 * a2 * a2, s * s);
}

float D_GGXAniso(float TdotH, float BdotH, float NdotH, float roughnessT, float roughnessB)
{
	return INV_PI * D_GGXAnisoNoPI(TdotH, BdotH, NdotH, roughnessT, roughnessB);
}

float GetSmithJointGGXAnisoPartLambdaV(float TdotV, float BdotV, float NdotV, float roughnessT, float roughnessB)
{
	return length(vec3(roughnessT * TdotV, roughnessB * BdotV, NdotV));
}

// Note: V = G / (4 * NdotL * NdotV)
// Ref: https://cedec.cesa.or.jp/2015/session/ENG/14698.html The Rendering Materials of Far Cry 4
float V_SmithJointGGXAniso_WithPartLambda(float TdotV, float BdotV, float NdotV, float TdotL, float BdotL, float NdotL, float roughnessT, float roughnessB, float partLambdaV) {
    float lambdaV = NdotL * partLambdaV;
    float lambdaL = NdotV * length(vec3(roughnessT * TdotL, roughnessB * BdotL, NdotL));
    return 0.5 / (lambdaV + lambdaL);
}

float V_SmithJointGGXAniso(float TdotV, float BdotV, float NdotV, float TdotL, float BdotL, float NdotL, float roughnessT, float roughnessB) {
    float partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, roughnessT, roughnessB);
    return V_SmithJointGGXAniso_WithPartLambda(TdotV, BdotV, NdotV, TdotL, BdotL, NdotL, roughnessT, roughnessB, partLambdaV);
}

float DV_SmithJointGGXAniso_WithPartLambda(float TdotH, float BdotH, float NdotH, float NdotV,
                                           float TdotL, float BdotL, float NdotL,
                                           float roughnessT, float roughnessB, float partLambdaV) {
    float a2 = roughnessT * roughnessB;
    vec3 v = vec3(roughnessB * TdotH, roughnessT * BdotH, a2 * NdotH);
    float s = dot(v, v);
    float lambdaV = NdotL * partLambdaV;
    float lambdaL = NdotV * length(vec3(roughnessT * TdotL, roughnessB * BdotL, NdotL));
    vec2 D = vec2(a2 * a2 * a2, s * s);  // Fraction without the multiplier (1/Pi)
    vec2 G = vec2(1, lambdaV + lambdaL); // Fraction without the multiplier (1/2)
    return (INV_PI * 0.5) * (D.x * G.x) / max(D.y * G.y, 1e-6);  // Using 1e-6 in place of REAL_MIN
}

float DV_SmithJointGGXAniso(float TdotH, float BdotH, float NdotH,
                            float TdotV, float BdotV, float NdotV,
                            float TdotL, float BdotL, float NdotL,
                            float roughnessT, float roughnessB) {
    float partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, roughnessT, roughnessB);
    return DV_SmithJointGGXAniso_WithPartLambda(TdotH, BdotH, NdotH, NdotV,
                                                TdotL, BdotL, NdotL,
                                                roughnessT, roughnessB, partLambdaV);
}


// Get projected roughness for a certain normalized direction V in tangent space
// and an anisotropic roughness
// Ref: Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs, Heitz 2014, pp. 86, 88 - 39/60, 41/60
float GetProjectedRoughness(float TdotV, float BdotV, float NdotV, float roughnessT, float roughnessB)
{
	vec2 roughness = vec2(roughnessT, roughnessB);
	float sinTheta2 = max((1.0 - sq(NdotV)), FLT_MIN);
	// if sinTheta^2 = 0, NdotV = 1, TdotV = BdotV = 0 and roughness is arbitrary, no float azimuth
	// as there's a breakdown of the spherical parameterization, so we clamp under by FLT_MIN in any case
	// for safe division
	// Note:
	//       sin(thetaV)^2 * cos(phiV)^2 = (TdotV)^2
	//       sin(thetaV)^2 * sin(phiV)^2 = (BdotV)^2
	vec2 vProj2 = v2sq(vec2(TdotV, BdotV)) * (1.0 / sinTheta2);
	//       vProj2 = (cos^2(phi), sin^2(phi))
	float projRoughness = sqrt(dot(vProj2, roughness*roughness));
	return projRoughness;
}

//-----------------------------------------------------------------------------
// Diffuse BRDF - diffuseColor is expected to be multiply by the caller
//-----------------------------------------------------------------------------

float LambertNoPI()
{
	return 1.0;
}

float Lambert()
{
	return INV_PI;
}

float DisneyDiffuseNoPI(float NdotV, float NdotL, float LdotV, float perceptualRoughness)
{
	// (2 * LdotH * LdotH) = 1 + LdotV
	// float fd90 = 0.5 + (2 * LdotH * LdotH) * perceptualRoughness;
	float fd90 = 0.5 + (perceptualRoughness + perceptualRoughness * LdotV);
	// Two schlick fresnel term
	float lightScatter = F_Schlick_f2(1.0, fd90, NdotL);
	float viewScatter = F_Schlick_f2(1.0, fd90, NdotV);

	// Normalize the BRDF for polar view angles of up to (Pi/4).
	// We use the worst case of (roughness = albedo = 1), and, for each view angle,
	// integrate (brdf * cos(theta_light)) over all light directions.
	// The resulting value is for (theta_view = 0), which is actually a little bit larger
	// than the value of the integral for (theta_view = Pi/4).
	// Hopefully, the compiler folds the constant together with (1/Pi).
	return .965521 * (lightScatter * viewScatter);
}

#ifndef BUILTIN_TARGET_API
float DisneyDiffuse(float NdotV, float NdotL, float LdotV, float perceptualRoughness)
{
	return INV_PI * DisneyDiffuseNoPI(NdotV, NdotL, LdotV, perceptualRoughness);
}
#endif

// Ref: Diffuse Lighting for GGX + Smith Microsurfaces, p. 113.
vec3 DiffuseGGXNoPI(vec3 albedo, float NdotV, float NdotL, float NdotH, float LdotV, float roughness)
{
	float facing = 0.5 + 0.5 * LdotV;              // (LdotH)^2
	float rough = facing * (0.9 - 0.4 * facing) * (0.5 / NdotH + 1.0);
	float transmitL = F_Transm_Schlick_f1(0, NdotL);
	float transmitV = F_Transm_Schlick_f1(0, NdotV);
	float smooth_num = transmitL * transmitV * 1.05;   // Normalize F_t over the hemisphere
	float single = mix(smooth_num, rough, roughness); // Rescaled by PI
	float multiple = roughness * (0.1159 * PI);      // Rescaled by PI

	return single + albedo * multiple;
}

vec3 DiffuseGGX(vec3 albedo, float NdotV, float NdotL, float NdotH, float LdotV, float roughness)
{
	// Note that we could save 2 cycles by inlining the multiplication by INV_PI.
	return INV_PI * DiffuseGGXNoPI(albedo, NdotV, NdotL, NdotH, LdotV, roughness);
}

//-----------------------------------------------------------------------------
// Iridescence
//-----------------------------------------------------------------------------

// Ref: https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html
// Evaluation XYZ sensitivity curves in Fourier space
vec3 EvalSensitivity(float opd, float shift)
{
	// Use Gaussian fits, given by 3 parameters: val, pos and var
	float phase = 2.0 * PI * opd * 1e-6;
	vec3 val = vec3(5.4856e-13, 4.4201e-13, 5.2481e-13);
	vec3 pos = vec3(1.6810e+06, 1.7953e+06, 2.2084e+06);
	vec3 var = vec3(4.3278e+09, 9.3046e+09, 6.6121e+09);
	vec3 xyz = val * sqrt(2.0 * PI * var) * cos(pos * phase + shift) * exp(-var * phase * phase);
	xyz.x += 9.7470e-14 * sqrt(2.0 * PI * 4.5282e+09) * cos(2.2399e+06 * phase + shift) * exp(-4.5282e+09 * phase * phase);
	xyz /= 1.0685e-7;

	// Convert to linear sRGb color space here.
	// EvalIridescence works in linear sRGB color space and does not switch...
	vec3 srgb = XYZ_2_REC709_MAT * xyz;
	return srgb;
}

// Evaluate the reflectance for a thin-film layer on top of a dielectric medum.
vec3 EvalIridescence(float eta_1, float cosTheta1, float iridescenceThickness, vec3 baseLayerFresnel0, float iorOverBaseLayer)
{
	vec3 I;

	// iridescenceThickness unit is micrometer for this equation here. Mean 0.5 is 500nm.
	float Dinc = 3.0 * iridescenceThickness;

	// Note: Unlike the code provide with the paper, here we use schlick approximation
	// Schlick is a very poor approximation when dealing with iridescence to the Fresnel
	// term and there is no "neutral" value in this unlike in the original paper.
	// We use Iridescence mask here to allow to have neutral value

	// Hack: In order to use only one parameter (DInc), we deduced the ior of iridescence from current Dinc iridescenceThickness
	// and we use mask instead to fade out the effect
	float eta_2 = mix(2.0, 1.0, iridescenceThickness);
	// Following line from original code is not needed for us, it create a discontinuity
	// Force eta_2 -> eta_1 when Dinc -> 0.0
	// float eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));
	// Evaluate the cosTheta on the base layer (Snell law)
	float sinTheta2Sq = sq(eta_1 / eta_2) * (1.0 - sq(cosTheta1));

	// Handle TIR:
	// (Also note that with just testing sinTheta2Sq > 1.0, (1.0 - sinTheta2Sq) can be negative, as emitted instructions
	// can eg be a mad giving a small negative for (1.0 - sinTheta2Sq), while sinTheta2Sq still testing equal to 1.0), so we actually
	// test the operand [cosTheta2Sq := (1.0 - sinTheta2Sq)] < 0 directly:)
	float cosTheta2Sq = (1.0 - sinTheta2Sq);
	// Or use this "artistic hack" to get more continuity even though wrong (no TIR, continue the effect by mirroring it):
	//   if( cosTheta2Sq < 0.0 ) => { sinTheta2Sq = 2 - sinTheta2Sq; => so cosTheta2Sq = sinTheta2Sq - 1 }
	// ie don't test and simply do
	//   float cosTheta2Sq = abs(1.0 - sinTheta2Sq);
	if (cosTheta2Sq < 0.0)
		I = vec3(1.0, 1.0, 1.0);
	else
	{

		float cosTheta2 = sqrt(cosTheta2Sq);

		// First interface
		float R0 = IorToFresnel0(eta_2, eta_1);
		float R12 = F_Schlick_f1(R0, cosTheta1);
		float R21 = R12;
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		float phi21 = PI - phi12;

		// Second interface
		// The f0 or the base should account for the new computed eta_2 on top.
		// This is optionally done if we are given the needed current ior over the base layer that is accounted for
		// in the baseLayerFresnel0 parameter:
		if (iorOverBaseLayer > 0.0)
		{
			// Fresnel0ToIor will give us a ratio of baseIor/topIor, hence we * iorOverBaseLayer to get the baseIor
			vec3 baseIor = iorOverBaseLayer * vec3(Fresnel0ToIor(baseLayerFresnel0[0] + 0.0001),
			 Fresnel0ToIor(baseLayerFresnel0[1] + 0.0001), Fresnel0ToIor(baseLayerFresnel0[2] + 0.0001)); // guard against 1.0
			baseLayerFresnel0 = vec3(IorToFresnel0(baseIor[0], eta_2), IorToFresnel0(baseIor[1], eta_2), IorToFresnel0(baseIor[2], eta_2));
		}

		vec3 R23 = vec3(F_Schlick_f1(baseLayerFresnel0[0], cosTheta2), F_Schlick_f1(baseLayerFresnel0[1], cosTheta2), F_Schlick_f1(baseLayerFresnel0[2], cosTheta2));
		float  phi23 = 0.0;

		// Phase shift
		float OPD = Dinc * cosTheta2;
		float phi = phi21 + phi23;

		// Compound terms
		vec3 R123 = clamp(R12 * R23, 1e-5, 0.9999);
		vec3 r123 = sqrt(R123);
		vec3 Rs = sq(T121) * R23 / (vec3(1.0, 1.0, 1.0) - R123);

		// Reflectance term for m = 0 (DC term amplitude)
		vec3 C0 = R12 + Rs;
		I = C0;

		// Reflectance term for m > 0 (pairs of diracs)
		vec3 Cm = Rs - T121;
		for (int m = 1; m <= 2; ++m)
		{
			Cm *= r123;
			vec3 Sm = 2.0 * EvalSensitivity(float(m) * OPD, float(m) * phi);
			//vec3 SmP = 2.0 * evalSensitivity(m*OPD, m*phi2.y);
			I += Cm * Sm;
		}

		// Since out of gamut colors might be produced, negative color values are clamped to 0.
		I = max(I, vec3(0.0, 0.0, 0.0));
	}

	return I;
}

vec3 EvalIridescenceDefault(float eta_1, float cosTheta1, float iridescenceThickness, vec3 baseLayerFresnel0)
{
    return EvalIridescence(eta_1, cosTheta1, iridescenceThickness, baseLayerFresnel0, 0.0);
}


//-----------------------------------------------------------------------------
// Fabric
//-----------------------------------------------------------------------------

// Ref: https://knarkowicz.wordpress.com/2018/01/04/cloth-shading/
float D_CharlieNoPI(float NdotH, float roughness)
{
	float invR = (1.0 / roughness);
	float cos2h = NdotH * NdotH;
	float sin2h = 1.0 - cos2h;
	// Note: We have sin^2 so multiply by 0.5 to cancel it
	return (2.0 + invR) * pow(sin2h, invR * 0.5) / 2.0;
}

float D_Charlie(float NdotH, float roughness)
{
	return INV_PI * D_CharlieNoPI(NdotH, roughness);
}

float CharlieL(float x, float r)
{
	r = clamp(r, 0.0, 1.0);
	r = 1.0 - (1.0 - r) * (1.0 - r);

	float a = mix(25.3245, 21.5473, r);
	float b = mix(3.32435, 3.82987, r);
	float c = mix(0.16801, 0.19823, r);
	float d = mix(-1.27393, -1.97760, r);
	float e = mix(-4.85967, -4.32054, r);

	return a / (1.0 + b * pow(x, c)) + d * x + e;
}

// Note: This version don't include the softening of the paper: Production Friendly Microfacet Sheen BRDF
float V_Charlie(float NdotL, float NdotV, float roughness)
{
	float lambdaV = NdotV < 0.5 ? exp(CharlieL(NdotV, roughness)) : exp(2.0 * CharlieL(0.5, roughness) - CharlieL(1.0 - NdotV, roughness));
	float lambdaL = NdotL < 0.5 ? exp(CharlieL(NdotL, roughness)) : exp(2.0 * CharlieL(0.5, roughness) - CharlieL(1.0 - NdotL, roughness));

	return 1.0 / ((1.0 + lambdaV + lambdaL) * (4.0 * NdotV * NdotL));
}

// We use V_Ashikhmin instead of V_Charlie in practice for game due to the cost of V_Charlie
float V_Ashikhmin(float NdotL, float NdotV)
{
	// Use soft visibility term introduce in: Crafting a Next-Gen Material Pipeline for The Order : 1886
	return 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
}

// A diffuse term use with fabric done by tech artist - empirical
float FabricLambertNoPI(float roughness)
{
	return mix(1.0, 0.5, roughness);
}

float FabricLambert(float roughness)
{
	return INV_PI * FabricLambertNoPI(roughness);
}

float G_CookTorrance(float NdotH, float NdotV, float NdotL, float HdotV)
{
	return min(1.0, 2.0 * NdotH * min(NdotV, NdotL) / HdotV);
}

//-----------------------------------------------------------------------------
// Hair
//-----------------------------------------------------------------------------

//http://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf
vec3 ShiftTangent(vec3 T, vec3 N, float shift)
{
	return normalize(T + N * shift);
}

// Note: this is Blinn-Phong, the original paper uses Phong.
float D_KajiyaKay(vec3 T, vec3 H, float specularExponent)
{
	float TdotH = dot(T, H);
	float sinTHSq = clamp(1.0 - TdotH * TdotH, 0.0, 1.0);

	float dirAttn = clamp(TdotH + 1.0, 0.0, 1.0); // Evgenii: this seems like a hack? Do we floatly need this?

										   // Note: Kajiya-Kay is not energy conserving.
										   // We attempt at least some energy conservation by approximately normalizing Blinn-Phong NDF.
										   // We use the formulation with the NdotL.
										   // See http://www.thetenthplanet.de/archives/255.
	float n = specularExponent;
	float norm = (n + 2.0) * (1.0 / (2.0 * PI));

	return dirAttn * norm * pow(sinTHSq, 0.5 * n);
}

#endif // UNITY_BSDF_INCLUDED
