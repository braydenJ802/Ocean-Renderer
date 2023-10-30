RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_b5j0h ;         local://RDShaderFile_lpdku �	         RDShaderSPIRV          H  Failed parse:
ERROR: 0:3: 'image3D' : sampler/image types can only be used in uniform variables or function parameters: Turbulence
ERROR: 0:3: 'binding' : requires uniform or buffer storage qualifier 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		layout(binding = 0, rgba32f) coherent image3D Turbulence; 
4		layout(binding = 1, rgba32f) coherent image3D Input; 
5		
6		layout(std140, binding = 2) uniform Params {
7		    uint CascadesCount;
8		    float DeltaTime;
9		    float FoamDecayRate;
10		};
11		
12		void SimulateForCascade(uvec3 id) {
13		    float Dxz = imageLoad(Input, ivec3(id.xy, id.z * 2)).w;
14		    vec2 DxxDzz = imageLoad(Input, ivec3(id.xy, id.z * 2 + 1)).zw;
15		    
16		    float jxx = 1 + DxxDzz.x;
17		    float jzz = 1 + DxxDzz.y;
18		    float jxz = Dxz;
19		    
20		    float jacobian = jxx * jzz - jxz * jxz;
21		    float jminus = 0.5 * (jxx + jzz) - 0.5 * sqrt((jxx - jzz) * (jxx - jzz) + 4 * jxz * jxz);
22		    
23		    float bias = 1;
24		    vec2 current = vec2(-jminus, - jacobian) + bias;
25		    vec2 persistent = imageLoad(Turbulence, ivec3(id)).zw;
26		    persistent -= FoamDecayRate * DeltaTime;
27		    persistent = max(current, persistent);
28		
29		    imageStore(Turbulence, ivec3(id), vec4(current, persistent));
30		}
31		
32		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
33		void Simulate() {
34		    uvec2 id = gl_LocalInvocationID.xy;
35		    for (uint i = 0; i < CascadesCount; i++) {
36		        SimulateForCascade(uvec3(id, i));
37		    }
38		}
39		
40		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
41		void Initialize() {
42		    uvec2 id = gl_LocalInvocationID.xy;
43		    for (uint i = 0; i < CascadesCount; i++) {
44		        imageStore(Turbulence, ivec3(id, i), vec4(-5.0));
45		    }
46		}
47		
48		
          RDShaderFile                                    RSRC