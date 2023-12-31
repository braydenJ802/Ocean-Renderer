#ifndef UNITY_COMMON_MATERIAL_INCLUDED
#define UNITY_COMMON_MATERIAL_INCLUDED

#include "res://Shaders/Additional Shaders/MathExtensions.gdshaderinc"

//-----------------------------------------------------------------------------
// Define constants
//-----------------------------------------------------------------------------

#define DEFAULT_SPECULAR_VALUE 0.04

// Following constant are used when we use clear coat properties that can't be store in the Gbuffer (with the Lit shader)
#define CLEAR_COAT_IOR 1.5
#define CLEAR_COAT_IETA (1.0 / CLEAR_COAT_IOR) // IETA is the inverse eta which is the ratio of IOR of two interface
#define CLEAR_COAT_F0 0.04 // IORToFresnel0(CLEAR_COAT_IOR)
#define CLEAR_COAT_ROUGHNESS 0.01
#define CLEAR_COAT_PERCEPTUAL_SMOOTHNESS RoughnessToPerceptualSmoothness(CLEAR_COAT_ROUGHNESS)
#define CLEAR_COAT_PERCEPTUAL_ROUGHNESS RoughnessToPerceptualRoughness(CLEAR_COAT_ROUGHNESS)
#define CLEAR_COAT_SSR_PERCEPTUAL_ROUGHNESS 0.0 // For screen space reflections and ray traced reflections, we want to have a purely smooth surface to map the envrionement light behavior

//-----------------------------------------------------------------------------
// Helper functions for roughness
//-----------------------------------------------------------------------------


#ifndef BUILTIN_TARGET_API
float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
	return perceptualRoughness * perceptualRoughness;
}

float RoughnessToPerceptualRoughness(float roughness)
{
	return sqrt(roughness);
}
#endif

float RoughnessToPerceptualSmoothness(float roughness)
{
	return 1.0 - sqrt(roughness);
}

float PerceptualSmoothnessToRoughness(float perceptualSmoothness)
{
	return (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);
}

float PerceptualSmoothnessToPerceptualRoughness(float perceptualSmoothness)
{
	return (1.0 - perceptualSmoothness);
}

// Beckmann to GGX roughness "conversions":
//
// As also noted for NormalVariance in this file, Beckmann microfacet models use a Gaussian distribution of slopes
// and the roughness parameter absorbs constants in the canonical Gaussian formula and is thus not exactly the variance.
// The relationship is:
//
// roughnessBeckmann^2 = 2 variance (where variance is usually denoted sigma^2 but some comp gfx papers use sigma for
// variance or even sigma for roughness itself.)
//
// Microfacet BRDF models with a GGX NDF implies a Cauchy distribution of slopes (also corresponds to the distribution
// of slopes on an ellipsoid). Cauchy distributions don't have second moments, which precludes having a variance,
// but chopping the far tails of GGX and keeping 94% of the mass yields a distribution with a defined variance where
// we can then relate the roughness of GGX to a variance (see Ray Tracing Gems p153 - the reference is wrong though,
// the Conty paper doesn't mention this at all, but it can be found in stats using quantiles):
//
// roughnessGGX^2 = variance / 2
//
// From the two previous, if we want roughly comparable variances of slopes between a Beckmann and a GGX NDF, we can
// equate the variances and get a conversion of their roughnesses:
//
// 2 * roughnessGGX^2 = roughnessBeckmann^2 / 2      <==>
// 4 * roughnessGGX^2 = roughnessBeckmann^2          <==>
// 2 * roughnessGGX = roughnessBeckmann
//
// (Note that the Ray Tracing Gems paper makes an error on p154 writing sqrt(2) * roughnessGGX = roughnessBeckmann;
// Their validation study using ray tracing and LEADR - which looks good - is for the *variance to GGX* roughness mapping,
// not the Beckmann to GGX roughness "conversion")
float BeckmannRoughnessToGGXRoughness(float roughnessBeckmann)
{
	return 0.5 * roughnessBeckmann;
}

float PerceptualRoughnessBeckmannToGGX(float perceptualRoughnessBeckmann)
{
	//sqrt(a_ggx) = sqrt(0.5) sqrt(a_beckmann)
	return sqrt(0.5) * perceptualRoughnessBeckmann;
}

