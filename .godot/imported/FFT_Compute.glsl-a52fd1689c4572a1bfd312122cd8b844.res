RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_3qkay ;         local://RDShaderFile_pdaki Y         RDShaderSPIRV          �  Failed parse:
ERROR: 0:18: 'static' : Reserved word. 
ERROR: 0:18: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		
4		#if defined(FFT_SIZE_512)
5		#define SIZE 512
6		#define LOG_SIZE 9
7		#elif defined(FFT_SIZE_256)
8		#define SIZE 256
9		#define LOG_SIZE 8
10		#elif defined(FFT_SIZE_128)
11		#define SIZE 128
12		#define LOG_SIZE 7
13		#else
14		#define SIZE 64
15		#define LOG_SIZE 6
16		#endif
17		
18		static uint Size = SIZE;
19		
20		#ifdef FFT_ARRAY_TARGET
21		RWTexture2DArray<float4> Target;
22		#else
23		RWTexture2D<float4> Target;
24		#endif
25		
26		cbuffer Params
27		{
28			uint TargetsCount;
29			bool Direction;
30			bool Inverse;
31			bool Scale;
32			bool Permute;
33		};
34		
35		groupshared float4 buffer[2][SIZE];
36		
37		vec2 ComplexMult(vec2 a, vec2 b)
38		{
39			return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
40		}
41		
42		void ButterflyValues(uint step, uint index, out uint2 indices, out vec2 twiddle)
43		{
44			const float twoPi = 6.28318530718;
45			uint b = Size >> (step + 1);
46			uint w = b * (index / b);
47			uint i = (w + index) % Size;
48			sincos(-twoPi / Size * w, twiddle.y, twiddle.x);
49			if (Inverse)
50				twiddle.y = -twiddle.y;
51			indices = uint2(i, i + b);
52		}
53		
54		float4 DoFft(uint threadIndex, float4 input)
55		{
56			buffer[0][threadIndex] = input;
57			GroupMemoryBarrierWithGroupSync();
58			bool flag = false;
59			
60			[unroll(LOG_SIZE)]
61			for (uint step = 0; step < LOG_SIZE; step++)
62			{
63				uint2 inputsIndices;
64				vec2 twiddle;
65				ButterflyValues(step, threadIndex, inputsIndices, twiddle);
66				
67				float4 v = buffer[flag][inputsIndices.y];
68				buffer[!flag][threadIndex] = buffer[flag][inputsIndices.x]
69					+ float4(ComplexMult(twiddle, v.xy), ComplexMult(twiddle, v.zw));
70				flag = !flag;
71				GroupMemoryBarrierWithGroupSync();
72			}
73			
74			return buffer[flag][threadIndex];
75		}
76		
77		[numthreads(SIZE, 1, 1)]
78		void Fft(uint3 id : SV_DispatchThreadID)
79		{
80			uint threadIndex = id.x;
81			uint2 targetIndex;
82			if (Direction)
83				targetIndex = id.yx;
84			else
85				targetIndex = id.xy;
86			
87		#ifdef FFT_ARRAY_TARGET
88			for (uint k = 0; k < TargetsCount; k++)
89			{
90				Target[uint3(targetIndex, k)] = DoFft(threadIndex, Target[uint3(targetIndex, k)]);
91			}
92		#else
93			Target[targetIndex] = DoFft(threadIndex, Target[targetIndex]);
94		#endif
95		}
96		
97		float4 DoPostProcess(float4 input, uint2 id)
98		{
99			if (Scale)
100				input /= Size * Size;
101			if (Permute)
102				input *= 1.0 - 2.0 * ((id.x + id.y) % 2);
103			return input;
104		}
105		
106		[numthreads(8, 8, 1)]
107		void PostProcess(uint3 id : SV_DispatchThreadID)
108		{
109		#ifdef FFT_ARRAY_TARGET
110			for (uint i = 0; i < TargetsCount; i++)
111			{
112				Target[uint3(id.xy, i)] = DoPostProcess(Target[uint3(id.xy, i)], id.xy);
113			}
114		#else
115			Target[id.xy] = DoPostProcess(Target[id.xy], id.xy);
116		#endif
117		}
118		
119		
          RDShaderFile                                    RSRC