RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_wkv7q ;         local://RDShaderFile_tk80v &         RDShaderSPIRV          �  Failed parse:
ERROR: 0:15: 'non-opaque uniforms outside a block' : not allowed when using GLSL for Vulkan 
ERROR: 1 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
4		
5		const float PI = 3.14159265358979323846264338327950;
6		
7		//maybe use writeonly instead of coherent
8		layout(binding = 0, rgba32f) coherent uniform image2D H0; // Corresponding to RWTexture2D<float4> H0 in HLSL
9		layout(binding = 1, rgba32f) coherent uniform image2D WavesData; // Corresponding to RWTexture2D<float4> WavesData in HLSL
10		layout(binding = 2, rg32f) coherent uniform image2D H0K; // Corresponding to RWTexture2D<float2> H0K in HLSL
11		
12		layout(binding = 3, rg32f) readonly uniform image2D Noise; // Corresponding to Texture2D<float2> Noise in HLSL
13		
14		
15		uniform uint Size;
16		uniform float LengthScale;
17		uniform float CutoffHigh;
18		uniform float CutoffLow;
19		uniform float GravityAcceleration;
20		uniform float Depth;
21		
22		struct SpectrumParameters {
23		    float scale;
24		    float angle;
25		    float spreadBlend;
26		    float swell;
27		    float alpha;
28		    float peakOmega;
29		    float gamma;
30		    float shortWavesFade;
31		};
32		
33		layout(std430, binding = 4) buffer SpectrumBuffer {
34		    SpectrumParameters Spectrums[];
35		};
36		
37		
38		
39		float Frequency(float k, float g, float depth)
40		{
41			return sqrt(g * k * tanh(min(k * depth, 20)));
42		}
43		
44		float FrequencyDerivative(float k, float g, float depth)
45		{
46			float th = tanh(min(k * depth, 20));
47			float ch = cosh(k * depth);
48			return g * (depth * k / ch / ch + th) / Frequency(k, g, depth) / 2;
49		}
50		
51		float NormalisationFactor(float s)
52		{
53			float s2 = s * s;
54			float s3 = s2 * s;
55			float s4 = s3 * s;
56			if (s < 5)
57				return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
58			else
59				return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
60		}
61		
62		float DonelanBannerBeta(float x)
63		{
64			if (x < 0.95)
65				return 2.61 * pow(abs(x), 1.3);
66			if (x < 1.6)
67				return 2.28 * pow(abs(x), -1.3);
68			float p = -0.4 + 0.8393 * exp(-0.567 * log(x * x));
69			return pow(10, p);
70		}
71		
72		float DonelanBanner(float theta, float omega, float peakOmega)
73		{
74			float beta = DonelanBannerBeta(omega / peakOmega);
75			float sech = 1 / cosh(beta * theta);
76			return beta / 2 / tanh(beta * 3.1416) * sech * sech;
77		}
78		
79		float Cosine2s(float theta, float s)
80		{
81			return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2 * s);
82		}
83		
84		float SpreadPower(float omega, float peakOmega)
85		{
86			if (omega > peakOmega)
87			{
88				return 9.77 * pow(abs(omega / peakOmega), -2.5);
89			}
90			else
91			{
92				return 6.97 * pow(abs(omega / peakOmega), 5);
93			}
94		}
95		
96		float DirectionSpectrum(float theta, float omega, SpectrumParameters pars)
97		{
98			float s = SpreadPower(omega, pars.peakOmega)
99				+ 16 * tanh(min(omega / pars.peakOmega, 20)) * pars.swell * pars.swell;
100			return lerp(2 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
101		}
102		
103		float TMACorrection(float omega, float g, float depth)
104		{
105			float omegaH = omega * sqrt(depth / g);
106			if (omegaH <= 1)
107				return 0.5 * omegaH * omegaH;
108			if (omegaH < 2)
109				return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
110			return 1;
111		}
112		
113		float JONSWAP(float omega, float g, float depth, SpectrumParameters pars)
114		{
115			float sigma;
116			if (omega <= pars.peakOmega)
117				sigma = 0.07;
118			else
119				sigma = 0.09;
120			float r = exp(-(omega - pars.peakOmega) * (omega - pars.peakOmega)
121				/ 2 / sigma / sigma / pars.peakOmega / pars.peakOmega);
122			
123			float oneOverOmega = 1 / omega;
124			float peakOmegaOverOmega = pars.peakOmega / omega;
125			return pars.scale * TMACorrection(omega, g, depth) * pars.alpha * g * g
126				* oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
127				* exp(-1.25 * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
128				* pow(abs(pars.gamma), r);
129		}
130		
131		float ShortWavesFade(float kLength, SpectrumParameters pars)
132		{
133			return exp(-pars.shortWavesFade * pars.shortWavesFade * kLength * kLength);
134		}
135		
136		
137		void CalculateInitialSpectrum() {
138		    uvec3 id = gl_GlobalInvocationID;
139		    float deltaK = 2 * PI / LengthScale;
140		    int nx = int(id.x) - int(Size) / 2;
141		    int nz = int(id.y) - int(Size) / 2;
142		    vec2 k = vec2(nx, nz) * deltaK;
143		    float kLength = length(k);
144		    
145		    if (kLength <= CutoffHigh && kLength >= CutoffLow) {
146		        float kAngle = atan(k.y, k.x);
147		        float omega = Frequency(kLength, GravityAcceleration, Depth);
148		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1 / kLength, k.y, omega));
149		        float dOmegadk = FrequencyDerivative(kLength, GravityAcceleration, Depth);
150		
151		        float spectrum = JONSWAP(omega, GravityAcceleration, Depth, Spectrums[0])
152		            * DirectionSpectrum(kAngle, omega, Spectrums[0]) * ShortWavesFade(kLength, Spectrums[0]);
153		        if (Spectrums[1].scale > 0) {
154		           
155				    spectrum += JONSWAP(omega, GravityAcceleration, Depth, Spectrums[1])
156		            * DirectionSpectrum(kAngle, omega, Spectrums[1]) * ShortWavesFade(kLength, Spectrums[1]);
157		
158				}
159		
160		        vec4 NoiseSample = imageLoad(Noise, ivec2(id.xy));
161		        imageStore(H0K, ivec2(id.xy), vec4(NoiseSample.x, NoiseSample.y, 0.0, 0.0) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK));
162		    }
163		    else {
164		        imageStore(H0K, ivec2(id.xy), vec4(0.0));
165		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1, k.y, 0));
166		    }
167		}
168		
169		void CalculateConjugatedSpectrum() {
170		    uvec3 id = gl_GlobalInvocationID;
171		    vec4 h0K = imageLoad(H0K, ivec2(id.xy));
172		    vec4 h0MinusK = imageLoad(H0K, ivec2((Size - id.x) % Size, (Size - id.y) % Size));
173		    imageStore(H0, ivec2(id.xy), vec4(h0K.x, h0K.y, h0MinusK.x, -h0MinusK.y));
174		}
175		
176		
177		
178		
179		
180		
          RDShaderFile                                    RSRC