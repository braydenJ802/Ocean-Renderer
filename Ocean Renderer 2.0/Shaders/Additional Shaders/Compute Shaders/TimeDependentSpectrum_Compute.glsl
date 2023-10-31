#[compute]
#version 450

#define PI 3.141592653589793238462643383279502884197169

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
