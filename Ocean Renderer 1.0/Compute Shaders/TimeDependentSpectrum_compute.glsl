#[compute]
#version 450

// For the read-write textures
layout(binding = 0, rg32f) coherent image2D Dx_Dz;
layout(binding = 1, rg32f) coherent image2D Dy_Dxz;
layout(binding = 2, rg32f) coherent image2D Dyx_Dyz;
layout(binding = 3, rg32f) coherent image2D Dxx_Dzz;

// For the read-only textures
layout(binding = 4) uniform sampler2D H0;
// wave vector x, 1 / magnitude, wave vector z, frequency
layout(binding = 5) uniform sampler2D WavesData;
uniform float Time;

vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

void main() {
    uvec2 id = gl_GlobalInvocationID.xy;
    vec4 wave = texture(WavesData, vec2(id) / vec2(imageSize(WavesData)));
    float phase = wave.w * Time;
    vec2 exponent = vec2(cos(phase), sin(phase));
    vec2 h = ComplexMult(texelFetch(H0, ivec2(id), 0).xy, exponent)
           + ComplexMult(texelFetch(H0, ivec2(id), 0).zw, vec2(exponent.x, -exponent.y));
    vec2 ih = vec2(-h.y, h.x);
    
	vec2 displacementX = ih * wave.x * wave.y;
	vec2 displacementY = h;
	vec2 displacementZ = ih * wave.z * wave.y;
		 
	vec2 displacementX_dx = -h * wave.x * wave.x * wave.y;
	vec2 displacementY_dx = ih * wave.x;
	vec2 displacementZ_dx = -h * wave.x * wave.z * wave.y;
		 
	vec2 displacementY_dz = ih * wave.z;
	vec2 displacementZ_dz = -h * wave.z * wave.z * wave.y;

    imageStore(Dx_Dz, ivec2(id), vec4(displacementX.x - displacementZ.y, displacementX.y + displacementZ.x, 0.0, 0.0));
    imageStore(Dy_Dxz, ivec2(id), vec4(displacementY.x - displacementZ_dx.y, displacementY.y + displacementZ_dx.x, 0.0, 0.0));
    imageStore(Dyx_Dyz, ivec2(id), vec4(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x, 0.0, 0.0));
    imageStore(Dxx_Dzz, ivec2(id), vec4(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x, 0.0, 0.0));
}