float GGXRoughnessToBeckmannRoughness(float roughnessGGX)
{
	return 2.0 * roughnessGGX;
}

float PerceptualRoughnessToPerceptualSmoothness(float perceptualRoughness)
{
	return (1.0 - perceptualRoughness);
}

// WARNING: this has been deprecated, and should not be used!
// Using roughness values of 0 leads to INFs and NANs. The only sensible place to use the roughness
// value of 0 is IBL, so we do not modify the perceptual roughness which is used to select the MIP map level.
// Note: making the constant too small results in aliasing.
float ClampRoughnessForAnalyticalLights(float roughness)
{
	return max(roughness, 1.0 / 1024.0);
}

// Given that the GGX model is invalid for a roughness of 0.0. This values have been experimentally evaluated to be the limit for the roughness
// for integration.
float ClampRoughnessForRaytracing(float roughness)
{
	return max(roughness, 0.001225);
}
float ClampPerceptualRoughnessForRaytracing(float perceptualRoughness)
{
	return max(perceptualRoughness, 0.035);
}

void ConvertValueAnisotropyToValueTB(float value, float anisotropy, out float valueT, out float valueB)
{
	// Use the parametrization of Sony Imageworks.
	// Ref: Revisiting Physically Based Shading at Imageworks, p. 15.
	valueT = value * (1.0 + anisotropy);
	valueB = value * (1.0 - anisotropy);
}

void ConvertAnisotropyToRoughness(float perceptualRoughness, float anisotropy, out float roughnessT, out float roughnessB)
{
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	ConvertValueAnisotropyToValueTB(roughness, anisotropy, roughnessT, roughnessB);
}

void ConvertRoughnessTAndAnisotropyToRoughness(float roughnessT, float anisotropy, out float roughness)
{
	roughness = roughnessT / (1.0 + anisotropy);
}

float ConvertRoughnessTAndBToRoughness(float roughnessT, float roughnessB)
{
	return 0.5 * (roughnessT + roughnessB);
}

void ConvertRoughnessToAnisotropy(float roughnessT, float roughnessB, out float anisotropy)
{
	anisotropy = ((roughnessT - roughnessB) / max(roughnessT + roughnessB, 0.0001));
}

// WARNING: this has been deprecated, and should not be used!
// Same as ConvertAnisotropyToRoughness but
// roughnessT and roughnessB are clamped, and are meant to be used with punctual and directional lights.
void ConvertAnisotropyToClampRoughness(float perceptualRoughness, float anisotropy, out float roughnessT, out float roughnessB)
{
	ConvertAnisotropyToRoughness(perceptualRoughness, anisotropy, roughnessT, roughnessB);

	roughnessT = ClampRoughnessForAnalyticalLights(roughnessT);
	roughnessB = ClampRoughnessForAnalyticalLights(roughnessB);
}

// Use with stack BRDF (clear coat / coat) - This only used same equation to convert from Blinn-Phong spec power to Beckmann roughness
float RoughnessToVariance(float roughness)
{
	return 2.0 / sq(roughness) - 2.0;
}

float VarianceToRoughness(float variance)
{
	return sqrt(2.0 / (variance + 2.0));
}

// Normal Map Filtering - This must match HDRP\Editor\AssetProcessors\NormalMapFilteringTexturePostprocessor.cs - highestVarianceAllowed (TODO: Move in core)
#define NORMALMAP_HIGHEST_VARIANCE 0.03125

float DecodeVariance(float gradientW)
{
	return gradientW * NORMALMAP_HIGHEST_VARIANCE;
}

// Return modified perceptualSmoothness based on provided variance (get from GeometricNormalVariance + TextureNormalVariance)
float NormalFiltering(float perceptualSmoothness, float variance, float threshold)
{
	float roughness = PerceptualSmoothnessToRoughness(perceptualSmoothness);
	// Ref: Geometry into Shading - http://graphics.pixar.com/library/BumpRoughness/paper.pdf - equation (3)
	float squaredRoughness = clamp(roughness * roughness + min(2.0 * variance, threshold * threshold), 0.0, 1.0); // threshold can be floatly low, square the value for easier control

	return RoughnessToPerceptualSmoothness(sqrt(squaredRoughness));
}

