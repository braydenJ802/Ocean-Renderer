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

//--------------------------------------------------

//Example taking an arbitrary float value as input
vec4 hash42(vec2 x)
{
    uint n = baseHash(floatBitsToUint(x));
    uvec4 rz = uvec4(n, n*16807U, n*48271U, n*69621U);
    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    vec2 p = fragCoord/resolution.xy;
    p.x *= resolution.x/resolution.y;
    
    //float input
    //fragColor = hash42(p);
    
    //2D input
    fragColor = hash42(uvec2(fragCoord));
    
    //1D input
    //fragColor = hash41(uint(fragCoord.x + fragCoord.y*900.));
    
    //3D input
    //fragColor = hash43(uvec3(fragCoord.xy, uint(fragCoord.y)*0xffffU));
}

//Me to (ChatGPT with Bing):
// You said that this was closer to a fragment shader than a compute shader and I see your point. If I'm using this in Godot 4, should I try to make this a compute shader as we've done (which will not need any modifications because Godot runs compute shaders in GLSL 450 directly), or make this a Godot Shader Include file?


//(ChatGPT with Bing) to Me:
// The decision between using a compute shader or a shader include file in Godot largely depends on your specific use case and workflow within Godot 4.0.

// Here are some considerations that might help you decide:

// Compute Shader:
// Compute shaders in Godot 4.0 allow for more general-purpose computing and are particularly suited for tasks that require processing large data sets or performing computations that don't directly relate to rendering.
// If your hashing functions are part of a larger GPGPU (General-Purpose computing on Graphics Processing Units) workflow, or if they need to process data in a way that isn't directly related to rendering, a compute shader might be the right choice.
// Compute shaders can be more efficient for certain types of calculations due to their ability to handle data in parallel and manage memory in a more flexible manner.
// Shader Include File:
// Shader include files in Godot are a way to share common shader code across multiple shader programs. This can be a more organized and cleaner way to manage your shader code if these hashing functions are going to be used in multiple places across your project.
// If your hashing functions are going to be used primarily in the context of rendering – for example, as part of a fragment shader that's generating procedural textures – using a shader include file might be more straightforward.
// Shader include files can help keep your code DRY (Don't Repeat Yourself), which can be beneficial for maintenance and readability.
// In summary:

// If your hashing functions are part of a larger computational task that's well-suited to GPGPU workflows, a compute shader might be the right choice.
// If your hashing functions are going to be used across multiple shader programs primarily in the context of rendering, a shader include file could be a more organized and maintainable solution.
// Whichever route you choose, the GLSL code you have should be compatible with Godot 4.0's shading language for either a compute shader or a shader include file, as Godot's shading language is based on a subset of GLSL 450.