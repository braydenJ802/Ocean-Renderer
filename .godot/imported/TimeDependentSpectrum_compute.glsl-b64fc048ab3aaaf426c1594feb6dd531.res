RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_s5nhj ;         local://RDShaderFile_k6gxq �         RDShaderSPIRV          ~	  Failed parse:
ERROR: 0:4: 'image2D' : sampler/image types can only be used in uniform variables or function parameters: Dx_Dz
ERROR: 0:4: 'binding' : requires uniform or buffer storage qualifier 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		// For the read-write textures
4		layout(binding = 0, rg32f) coherent image2D Dx_Dz;
5		layout(binding = 1, rg32f) coherent image2D Dy_Dxz;
6		layout(binding = 2, rg32f) coherent image2D Dyx_Dyz;
7		layout(binding = 3, rg32f) coherent image2D Dxx_Dzz;
8		
9		// For the read-only textures
10		layout(binding = 4) uniform sampler2D H0;
11		// wave vector x, 1 / magnitude, wave vector z, frequency
12		layout(binding = 5) uniform sampler2D WavesData;
13		uniform float Time;
14		
15		vec2 ComplexMult(vec2 a, vec2 b) {
16		    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
17		}
18		
19		// Invocations in the (x, y, z) dimension
20		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
21		
22		void main() {
23		    uvec2 id = gl_GlobalInvocationID.xy;
24		    vec4 wave = texture(WavesData, vec2(id) / vec2(imageSize(WavesData)));
25		    float phase = wave.w * Time;
26		    vec2 exponent = vec2(cos(phase), sin(phase));
27		    vec2 h = ComplexMult(texelFetch(H0, ivec2(id), 0).xy, exponent)
28		           + ComplexMult(texelFetch(H0, ivec2(id), 0).zw, vec2(exponent.x, -exponent.y));
29		    vec2 ih = vec2(-h.y, h.x);
30		    
31			vec2 displacementX = ih * wave.x * wave.y;
32			vec2 displacementY = h;
33			vec2 displacementZ = ih * wave.z * wave.y;
34				 
35			vec2 displacementX_dx = -h * wave.x * wave.x * wave.y;
36			vec2 displacementY_dx = ih * wave.x;
37			vec2 displacementZ_dx = -h * wave.x * wave.z * wave.y;
38				 
39			vec2 displacementY_dz = ih * wave.z;
40			vec2 displacementZ_dz = -h * wave.z * wave.z * wave.y;
41		
42		    imageStore(Dx_Dz, ivec2(id), vec4(displacementX.x - displacementZ.y, displacementX.y + displacementZ.x, 0.0, 0.0));
43		    imageStore(Dy_Dxz, ivec2(id), vec4(displacementY.x - displacementZ_dx.y, displacementY.y + displacementZ_dx.x, 0.0, 0.0));
44		    imageStore(Dyx_Dyz, ivec2(id), vec4(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x, 0.0, 0.0));
45		    imageStore(Dxx_Dzz, ivec2(id), vec4(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x, 0.0, 0.0));
46		}
47		
48		
49		
50		
          RDShaderFile                                    RSRC