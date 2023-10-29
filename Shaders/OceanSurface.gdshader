shader_type spatial;

// Shader definitions and constants
#ifndef OCEAN_SURFACE_INCLUDED
#define OCEAN_SURFACE_INCLUDED


#include "Additional Shaders/UPS/DeclareDepthTexture.gdshaderinc"

#include "BrunetonLighting.gdshaderinc"
#include "OceanGlobals.gdshaderinc"
#include "OceanMaterialProps.gdshaderinc"
#include "OceanVolume.gdshaderinc"
#include "OceanFoam.gdshaderinc"

uniform vec4 _CameraDepthTexture_TexelSize;

// Sample functions for Godot are simplified to use texture() instead of custom functions
// The sampling depends on the type of texture and required mip level or derivatives.

// Functions
float Pow5(float x) {
    return x * x * x * x * x;
}

vec3 PositionWsFromDepth(float rawDepth, vec2 screenUV, mat4 inverseProj, mat4 inverseView) {
    vec4 positionCS = vec4(screenUV * 2.0 - 1.0, rawDepth, 1.0);
    vec4 positionVS = inverseProj * positionCS;
    positionVS /= positionVS.w;
    return (inverseView * positionVS).xyz;
}

vec2 SlopeVarianceSquared(float windSpeed, float viewDist, float alignment, float scale) {
    float upwind = 0.01 * sqrt(windSpeed) * viewDist / (viewDist + scale);
    return vec2(upwind, upwind * (1.0 - 0.3 * alignment));
}

float EffectiveFresnel(vec3 viewDir_windSpace, vec3 normal_windSpace, vec2 slopeVarianceSquared) {
    const float R = 0.02;
    float fresnel = R + (1.0 - R) * MeanFresnel(viewDir_windSpace, normal_windSpace, slopeVarianceSquared);
    return clamp(fresnel, 0.0, 1.0);
}


float ShlickFresnel(vec3 viewDir, vec3 normal)
{
	const float R = 0.02;
	return R + (1 - R) * Pow5(1 - clamp(abs(dot(viewDir, normal))));
}

vec3 Specular(LightingInput li, BrunetonInputs bi)
{
    float radiance = li.mainLight.shadowAttenuation * ReflectedSunRadiance(
		bi.lightDir_windSpace,
		bi.viewDir_windSpace,
		bi.normal_windSpace,
		bi.tangentX_windSpace,
		bi.tangentY_windSpace,
		max(1e-4, bi.slopeVarianceSquared + _SpecularMinRoughness * 0.2));
    return radiance * _SpecularStrength * li.mainLight.color;
}

vec3 Reflection(LightingInput li, BrunetonInputs bi)
{
    vec3 sky = MeanSkyRadiance(Ocean_SkyMap, samplerOcean_SkyMap,
		transpose(Ocean_WorldToWindSpace),
        bi.viewDir_windSpace,
        bi.normal_windSpace,
        bi.tangentX_windSpace,
        bi.tangentY_windSpace,
        bi.slopeVarianceSquared);

	#ifdef PLANAR_REFLECTIONS_ENABLED
	vec4 local = GetPlanarReflection(li.viewDir, li.normal, li.positionWS, 
		bi.slopeVarianceSquared.x * 100, 1 - _ReflectionNormalStength);
	return lerp(sky, local.rgb, local.a);
	#else
	return sky;
	#endif
}

vec3 ReflectionBackface(LightingInput li)
{
	vec3 normal = li.normal;
	normal.xz *= 0.2;
	normal = normalize(normal);
	vec3 dir = reflect(li.viewDir, normal);
    vec3 volume = UnderwaterFogColor(dir, li.mainLight.direction, 0);
	return volume;
	
	//#ifdef PLANAR_REFLECTIONS_ENABLED
	//vec4 color = GetPlanarReflection(li.viewDir, li.normal, li.positionWS, 0, 1);
	//color.rgb = ColorThroughWater(color.rgb, 0, 0, -li.shore.x).rgb;
	//return lerp(volume, color.rgb, color.a);
	//#else
	//return volume;
	//#endif
}

