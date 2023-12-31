RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_g2dbk ;         local://RDShaderFile_t44q0 �         RDShaderSPIRV          |  Failed parse:
ERROR: 0:29: '[]' : scalar integer expression required 
ERROR: 0:29: 'PrecomputeBuffer' :  left of '[' is not of type array, matrix, or vector  
ERROR: 0:29: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		const float PI = 3.14159265358979323846264338327950;
4		
5		layout(binding = 0, rgba32f) uniform image2D PrecomputeBuffer;
6		layout(binding = 1, rgba32f) readonly uniform image2D PrecomputedData;
7		layout(binding = 2, rg32f) uniform image2D Buffer0;
8		layout(binding = 3, rg32f) uniform image2D Buffer1;
9		
10		bool PingPong;
11		uint Step;
12		uint Size;
13		
14		vec2 ComplexMult(vec2 a, vec2 b) {
15		    return vec2(a.r * b.r - a.g * b.g, a.r * b.g + a.g * b.r);
16		}
17		
18		vec2 ComplexExp(vec2 a) {
19		    return vec2(cos(a.y), sin(a.y)) * exp(a.x);
20		}
21		
22		layout(local_size_x = 1, local_size_y = 8, local_size_z = 1) in;
23		void PrecomputeTwiddleFactorsAndInputIndices() {
24		    uvec3 id = gl_GlobalInvocationID;
25		    uint b = Size >> (id.x + 1);
26			vec2 mult = 2 * PI * vec2(0, 1) / Size;
27			uint i = (2 * b * (id.y / b) + id.y % b) % Size;
28			vec2 twiddle = ComplexExp(-mult * ((id.y / b) * b));
29			PrecomputeBuffer[id.xy] = vec4(twiddle.x, twiddle.y, i, i + b);
30			PrecomputeBuffer[uint2(id.x, id.y + Size / 2)] = vec4(-twiddle.x, -twiddle.y, i, i + b);
31		}
32		
33		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
34		void HorizontalStepFFT() {
35		    uvec3 id = gl_GlobalInvocationID;
36		    vec4 data = PrecomputedData[uint2(Step, id.x)];
37			uvec2 inputsIndices = uvec2(data.zw);
38			if (PingPong)
39			{
40				Buffer1[id.xy] = Buffer0[uint2(inputsIndices.x, id.y)]
41					+ ComplexMult(data.rg, Buffer0[uint2(inputsIndices.y, id.y)]);
42			}
43			else
44			{
45				Buffer0[id.xy] = Buffer1[uint2(inputsIndices.x, id.y)]
46					+ ComplexMult(data.rg, Buffer1[uint2(inputsIndices.y, id.y)]);
47			}
48		}
49		
50		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
51		void VerticalStepFFT() {
52		    uvec3 id = gl_GlobalInvocationID;
53		    vec4 data = PrecomputedData[uint2(Step, id.y)];
54			uvec2 inputsIndices = uvec2(data.zw);
55			if (PingPong)
56			{
57				Buffer1[id.xy] = Buffer0[uint2(id.x, inputsIndices.x)]
58					+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(id.x, inputsIndices.y)]);
59			}
60			else
61			{
62				Buffer0[id.xy] = Buffer1[uint2(id.x, inputsIndices.x)]
63					+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(id.x, inputsIndices.y)]);
64			}
65		}
66		
67		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
68		void HorizontalStepInverseFFT() {
69		    uvec3 id = gl_GlobalInvocationID;
70			vec4 data = PrecomputedData[uint2(Step, id.x)];
71			uvec2 inputsIndices = uvec2(data.zw);
72			if (PingPong)
73			{
74				Buffer1[id.xy] = Buffer0[uint2(inputsIndices.x, id.y)]
75					+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(inputsIndices.y, id.y)]);
76			}
77			else
78			{
79				Buffer0[id.xy] = Buffer1[uint2(inputsIndices.x, id.y)]
80					+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(inputsIndices.y, id.y)]);
81			}
82		}
83		
84		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
85		void VerticalStepInverseFFT() {
86		    uvec3 id = gl_GlobalInvocationID;
87			vec4 data = PrecomputedData[uint2(Step, id.y)];
88			uvec2 inputsIndices = uvec2(data.zw);
89			if (PingPong)
90			{
91				Buffer1[id.xy] = Buffer0[uint2(id.x, inputsIndices.x)]
92					+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(id.x, inputsIndices.y)]);
93			}
94			else
95			{
96				Buffer0[id.xy] = Buffer1[uint2(id.x, inputsIndices.x)]
97					+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(id.x, inputsIndices.y)]);
98			}
99		}
100		
101		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
102		void Scale() {
103		    uvec3 id = gl_GlobalInvocationID;
104		    Buffer0[id.xy] = Buffer0[id.xy] / Size / Size;
105		}
106		
107		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
108		void Permute() {
109		    uvec3 id = gl_GlobalInvocationID;
110			Buffer0[id.xy] = Buffer0[id.xy] * (1.0 - 2.0 * ((id.x + id.y) % 2));
111		}
112		
113		
          RDShaderFile                                    RSRC