float ProjectedSpaceNormalFiltering(float perceptualSmoothness, float variance, float threshold)
{
	float roughness = PerceptualSmoothnessToRoughness(perceptualSmoothness);
	// Ref: Stable Geometric Specular Antialiasing with Projected-Space NDF Filtering - https://yusuketokuyoshi.com/papers/2021/Tokuyoshi2021SAA.pdf
	float squaredRoughness = roughness * roughness;
	float projRoughness2 = squaredRoughness / (1.0 - squaredRoughness);
	float filteredProjRoughness2 = clamp(projRoughness2 + min(2.0 * variance, threshold * threshold), 0.0, 1.0);
	squaredRoughness = filteredProjRoughness2 / (filteredProjRoughness2 + 1.0f);

	return RoughnessToPerceptualSmoothness(sqrt(squaredRoughness));
}

// Reference: Error Reduction and Simplification for Shading Anti-Aliasing
// Specular antialiasing for geometry-induced normal (and NDF) variations: Tokuyoshi / Kaplanyan et al.'s method.
// This is the deferred approximation, which works reasonably well so we keep it for forward too for now.
// screenSpaceVariance should be at most 0.5^2 = 0.25, as that corresponds to considering
// a gaussian pixel reconstruction kernel with a standard deviation of 0.5 of a pixel, thus 2 sigma covering the whole pixel.
float GeometricNormalVariance(vec3 geometricNormalWS, float screenSpaceVariance)
{
	vec3 deltaU = dFdx(geometricNormalWS);
	vec3 deltaV = dFdy(geometricNormalWS);

	return screenSpaceVariance * (dot(deltaU, deltaU) + dot(deltaV, deltaV));
}

// Return modified perceptualSmoothness
float GeometricNormalFiltering(float perceptualSmoothness, vec3 geometricNormalWS, float screenSpaceVariance, float threshold)
{
	float variance = GeometricNormalVariance(geometricNormalWS, screenSpaceVariance);
	return NormalFiltering(perceptualSmoothness, variance, threshold);
}

float ProjectedSpaceGeometricNormalFiltering(float perceptualSmoothness, vec3 geometricNormalWS, float screenSpaceVariance, float threshold)
{
	float variance = GeometricNormalVariance(geometricNormalWS, screenSpaceVariance);
	return ProjectedSpaceNormalFiltering(perceptualSmoothness, variance, threshold);
}

// Normal map filtering based on The Order : 1886 SIGGRAPH course notes implementation.
// Basically Toksvig with an intermediate single vMF lobe induced dispersion (Han et al. 2007)
//
// This returns 2 times the variance of the induced "mesoNDF" lobe (an NDF induced from a section of
// the normal map) from the level 0 mip normals covered by the "current texel".
//
// avgNormalLength gives the dispersion information for the covered normals.
//
// Note that hw filtering on the normal map should be trilinear to be conservative, while anisotropic
// risk underfiltering. Could also compute average normal on the fly with a proper normal map format,
// like Toksvig.
float TextureNormalVariance(float avgNormalLength)
{
	float variance = 0.0;

	if (avgNormalLength < 1.0)
	{
		float avgNormLen2 = avgNormalLength * avgNormalLength;
		float kappa = (3.0 * avgNormalLength - avgNormalLength * avgNormLen2) / (1.0 - avgNormLen2);

		// Ref: Frequency Domain Normal Map Filtering - http://www.cs.columbia.edu/cg/normalmap/normalmap.pdf (equation 21)
		// Relationship between between the standard deviation of a Gaussian distribution and the roughness parameter of a Beckmann distribution.
		// is roughness^2 = 2 variance    (note: variance is sigma^2)
		// (Ref: Filtering Distributions of Normals for Shading Antialiasing - Equation just after (14))
		// Relationship between gaussian lobe and vMF lobe is 2 * variance = 1 / (2 * kappa) = roughness^2
		// (Equation 36 of  Normal map filtering based on The Order : 1886 SIGGRAPH course notes implementation).
		// So to get variance we must use variance = 1 / (4 * kappa)
		variance = 0.25 / kappa;
	}

	return variance;
}

