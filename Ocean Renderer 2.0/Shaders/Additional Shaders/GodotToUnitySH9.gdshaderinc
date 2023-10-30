// Global temporary variables in GLSL, and access to ambient/reflection/SH9 in shaders:
// Requires these patches:
// https://github.com/lyuma/godot/tree/shader_improvements_meta (master)
// https://github.com/lyuma/godot/tree/shader_global_arrays_3.2 (3.2)
// https://github.com/lyuma/godot/tree/shader_npr_lighting_3.2 (3.2)

uniform vec4 unity_SHAr = vec4(0.0);
uniform vec4 unity_SHAg = vec4(0.0);
uniform vec4 unity_SHAb = vec4(0.0);
uniform vec4 unity_SHBr = vec4(0.0);
uniform vec4 unity_SHBg = vec4(0.0);
uniform vec4 unity_SHBb = vec4(0.0);
uniform vec4 unity_SHC = vec4(0.0);

// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// normal should be normalized, w=1.0
vec3 SHEvalLinearL0L1 (vec4 normal)
{
	vec3 x;

	// Linear (L1) + constant (L0) polynomial terms
	x.r = dot(unity_SHAr,normal);
	x.g = dot(unity_SHAg,normal);
	x.b = dot(unity_SHAb,normal);

	return x;
}

// normal should be normalized, w=1.0
vec3 SHEvalLinearL2 (vec4 normal)
{
	vec3 x1, x2;
	// 4 of the quadratic (L2) polynomials
	vec4 vB = normal.xyzz * normal.yzzx;
	x1.r = dot(unity_SHBr,vB);
	x1.g = dot(unity_SHBg,vB);
	x1.b = dot(unity_SHBb,vB);

	// Final (5th) quadratic (L2) polynomial
	float vC = normal.x*normal.x - normal.y*normal.y;
	x2 = unity_SHC.rgb * vC;

	return x1 + x2;
}

// normal should be normalized, w=1.0
// output in active color space
vec3 ShadeSH9 (vec4 normal)
{
	// Linear + constant polynomial terms
	vec3 res = SHEvalLinearL0L1 (normal);

	// Quadratic polynomials
	res += SHEvalLinearL2 (normal);


	return res;
}


// Godot conversion operations, followed by user code.

void fragment() {
	// Initialize SH coefficiens.
	LightmapCapture lc;
	if (GET_LIGHTMAP_SH(lc)) {
		const float c1 = 0.429043;
		const float c2 = 0.511664;
		const float c3 = 0.743125;
		const float c4 = 0.886227;
		const float c5 = 0.247708;
		// multiplying by constants as in:
		// https://github.com/mrdoob/three.js/pull/16275/files
		vec3 constterm = c4 * SH_COEF(lc, uint(0)).rgb - c5 * SH_COEF(lc, uint(6)).rgb;
		vec3 shaX = 2.0 * c2 * SH_COEF(lc, uint(3)).rgb;
		vec3 shaY = 2.0 * c2 * SH_COEF(lc, uint(1)).rgb;
		vec3 shaZ = 2.0 * c2 * SH_COEF(lc, uint(2)).rgb;
		vec3 shbX = 2.0 * c1 * SH_COEF(lc, uint(4)).rgb;
		vec3 shbY = 2.0 * c1 * SH_COEF(lc, uint(5)).rgb;
		vec3 shbZ = c3 * SH_COEF(lc, uint(6)).rgb;
		vec3 shbW = 2.0 * c1 * SH_COEF(lc, uint(7)).rgb;
		vec3 shc = c1 * SH_COEF(lc, uint(8)).rgb;
		unity_SHAr = vec4(shaX.r, shaY.r, shaZ.r, constterm.r);
		unity_SHAg = vec4(shaX.g, shaY.g, shaZ.g, constterm.g);
		unity_SHAb = vec4(shaX.b, shaY.b, shaZ.b, constterm.b);
		unity_SHBr = vec4(shbX.r, shbY.r, shbZ.r, shbW.r);
		unity_SHBg = vec4(shbX.g, shbY.g, shbZ.g, shbW.g);
		unity_SHBb = vec4(shbX.b, shbY.b, shbZ.b, shbW.b);
		unity_SHC = vec4(shc, 0.0);
	} else {
		// Emulate L0&L1 Coefficients, assuming top-down lighting.

		// Indirect Light
		vec4 reflection_accum;
		vec4 ambient_accum;
		
		vec3 env_reflection_light = vec3(0.0);
		
		vec3 world_space_up = vec3(0.0,1.0,0.0);
		vec3 up_normal = mat3(INV_CAMERA_MATRIX) * world_space_up;

		vec3 ambient_light_up;
		vec3 diffuse_light_up;
		vec3 specular_light_up;
		reflection_accum = vec4(0.0, 0.0, 0.0, 0.0);
		ambient_accum = vec4(0.0, 0.0, 0.0, 0.0);
		AMBIENT_PROCESS(VERTEX, up_normal, ROUGHNESS, SPECULAR, false, VIEW, vec2(0.0), ambient_light_up, diffuse_light_up, specular_light_up);
		for (uint idx = uint(0); idx < REFLECTION_PROBE_COUNT(CLUSTER_CELL); idx++) {
			REFLECTION_PROCESS(CLUSTER_CELL, idx, VERTEX, up_normal, ROUGHNESS, ambient_light_up, specular_light_up, ambient_accum, reflection_accum);
		}
		if (ambient_accum.a > 0.0) {
			ambient_light_up = ambient_accum.rgb / ambient_accum.a;
		}
		
		
		vec3 ambient_light_down;
		vec3 diffuse_light_down;
		vec3 specular_light_down;
		reflection_accum = vec4(0.0, 0.0, 0.0, 0.0);
		ambient_accum = vec4(0.0, 0.0, 0.0, 0.0);
		AMBIENT_PROCESS(VERTEX, -up_normal, ROUGHNESS, SPECULAR, false, VIEW, vec2(0.0), ambient_light_down, diffuse_light_down, specular_light_down);
		for (uint idx = uint(0); idx < REFLECTION_PROBE_COUNT(CLUSTER_CELL); idx++) {
			REFLECTION_PROCESS(CLUSTER_CELL, idx, VERTEX, -up_normal, ROUGHNESS, ambient_light_down, specular_light_down, ambient_accum, reflection_accum);
		}
		if (ambient_accum.a > 0.0) {
			ambient_light_down = ambient_accum.rgb / ambient_accum.a;
		}
		vec3 const_term = mix(ambient_light_down, ambient_light_up, 0.5);
		vec3 delta_term = 0.5*(ambient_light_up - ambient_light_down);

		unity_SHAr = vec4(world_space_up * delta_term.r, const_term.r);
		unity_SHAg = vec4(world_space_up * delta_term.g, const_term.g);
		unity_SHAb = vec4(world_space_up * delta_term.b, const_term.b);
	}

	... code here ...

}