vec3 LitFoamColor(LightingInput li, FoamData foamData)
{
    float ndotl = (0.2 + 0.8 * clamp(dot(foamData.normal, li.mainLight.direction))) 
		* li.mainLight.shadowAttenuation;
    return foamData.albedo * _FoamTint.rgb * 
		(ndotl * li.mainLight.color + OceanEnvironmentDiffuse(foamData.normal));
}

vec2 SubsurfaceScatteringFactor(LightingInput li)
{
    float normalFactor = clamp(dot(normalize(lerp(li.viewDir, li.normal, _SssNormalStrength)), li.viewDir));
    float heightFactor = clamp((li.positionWS.y + Ocean_ReferenceWaveHeight * (1 + _SssHeightBias)) * 0.5 / max(0.5, Ocean_ReferenceWaveHeight));
    heightFactor = pow(abs(heightFactor), max(1, Ocean_ReferenceWaveHeight * 0.4));
    float sun = _SssSunStrength * normalFactor * heightFactor * pow(clamp(dot(li.mainLight.direction, -li.viewDir)), min(50, 1 / _SssSpread));
    float environment = _SssEnvironmentStrength * normalFactor * heightFactor * clamp(1 - li.viewDir.y);
	vec2 factor = float2(sun, environment);
	factor *= _SssFadeDistance / (_SssFadeDistance + li.viewDist);
	return factor;
}

vec3 RefractionCoords(float refractionStrength, vec4 positionNDC, float viewDepth, vec3 normal)
{
	vec2 uvOffset = normal.xz * refractionStrength;
	uvOffset.y *=
		_CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
	vec2 refractedScreenUV = (positionNDC.xy + uvOffset) / positionNDC.w;
    float rawDepth = SampleSceneDepth(refractedScreenUV);
    float refractedDepthDiff = LinearEyeDepth(rawDepth, _ZBufferParams) - viewDepth;
	uvOffset *= clamp(refractedDepthDiff);
	refractedScreenUV = (positionNDC.xy + uvOffset) / positionNDC.w;
    rawDepth = SampleSceneDepth(refractedScreenUV);
	return float3(refractedScreenUV, rawDepth);
}

vec3 Refraction(LightingInput li, FoamData foamData, vec2 sss, vec3 foamColor)
{
	float depthScale = 0;//exp(li.shore.x / Ocean_FogGradientScale);
    vec3 color = DeepScatterColor(0 * (1 - abs(li.viewDir.y)) * (1 - abs(li.viewDir.y)) * depthScale);
    vec3 sssColor = SssColor(depthScale);
	color += sssColor * clamp(sss.x + sss.y);
    float ndotl = clamp(dot(li.normal, li.mainLight.direction));
    color += (ndotl * 0.8 + 0.2f) * li.mainLight.color  * Ocean_DiffuseColor;
	
	#ifdef OCEAN_TRANSPARENCY_ENABLED
	vec3 refractionCoords = RefractionCoords(_RefractionStrength, li.positionNDC, li.viewDepth, li.normal);
	vec3 backgroundColor = SampleSceneColor(refractionCoords.xy);
	
	vec3 backgroundPositionWS = PositionWsFromDepth(refractionCoords.z, refractionCoords.xy, Ocean_InverseProjectionMatrix, Ocean_InverseViewMatrix);
	float backgroundDistance = length(backgroundPositionWS - li.cameraPos) - li.viewDist;
	color = ColorThroughWater(backgroundColor, color, backgroundDistance, -backgroundPositionWS.y);
	#endif
	
	#ifdef WAVES_FOAM_ENABLED
	float underwaterFoamVisibility = 20 / (20 + li.viewDist);
	vec3 tint = AbsorptionTint(0.8);
	vec3 underwaterFoamColor = foamColor * tint * tint;
	color = lerp(color, underwaterFoamColor, foamData.coverage.y * underwaterFoamVisibility);
	#endif
	return color;
}

