#ifndef GEO_CLIP_MAP_INCLUDED
#define GEO_CLIP_MAP_INCLUDED

uniform float ClipMap_Scale = 1.0;
uniform float ClipMap_LevelHalfSize = .5;
uniform vec3 ClipMap_ViewerPosition = vec3(0.0);

float ModifiedManhattanDistance(vec3 a, vec3 b)
{
	vec3 v = a - b;
	return max(abs(v.x + v.z) + abs(v.x - v.z), abs(v.y)) * 0.5;
}

vec3 ClipMapVertex(vec3 positionOS, vec2 uv)
{
    vec3 morphOffset = vec3(uv.x, 0, uv.y);
    positionOS *= ClipMap_Scale;
    float meshScale = positionOS.y;
	float step = meshScale * 4.0;

	vec3 snappedViewerPos = vec3(floor(ClipMap_ViewerPosition.x / step) * step, 0, floor(ClipMap_ViewerPosition.z / step) * step);
    vec3 worldPos = vec3(snappedViewerPos.x + positionOS.x, 0, snappedViewerPos.z + positionOS.z);

	float morphStart = ((ClipMap_LevelHalfSize + 1.0) * 0.5 + 8.0) * meshScale;
	float morphEnd = (ClipMap_LevelHalfSize - 2.0) * meshScale;

	float t = clamp((ModifiedManhattanDistance(worldPos, ClipMap_ViewerPosition) - morphStart) / (morphEnd - morphStart), 0.0, 1.0);

	worldPos += morphOffset * meshScale * t;
	return worldPos;
}
#endif