float TextureNormalFiltering(float perceptualSmoothness, float avgNormalLength, float threshold)
{
	float variance = TextureNormalVariance(avgNormalLength);
	return NormalFiltering(perceptualSmoothness, variance, threshold);
}

// ----------------------------------------------------------------------------
// Helper for Disney parametrization
// ----------------------------------------------------------------------------

vec3 ComputeDiffuseColor(vec3 baseColor, float metallic)
{
	return baseColor * (1.0 - metallic);
}

vec3 ComputeFresnel0(vec3 baseColor, float metallic, float dielectricF0)
{
	return mix(vec3(dielectricF0, dielectricF0, dielectricF0), baseColor, metallic);
}

// ----------------------------------------------------------------------------
// Helper for normal blending
// ----------------------------------------------------------------------------

// ref https://www.gamedev.net/topic/678043-how-to-blend-world-space-normals/#entry5287707
// assume compositing in world space
// Note: Using vtxNormal = vec3(0, 0, 1) give the BlendNormalRNM formulation.
// TODO: Untested
vec3 BlendNormalWorldspaceRNM(vec3 n1, vec3 n2, vec3 vtxNormal)
{
	// Build the shortest-arc quaternion
	vec4 q = vec4(cross(vtxNormal, n2), dot(vtxNormal, n2) + 1.0) / sqrt(2.0 * (dot(vtxNormal, n2) + 1.0));

	// Rotate the normal
	return n1 * (q.w * q.w - dot(q.xyz, q.xyz)) + 2.0 * q.xyz * dot(q.xyz, n1) + 2.0 * q.w * cross(q.xyz, n1);
}

// ref http://blog.selfshadow.com/publications/blending-in-detail/
// ref https://gist.github.com/selfshadow/8048308
// Reoriented Normal Mapping
// Blending when n1 and n2 are already 'unpacked' and normalised
// assume compositing in tangent space
vec3 BlendNormalRNM(vec3 n1, vec3 n2)
{
	vec3 t = n1.xyz + vec3(0.0, 0.0, 1.0);
	vec3 u = n2.xyz * vec3(-1.0, -1.0, 1.0);
	vec3 r = (t / t.z) * dot(t, u) - u;
	return r;
}

// assume compositing in tangent space
vec3 BlendNormal(vec3 n1, vec3 n2)
{
	return normalize(vec3(n1.xy * n2.z + n2.xy * n1.z, n1.z * n2.z));
}

// ----------------------------------------------------------------------------
// Helper for triplanar
// ----------------------------------------------------------------------------

// Ref: http://http.developer.nvidia.com/GPUGems3/gpugems3_ch01.html / http://www.slideshare.net/icastano/cascades-demo-secrets
vec3 ComputeTriplanarWeights(vec3 normal)
{
	// Determine the blend weights for the 3 planar projections.
	vec3 blendWeights = abs(normal);
	// Tighten up the blending zone
	blendWeights = (blendWeights - 0.2);
	blendWeights = blendWeights * blendWeights * blendWeights; // pow(blendWeights, 3);
	// Force weights to sum to 1.0 (very important!)
	blendWeights = max(blendWeights, vec3(0.0, 0.0, 0.0));
	blendWeights /= dot(blendWeights, vec3(1.0));

	return blendWeights;
}

// Planar/Triplanar convention for Unity in world space
void GetTriplanarCoordinate(vec3 position, out vec2 uvXZ, out vec2 uvXY, out vec2 uvZY)
{
	// Caution: This must follow the same rule as what is use for SurfaceGradient triplanar
	// TODO: Currently the normal mapping looks wrong without SURFACE_GRADIENT option because we don't handle corretly the tangent space
	uvXZ = vec2(position.x, position.z);
	uvXY = vec2(position.x, position.y);
	uvZY = vec2(position.z, position.y);
}

// ----------------------------------------------------------------------------
// Helper for detail map operation
// ----------------------------------------------------------------------------

float LerpWhiteTo(float b, float t)
{
	float oneMinusT = 1.0 - t;
	return oneMinusT + b * t;
}

#ifndef BUILTIN_TARGET_API
vec3 LerpWhiteTo_v3(vec3 b, float t)
{
	float oneMinusT = 1.0 - t;
	return vec3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}
#endif

#endif // UNITY_COMMON_MATERIAL_INCLUDED
