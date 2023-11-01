#[compute]
#version 450

#define PI 3.14159265358979323846264338327950288419716939937510

layout(binding = 0, rgba32f) uniform image3D Result;

layout(binding = 1) uniform sampler2DArray H0;
layout(binding = 2) uniform sampler2DArray WavesData;

layout(push_constant) uniform Params {
    uint CascadesCount;
    float Time;
} params;

vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void CalculateForCascade(uvec3 id) {
    vec4 wave = texture(WavesData, vec3(id.xy, id.z));
    
    float phase = wave.w * params.Time;
    vec2 exponent = vec2(cos(phase), sin(phase));
    vec4 h0 = texture(H0, vec3(id.xy, id.z));
    vec2 h = ComplexMult(h0.xy, exponent)
        + ComplexMult(h0.zw, vec2(exponent.x, -exponent.y));
    vec2 ih = vec2(-h.y, h.x);
    
    float oneOverKLength = 1 / max(0.001, length(wave.xz));
    
    float lambda = wave.y;
    vec2 displacementX = lambda * ih * wave.x * oneOverKLength;
    vec2 displacementY = h;
    vec2 displacementZ = lambda * ih * wave.z * oneOverKLength;
    
    vec2 displacementX_dx = -lambda * h * wave.x * wave.x * oneOverKLength;
    vec2 displacementY_dx = ih * wave.x;
    vec2 displacementZ_dx = -lambda * h * wave.x * wave.z * oneOverKLength;
         
    vec2 displacementY_dz = ih * wave.z;
    vec2 displacementZ_dz = -lambda * h * wave.z * wave.z * oneOverKLength;
    
    imageStore(Result, ivec3(id.xy, id.z * 2), vec4(vec2(displacementX.x - displacementY.y, displacementX.y + displacementY.x),
                                          vec2(displacementZ.x - displacementZ_dx.y, displacementZ.y + displacementZ_dx.x)));
    imageStore(Result, ivec3(id.xy, id.z * 2 + 1), vec4(vec2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x),
                                             vec2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x)));
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    uvec3 id = gl_GlobalInvocationID.xyz;
    for (uint i = 0; i < params.CascadesCount; i++) {
        CalculateForCascade(uvec3(id.xy, i));
    }
}

//------------END OF SHADER----------------------

//-----------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------

//----------CHATGPT EVALUATION OF The Translation------------------------

// Upon reviewing the translated GLSL shader against the original HLSL shader, it appears that the translation has been done accurately, preserving the functionality and intent of the original HLSL shader. Here are some key points noted:

// Data Types & Variables: The data types and variable names have been translated correctly from HLSL to GLSL. For instance, float2 and float4 have been correctly translated to vec2 and vec4, respectively.

// Texture and Image Handling:

// The RWTexture2DArray<float4> Result; has been correctly translated to layout(binding = 0, rgba32f) uniform image3D Result;.
// The Texture2DArray<float4> H0; and Texture2DArray<float4> WavesData; have been translated to layout(binding = 1) uniform sampler2DArray H0; and layout(binding = 2) uniform sampler2DArray WavesData; respectively, which are accurate translations.
// Constant Buffers: The cbuffer Params has been translated to layout(push_constant) uniform Params which is the correct way to handle constant buffers in GLSL.

// Functionality:

// The ComplexMult function has been translated accurately.
// The CalculateForCascade function, which carries out the bulk of the computations, has been translated accurately.
// The main compute shader function CalculateAmplitudes has been translated to main in GLSL, and its functionality has been preserved.
// Thread Dispatching: The [numthreads(8,8,1)] directive has been translated to layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in; which is the correct translation in GLSL.

// Mathematical Operations: All mathematical operations and function calls within the shader functions appear to have been translated accurately.

// Precision of PI: The precision of PI has been increased in the GLSL version, which is good for maintaining accuracy in calculations.

// In summary, the translation from HLSL to GLSL has been done correctly and should provide the same functionality as the original HLSL shader. The GLSL shader should now compile and run as expected in Godot's shader environment.

//-----------------------------------------------------------------------

//----------------ORIGINAL HLSL CODE---------------------

// #pragma kernel CalculateAmplitudes

// #define PI 3.1415926

// // DxDyDzDxz, DyxDyzDxxDzz for each cascade
// RWTexture2DArray<float4> Result;

// Texture2DArray<float4> H0;
// // wave vector x, chop, wave vector z, frequency
// Texture2DArray<float4> WavesData;

// cbuffer Params
// {
// 	uint CascadesCount;
// 	float Time;
// };



// float2 ComplexMult(float2 a, float2 b)
// {
// 	return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
// }

// void CalculateForCascade(uint3 id)
// {
// 	float4 wave = WavesData[id];
	
// 	float phase = wave.w * Time;
// 	float2 exponent = float2(cos(phase), sin(phase));
// 	float4 h0 = H0[id];
// 	float2 h = ComplexMult(h0.xy, exponent)
// 		+ ComplexMult(h0.zw, float2(exponent.x, -exponent.y));
// 	float2 ih = float2(-h.y, h.x);
	
// 	float oneOverKLength = 1 / max(0.001, length(wave.xz));
	
// 	float lambda = wave.y;
// 	float2 displacementX = lambda * ih * wave.x * oneOverKLength;
// 	float2 displacementY = h;
// 	float2 displacementZ = lambda * ih * wave.z * oneOverKLength;
	
// 	float2 displacementX_dx = -lambda * h * wave.x * wave.x * oneOverKLength;
// 	float2 displacementY_dx = ih * wave.x;
// 	float2 displacementZ_dx = -lambda * h * wave.x * wave.z * oneOverKLength;
		 
// 	float2 displacementY_dz = ih * wave.z;
// 	float2 displacementZ_dz = -lambda * h * wave.z * wave.z * oneOverKLength;
	
// 	Result[uint3(id.xy, id.z * 2)] = float4(float2(displacementX.x - displacementY.y, displacementX.y + displacementY.x),
// 							  float2(displacementZ.x - displacementZ_dx.y, displacementZ.y + displacementZ_dx.x));
// 	Result[uint3(id.xy, id.z * 2 + 1)] = float4(float2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x),
// 								 float2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x));
// }

// [numthreads(8,8,1)]
// void CalculateAmplitudes(uint3 id : SV_DispatchThreadID)
// {
// 	for (uint i = 0; i < CascadesCount; i++)
// 	{
// 		CalculateForCascade(uint3(id.xy, i));
// 	}
// }

