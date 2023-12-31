RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_a54qf ;         local://RDShaderFile_n4kpx 1         RDShaderSPIRV          �  Failed parse:
ERROR: 0:3: '' :  syntax error, unexpected IDENTIFIER
ERROR: 1 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		RWTexture2DArray<float4> Turbulence;
4		// DxDyDzDxz, DyxDyzDxxDzz for each cascade
5		RWTexture2DArray<float4> Input;
6		
7		cbuffer Params
8		{
9		    uint CascadesCount;
10		    float DeltaTime;
11		    float FoamDecayRate;
12		};
13		
14		
15		void SimulateForCascade(uint3 id)
16		{
17			float Dxz = Input[uint3(id.xy, id.z * 2)].w;
18			vec2 DxxDzz = Input[uint3(id.xy, id.z * 2 + 1)].zw;
19			
20			float jxx = 1 + DxxDzz.x;
21			float jzz = 1 + DxxDzz.y;
22			float jxz = Dxz;
23			
24			float jacobian = jxx * jzz - jxz * jxz;
25			float jminus = 0.5 * (jxx + jzz) - 0.5 * sqrt((jxx - jzz) * (jxx - jzz) + 4 * jxz * jxz);
26			
27			float bias = 1;
28			vec2 current = vec2(-jminus, - jacobian) + bias;
29			vec2 persistent = Turbulence[id].zw;
30			persistent -= FoamDecayRate * DeltaTime;
31			persistent = max(current, persistent);
32		
33			Turbulence[id] = float4(current, persistent);
34		}
35		
36		[numthreads(8, 8, 1)]
37		void Simulate(uint3 id : SV_DispatchThreadID)
38		{
39			for (uint i = 0; i < CascadesCount; i++)
40			{
41				SimulateForCascade(uint3(id.xy, i));
42			}
43		}
44		
45		[numthreads(8, 8, 1)]
46		void Initialize(uint3 id : SV_DispatchThreadID)
47		{
48			for (uint i; i < CascadesCount; i++)
49			{
50				Turbulence[uint3(id.xy, i)] = -5;
51			}
52		}
53		
54		
55		
          RDShaderFile                                    RSRC