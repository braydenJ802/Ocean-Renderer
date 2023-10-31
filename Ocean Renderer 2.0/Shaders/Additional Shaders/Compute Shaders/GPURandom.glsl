#[compute]
#version 450

//Quality hashes collection by nimitz 2018 (twitter: @stormoid)
// License details omitted for brevity

#if 1
//Modified from: iq's "Integer Hash - III" (https://www.shadertoy.com/view/4tXyWN)
//Faster than "full" xxHash and good quality
uint baseHash(uvec2 p)
{
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    return h32^(h32 >> 16);
}
#else
//XXHash32 based (https://github.com/Cyan4973/xxHash)
//Slower, higher quality
uint baseHash(uvec2 p)
{
    const uint PRIME32_2 = 2246822519U, PRIME32_3 = 3266489917U;
	const uint PRIME32_4 = 668265263U, PRIME32_5 = 374761393U;
    uint h32 = p.y + PRIME32_5 + p.x*PRIME32_3;
    h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17)));
    h32 = PRIME32_2*(h32^(h32 >> 15));
    h32 = PRIME32_3*(h32^(h32 >> 13));
    return h32^(h32 >> 16);
}
#endif

//---------------------2D input---------------------

float hash12(uvec2 x)
{
    uint n = baseHash(x);
    return float(n)*(1.0/float(0xffffffffU));
}

vec2 hash22(uvec2 x)
{
    uint n = baseHash(x);
    uvec2 rz = uvec2(n, n*48271U);
    return vec2((rz.xy >> 1) & uvec2(0x7fffffffU))/float(0x7fffffff);
}

vec3 hash32(uvec2 x)
{
    uint n = baseHash(x);
    uvec3 rz = uvec3(n, n*16807U, n*48271U);
    return vec3((rz >> 1) & uvec3(0x7fffffffU))/float(0x7fffffff);
}

vec4 hash42(uvec2 x)
{
    uint n = baseHash(x);
    uvec4 rz = uvec4(n, n*16807U, n*48271U, n*69621U);
    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
}

vec4 hash42(vec2 x)
{
    uint n = baseHash(floatBitsToUint(x));
    uvec4 rz = uvec4(n, n*16807U, n*48271U, n*69621U);
    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
}

//--------------------------------------------------

layout(set = 0, binding = 0) uniform Params {
    vec2 resolution;
};

layout(set = 0, binding = 1, rgba32f) writeonly uniform image2D outputImage;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
void main() {
    vec2 fragCoord = vec2(gl_GlobalInvocationID.xy);
    
    vec2 p = fragCoord / resolution;
    p.x *= resolution.x / resolution.y;
    
    // 2D input
    vec4 fragColor = hash42(uvec2(fragCoord));
    
    imageStore(outputImage, ivec2(fragCoord), fragColor);
}
