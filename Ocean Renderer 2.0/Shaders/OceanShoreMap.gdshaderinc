
#ifndef OCEAN_SHORE_MAP_INCLUDED
#define OCEAN_SHORE_MAP_INCLUDED

const float OCEAN_PI = 3.1415926535897932384626;

// Textures
uniform sampler2D Ocean_ShoreMap;

// Properties
uniform vec4 Ocean_ShoreMapPosition = vec4(0.0); 
uniform vec4 Ocean_ShoreMapRanges = vec4(0.0);
uniform vec4 Ocean_ShoreModulationValue = vec4(0.0);
uniform vec4 Ocean_ShoreModulationScale = vec4(0.0);

vec4 SampleShore(vec2 worldPosXZ) {
	#ifdef SHORE_ENABLED
	vec2 elevationUV = (worldPosXZ - Ocean_ShoreMapPosition.xz) / Ocean_ShoreMapPosition.w;
	elevationUV = (elevationUV + 1) * 0.5;
	vec4 val = textureLod(Ocean_ShoreMap, vec4(elevationUV, 0.0, 0.0, 0.0));
	val.x = mix(Ocean_ShoreMapRanges.x, Ocean_ShoreMapRanges.y, val.x);
	val.y = mix(Ocean_ShoreMapRanges.z, Ocean_ShoreMapRanges.w, val.y);
	val.zw = val.zw * 2.0 - 1.0;
	return val;
	#else
	return vec4(-1000.0, 0.0, 0.0, 0.0);
	#endif
}

vec4 ShoreModulation(float elevation) {
	return 1.0 - clamp(Ocean_ShoreModulationValue * clamp(1.0 + elevation / Ocean_ShoreModulationScale, 0.0, 1.0), 0.0, 1.0);
}
#endif