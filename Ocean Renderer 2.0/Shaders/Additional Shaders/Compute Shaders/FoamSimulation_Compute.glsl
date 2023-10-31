#[compute]
#version 450

layout(binding = 0, rgba32f) uniform image3D Turbulence; 
layout(binding = 1, rgba32f) uniform image3D InputTexture; 

layout(std140, binding = 2) uniform Params {
    uint CascadesCount;
    float DeltaTime;
    float FoamDecayRate;
    bool IsInitializing; //Controls whether we initialize or simulate in main
};

void SimulateForCascade(uvec3 id) {
    float Dxz = imageLoad(InputTexture, ivec3(id.xy, id.z * 2)).w;
    vec2 DxxDzz = imageLoad(InputTexture, ivec3(id.xy, id.z * 2 + 1)).zw;
    
    float jxx = 1 + DxxDzz.x;
    float jzz = 1 + DxxDzz.y;
    float jxz = Dxz;
    
    float jacobian = jxx * jzz - jxz * jxz;
    float jminus = 0.5 * (jxx + jzz) - 0.5 * sqrt((jxx - jzz) * (jxx - jzz) + 4 * jxz * jxz);
    
    float bias = 1;
    vec2 current = vec2(-jminus, - jacobian) + bias;
    vec2 persistent = imageLoad(Turbulence, ivec3(id)).zw;
    persistent -= FoamDecayRate * DeltaTime;
    persistent = max(current, persistent);

    imageStore(Turbulence, ivec3(id), vec4(current, persistent));
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void Simulate() {
    uvec2 id = gl_LocalInvocationID.xy;
    for (uint i = 0; i < CascadesCount; i++) {
        SimulateForCascade(uvec3(id, i));
    }
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void Initialize() {
    uvec2 id = gl_LocalInvocationID.xy;
    for (uint i = 0; i < CascadesCount; i++) {
        imageStore(Turbulence, ivec3(id, i), vec4(-5.0));
    }
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    if (IsInitializing) {
        Initialize();
    } else {
        Simulate();
    }
}



