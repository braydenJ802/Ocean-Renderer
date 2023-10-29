
#ifndef OCEAN_SIMULATION_SAMPLING_INCLUDED
#define OCEAN_SIMULATION_SAMPLING_INCLUDED

#if defined(OCEAN_FOUR_CASCADES)
	#define ACTIVE_CASCADES vec4(1.0, 1.0, 1.0, 1.0)
#elif defined(OCEAN_THREE_CASCADES)
	#define ACTIVE_CASCADES vec4(1.0, 1.0, 1.0, 0.0)
#else
	#define ACTIVE_CASCADES vec4(1.0, 1.0, 0.0, 0.0)
#endif

const float LOD_THRESHOLD = 0.05;

uniform sampler2DArray Ocean_DisplacementAndDerivatives;
uniform sampler2DArray Ocean_Turbulence;

uniform vec4 Ocean_LengthScales = vec4(0.0);

float EaseInOutClamped(float x)
{
	x = clamp(x, 0.0, 1.0);
	return 3.0 * x * x - 2.0 * x * x * x;
}

vec4 LodWeights(float viewDist, float lodScale)
{
	vec4 x = (viewDist - Ocean_LengthScales * lodScale) / Ocean_LengthScales / lodScale;
	return vec4(1.0) - vec4(EaseInOutClamped(x.x), EaseInOutClamped(x.y), EaseInOutClamped(x.z), EaseInOutClamped(x.w));
}

vec3 SampleDisplacement(vec2 worldXZ, vec4 weights, vec4 shoreModulation)
{
	vec3 displacement = vec3(0.0);
	weights *= shoreModulation;

	displacement += weights[0] * textureLod(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[0], 0.0 * 2.0), 0.0).xyz;

	if (weights[1] > LOD_THRESHOLD)
		displacement += weights[1] * textureLod(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[1], 1.0 * 2.0), 0.0).xyz;

	if (ACTIVE_CASCADES[2] > 1.0)
		if (weights[2] > LOD_THRESHOLD)
			displacement += weights[2] * textureLod(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[2], 2.0 * 2.0), 0.0).xyz;

	if (ACTIVE_CASCADES[3] > 1.0)
		if (weights[3] > LOD_THRESHOLD)
			displacement += weights[3] * textureLod(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[3], 3.0 * 2.0), 0.0).xyz;

	return displacement;
}

float SampleHeight(vec2 worldPos, vec4 weights, vec4 shoreModulation)
{
	vec3 displacement = SampleDisplacement(worldPos, weights, shoreModulation);
	displacement = SampleDisplacement(worldPos - displacement.xz, weights, shoreModulation);
	displacement = SampleDisplacement(worldPos - displacement.xz, weights, shoreModulation);
	displacement = SampleDisplacement(worldPos - displacement.xz, weights, shoreModulation);

	return displacement.y;
}

mat4 SampleDerivatives(vec2 worldXZ, vec4 weights)
{
	mat4 o = mat4(0.0);

	o[0] = weights[0] * texture(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[0], 0.0 * 2.0 + 1.0));

	if (weights[1] > LOD_THRESHOLD)
		o[1] = weights[1] * texture(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[1], 1.0 * 2.0 + 1.0));

	if (ACTIVE_CASCADES[2] > 1.0)
		if (weights[2] > LOD_THRESHOLD)
			o[2] = weights[2] * texture(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[2], 2.0 * 2.0 + 1.0));

	if (ACTIVE_CASCADES[3] > 1.0)
		if (weights[3] > LOD_THRESHOLD)
			o[3] = weights[3] * texture(Ocean_DisplacementAndDerivatives, vec3(worldXZ / Ocean_LengthScales[3], 3.0 * 2.0 + 1.0));

	return o;
}

mat4 SampleTurbulence(vec2 worldXZ, vec4 weights)
{
	mat4 o = mat4(0.0);

	o[0] = weights[0] * texture(Ocean_Turbulence, vec3(worldXZ / Ocean_LengthScales[0], 0.0));

	if (weights[1] > LOD_THRESHOLD)
		o[1] = weights[1] * texture(Ocean_Turbulence, vec3(worldXZ / Ocean_LengthScales[1], 1.0));

	if (ACTIVE_CASCADES[2] > 1.0)
		if (weights[2] > LOD_THRESHOLD)
			o[2] = weights[2] * texture(Ocean_Turbulence, vec3(worldXZ / Ocean_LengthScales[2], 2.0));

	if (ACTIVE_CASCADES[3] > 1.0)
		if (weights[3] > LOD_THRESHOLD)
			o[3] = weights[3] * texture(Ocean_Turbulence, vec3(worldXZ / Ocean_LengthScales[3], 3.0));

	return o;
}

vec3 NormalFromDerivatives(mat4 derivativesCascades, vec4 weights)
{
	vec4 derivatives = derivativesCascades[0] * weights[0]
		+ derivativesCascades[1] * weights[1]
		+ derivativesCascades[2] * weights[2]
		+ derivativesCascades[3] * weights[3];
	vec2 slope = vec2(derivatives.x / max(0.001, 1.0 + derivatives.z),
                    derivatives.y / max(0.001, 1.0 + derivatives.w));

	return normalize(vec3(-slope.x, 1.0, -slope.y));
}

#endif
