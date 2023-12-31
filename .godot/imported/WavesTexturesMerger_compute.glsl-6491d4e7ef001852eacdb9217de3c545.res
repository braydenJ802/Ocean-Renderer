RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_t4ua6 ;         local://RDShaderFile_t7u6j �	         RDShaderSPIRV          ~  Failed parse:
ERROR: 0:4: 'image2D' : sampler/image types can only be used in uniform variables or function parameters: Displacement
ERROR: 0:4: 'binding' : requires uniform or buffer storage qualifier 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		// For the read-write textures
4		layout(binding = 0, rgba32f) coherent image2D Displacement; // float3 to vec4, but you'll just use the rgb channels.
5		layout(binding = 1, rgba32f) coherent image2D Derivatives;
6		layout(binding = 2, rgba32f) coherent image2D Turbulence;
7		
8		// For the read-only textures
9		layout(binding = 3) uniform sampler2D Dx_Dz; // float2 to vec2
10		layout(binding = 4) uniform sampler2D Dy_Dxz; // float2 to vec2
11		layout(binding = 5) uniform sampler2D Dyx_Dyz; // float2 to vec2
12		layout(binding = 6) uniform sampler2D Dxx_Dzz; // float2 to vec2
13		
14		float Lambda;
15		float DeltaTime;
16		
17		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
18		void FillResultTextures()
19		{
20		    uvec3 id = gl_GlobalInvocationID;
21		    vec2 DxDz = texture(Dx_Dz, id.xy / textureSize(Dx_Dz, 0));
22		    vec2 DyDxz = texture(Dy_Dxz, id.xy / textureSize(Dy_Dxz, 0));
23		    vec2 DyxDyz = texture(Dyx_Dyz, id.xy / textureSize(Dyx_Dyz, 0));
24		    vec2 DxxDzz = texture(Dxx_Dzz, id.xy / textureSize(Dxx_Dzz, 0));
25		    
26		    imageStore(Displacement, ivec2(id.xy), vec4(vec3(Lambda * DxDz.x, DyDxz.x, Lambda * DxDz.y), 0));
27		    imageStore(Derivatives, ivec2(id.xy), vec4(DyxDyz, DxxDzz * Lambda));
28		    
29		    float jacobian = (1 + Lambda * DxxDzz.x) * (1 + Lambda * DxxDzz.y) - Lambda * Lambda * DyDxz.y * DyDxz.y;
30		    vec4 turb = imageLoad(Turbulence, ivec2(id.xy));
31		    turb.r = turb.r + DeltaTime * 0.5 / max(jacobian, 0.5);
32		    turb.r = min(jacobian, turb.r);
33		    imageStore(Turbulence, ivec2(id.xy), turb);
34		}
35		
36		
          RDShaderFile                                    RSRC