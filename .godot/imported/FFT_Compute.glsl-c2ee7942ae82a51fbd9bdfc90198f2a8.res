RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_rdgm6 ;         local://RDShaderFile_bjao8          RDShaderSPIRV          �  Failed parse:
ERROR: 0:24: 'image2D' : sampler/image types can only be used in uniform variables or function parameters: Target
ERROR: 0:24: 'binding' : requires uniform or buffer storage qualifier 
ERROR: 0:24: '' : missing #endif 
ERROR: 3 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		#define FFT_SIZE_256 // Adjust this define as needed
4		
5		#if defined(FFT_SIZE_512)
6		#define SIZE 512
7		#define LOG_SIZE 9
8		#elif defined(FFT_SIZE_256)
9		#define SIZE 256
10		#define LOG_SIZE 8
11		#elif defined(FFT_SIZE_128)
12		#define SIZE 128
13		#define LOG_SIZE 7
14		#else
15		#define SIZE 64
16		#define LOG_SIZE 6
17		#endif
18		
19		const uint Size = SIZE;
20		
21		#ifdef FFT_ARRAY_TARGET
22		layout(binding = 0, rgba32f) coherent image3D Target;
23		#else
24		layout(binding = 0, rgba32f) coherent image2D Target;
25		#endif
26		
27		layout(std140, binding = 1) uniform Params {
28			uint TargetsCount;
29			bool Direction;
30			bool Inverse;
31			bool Scale;
32			bool Permute;
33		};
34		
35		shared vec4 buffer[2][SIZE];
36		
37		vec2 ComplexMult(vec2 a, vec2 b) {
38			return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
39		}
40		
41		void ButterflyValues(uint step, uint index, out uvec2 indices, out vec2 twiddle) {
42			const float twoPi = 6.28318530718;
43			uint b = Size >> (step + 1);
44			uint w = b * (index / b);
45			uint i = (w + index) % Size;
46			float s, c;
47			sincos(-twoPi / float(Size) * float(w), s, c);
48			twiddle = vec2(c, s);
49			if (Inverse)
50				twiddle.y = -twiddle.y;
51			indices = uvec2(i, i + b);
52		}
53		
54		vec4 DoFft(uint threadIndex, vec4 input) {
55			buffer[0][threadIndex] = input;
56			barrier();
57			bool flag = false;
58		
59			for (uint step = 0; step < LOG_SIZE; step++) {
60				uvec2 inputsIndices;
61				vec2 twiddle;
62				ButterflyValues(step, threadIndex, inputsIndices, twiddle);
63		
64				vec4 v = buffer[flag][inputsIndices.y];
65				buffer[!flag][threadIndex] = buffer[flag][inputsIndices.x]
66					+ vec4(ComplexMult(twiddle, v.xy), ComplexMult(twiddle, v.zw));
67				flag = !flag;
68				barrier();
69			}
70		
71			return buffer[flag][threadIndex];
72		}
73		
74		layout(local_size_x = SIZE, local_size_y = 1, local_size_z = 1) in;
75		void Fft() {
76			uint threadIndex = gl_LocalInvocationID.x;
77			uvec2 targetIndex;
78			if (Direction)
79				targetIndex = gl_WorkGroupID.yx;
80			else
81				targetIndex = gl_WorkGroupID.xy;
82		
83		#ifdef FFT_ARRAY_TARGET
84			for (uint k = 0; k < TargetsCount; k++) {
85				imageStore(Target, ivec3(targetIndex, k), DoFft(threadIndex, imageLoad(Target, ivec3(targetIndex, k))));
86			}
87		#else
88			imageStore(Target, ivec2(targetIndex), DoFft(threadIndex, imageLoad(Target, ivec2(targetIndex))));
89		#endif
90		}
91		
92		vec4 DoPostProcess(vec4 input, uvec2 id) {
93			if (Scale)
94				input /= float(Size * Size);
95			if (Permute)
96				input *= 1.0 - 2.0 * float((id.x + id.y) % 2);
97			return input;
98		}
99		
100		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
101		void PostProcess() {
102		#ifdef FFT_ARRAY_TARGET
103			for (uint i = 0; i < TargetsCount; i++) {
104				uvec2 id = gl_LocalInvocationID.xy;
105				imageStore(Target, ivec3(id, i), DoPostProcess(imageLoad(Target, ivec3(id, i)), id));
106			}
107		#else
108			uvec2 id = gl_LocalInvocationID.xy;
109			imageStore(Target, ivec2(id), DoPostProcess(imageLoad(Target, ivec2(id)), id));
110		#endif
111		}
112		
113		
          RDShaderFile                                    RSRC