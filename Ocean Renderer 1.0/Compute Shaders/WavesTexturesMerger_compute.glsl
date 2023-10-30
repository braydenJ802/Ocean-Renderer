#[compute]
#version 450

// For the read-write textures
layout(binding = 0, rgba32f) coherent image2D Displacement; // float3 to vec4, but you'll just use the rgb channels.
layout(binding = 1, rgba32f) coherent image2D Derivatives;
layout(binding = 2, rgba32f) coherent image2D Turbulence;

// For the read-only textures
layout(binding = 3) uniform sampler2D Dx_Dz; // float2 to vec2
layout(binding = 4) uniform sampler2D Dy_Dxz; // float2 to vec2
layout(binding = 5) uniform sampler2D Dyx_Dyz; // float2 to vec2
layout(binding = 6) uniform sampler2D Dxx_Dzz; // float2 to vec2

float Lambda;
float DeltaTime;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void FillResultTextures()
{
    uvec3 id = gl_GlobalInvocationID;
    vec2 DxDz = texture(Dx_Dz, id.xy / textureSize(Dx_Dz, 0));
    vec2 DyDxz = texture(Dy_Dxz, id.xy / textureSize(Dy_Dxz, 0));
    vec2 DyxDyz = texture(Dyx_Dyz, id.xy / textureSize(Dyx_Dyz, 0));
    vec2 DxxDzz = texture(Dxx_Dzz, id.xy / textureSize(Dxx_Dzz, 0));
    
    imageStore(Displacement, ivec2(id.xy), vec4(vec3(Lambda * DxDz.x, DyDxz.x, Lambda * DxDz.y), 0));
    imageStore(Derivatives, ivec2(id.xy), vec4(DyxDyz, DxxDzz * Lambda));
    
    float jacobian = (1 + Lambda * DxxDzz.x) * (1 + Lambda * DxxDzz.y) - Lambda * Lambda * DyDxz.y * DyDxz.y;
    vec4 turb = imageLoad(Turbulence, ivec2(id.xy));
    turb.r = turb.r + DeltaTime * 0.5 / max(jacobian, 0.5);
    turb.r = min(jacobian, turb.r);
    imageStore(Turbulence, ivec2(id.xy), turb);
}
