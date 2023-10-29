#ifndef OCEAN_VOLUME_INCLUDED
#define OCEAN_VOLUME_INCLUDED

#include "OceanGlobals.gdshaderinc"

vec3 ColorThroughWater(vec3 color, vec3 volumeColor, float distThroughWater, float depth)
{
	distThroughWater = max(0, distThroughWater);
	depth = max(0, depth);
    color *= AbsorptionTint(exp(-(distThroughWater + depth) / Ocean_AbsorptionDepthScale));
	return mix(color, volumeColor, 1 - clamp(exp(-Ocean_FogDensity * distThroughWater)));
}

vec3 UnderwaterFogColor(vec3 viewDir, vec3 lightDir, float depth)
{
	float depthScale = 0;//clamp(exp(Ocean_ElevationBelowCamera / Ocean_FogGradientScale));
	float bias = min(0, depth * 0.02);
	float sssFactor = 0.1 * pow(max(0, 1 - viewDir.y + bias), 3);
	sssFactor *= 1 + pow(clamp(dot(lightDir, -viewDir)), 4);
	sssFactor *= clamp(1 - depthScale);
    vec3 color = DeepScatterColor(depthScale) * max(0.5, clamp(2 - viewDir.y + bias));
	vec3 sssColor = SssColor(depthScale);
	color = color + sssColor * sssFactor;
	return color;
}

#endif