vec3 RefractionBackface(LightingInput li, vec3 refractionDir)
{
	#ifdef OCEAN_TRANSPARENCY_ENABLED
	vec3 refractionCoords = RefractionCoords(_RefractionStrengthUnderwater, li.positionNDC, li.viewDepth, li.normal);
	return SampleSceneColor(refractionCoords.xy);
	#else
	return SampleOceanSpecCube(refractionDir);
	#endif
}

vec4 HorizonBlend(LightingInput li)
{
	vec3 dir = -float3(li.viewDir.x, 0, li.viewDir.z);
	vec3 horizonColor = SampleOceanSpecCube(dir);
	
	float distanceScale = 100 + 7 * abs(li.cameraPos.y);
	float t = exp(-5 / max(_HorizonFog, 0.01) * (abs(li.viewDir.y) + distanceScale / (li.viewDist + distanceScale)));
	return float4(horizonColor, t);	
}

vec3 GetOceanColor(LightingInput li, FoamData foamData)
{
	vec3 tangentY = float3(0.0, li.normal.z, -li.normal.y);
	tangentY /= max(0.001, length(tangentY));
	vec3 tangentX = cross(tangentY, li.normal);
    
	BrunetonInputs bi;
	bi.lightDir_windSpace = mul(Ocean_WorldToWindSpace, float4(li.mainLight.direction, 0)).xyz;
    bi.viewDir_windSpace = mul(Ocean_WorldToWindSpace, float4(li.viewDir, 0)).xyz;
    bi.normal_windSpace = mul(Ocean_WorldToWindSpace, float4(li.normal, 0)).xyz;
    bi.tangentX_windSpace = mul(Ocean_WorldToWindSpace, float4(tangentX, 0)).xyz;
    bi.tangentY_windSpace = mul(Ocean_WorldToWindSpace, float4(tangentY, 0)).xyz;
    bi.slopeVarianceSquared = _RoughnessScale * (1 + li.roughnessMap * 0.3)
		* SlopeVarianceSquared(Ocean_WindSpeed * Ocean_WavesScale, li.viewDist,
		Ocean_WavesAlignement, _RoughnessDistance);
	
	vec2 sss = SubsurfaceScatteringFactor(li);
    vec3 foamLitColor = 0;
	#if defined(WAVES_FOAM_ENABLED) || defined(CONTACT_FOAM_ENABLED)
	foamLitColor = LitFoamColor(li, foamData);
	#endif
	
	float fresnel = EffectiveFresnel(bi);
	vec3 specular = Specular(li, bi) * Pow5(1 - foamData.coverage.y);
	vec3 reflected = Reflection(li, bi);
    vec3 refracted = Refraction(li, foamData, sss, foamLitColor);
	vec4 horizon = HorizonBlend(li);
	vec3 color = specular + lerp(refracted, reflected, fresnel);
	#if defined(WAVES_FOAM_ENABLED) || defined(CONTACT_FOAM_ENABLED)
	color = lerp(color, foamLitColor, foamData.coverage.x);
	#endif
	color = lerp(color, horizon.rgb, horizon.a);
	return color;
}

vec3 GetOceanColorUnderwater(LightingInput li)
{
	const float n = 1.1;
	vec3 refractionDir = refract(-li.viewDir, -li.normal, n);
	
	float fresnel = max(ShlickFresnel(li.viewDir, li.normal), dot(refractionDir, refractionDir) < 0.5);
	vec3 refracted = RefractionBackface(li, refractionDir);
	vec3 reflected = ReflectionBackface(li);
	vec3 color = lerp(refracted, reflected, fresnel);
	vec3 volume = UnderwaterFogColor(li.viewDir, li.mainLight.direction, li.cameraPos.y);
    color = ColorThroughWater(color, volume, li.viewDist - _ProjectionParams.y, 0);
	return color;
}

#endif