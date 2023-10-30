RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_s0ked ;         local://RDShaderFile_1x53s R         RDShaderSPIRV          �  Failed parse:
ERROR: 0:5: 'image2D' : sampler/image types can only be used in uniform variables or function parameters: H0
ERROR: 0:5: 'binding' : requires uniform or buffer storage qualifier 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		const float PI = 3.141592653589793238462643383279502884197;
4		
5		layout(binding = 0, rgba32f) coherent image2D H0;
6		layout(binding = 1, rgba32f) coherent image2D WavesData;
7		layout(binding = 2, rg32f) coherent image2D H0K;
8		
9		layout(binding = 3) uniform sampler2D Noise;
10		
11		uniform uint Size;
12		uniform float LengthScale;
13		uniform float CutoffHigh;
14		uniform float CutoffLow;
15		uniform float GravityAcceleration;
16		uniform float Depth;
17		
18		struct SpectrumParameters {
19		    float scale;
20		    float angle;
21		    float spreadBlend;
22		    float swell;
23		    float alpha;
24		    float peakOmega;
25		    float gamma;
26		    float shortWavesFade;
27		};
28		
29		layout(std140, binding = 4) buffer SpectrumParametersBuffer {
30		    SpectrumParameters Spectrums[];
31		};
32		
33		float Frequency(float k, float g, float depth) {
34		   
35		    return sqrt(g * k * tanh(min(k * depth, 20.0)));
36		
37		}
38		
39		
40		float FrequencyDerivative(float k, float g, float depth) {
41		   
42		    float th = tanh(min(k * depth, 20.0));
43		    float ch = cosh(k * depth);
44		    return g * (depth * k / ch / ch + th) / Frequency(k, g, depth) / 2.0;
45		
46		}
47		
48		
49		float NormalisationFactor(float s) {
50		
51		    float s2 = s * s;
52		    float s3 = s2 * s;
53		    float s4 = s3 * s;
54		    if (s < 5.0) {
55		        return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
56		    } else {
57		        return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
58		    }
59		
60		}
61		
62		
63		float DonelanBannerBeta(float x) {
64		
65		    if (x < 0.95) {
66		        return 2.61 * pow(abs(x), 1.3);
67		    }
68		    if (x < 1.6) {
69		        return 2.28 * pow(abs(x), -1.3);
70		    }
71		    float p = -0.4 + 0.8393 * exp(-0.567 * log(x * x));
72		    return pow(10.0, p);
73		
74		}
75		
76		
77		float DonelanBanner(float theta, float omega, float peakOmega) {
78		
79		    float beta = DonelanBannerBeta(omega / peakOmega);
80		    float sech = 1.0 / cosh(beta * theta);
81		    return beta / 2.0 / tanh(beta * 3.1416) * sech * sech;
82		
83		}
84		
85		
86		float Cosine2s(float theta, float s) {
87		    
88			return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2.0 * s);
89		
90		}
91		
92		
93		float SpreadPower(float omega, float peakOmega) {
94		
95		    if (omega > peakOmega) {
96		        return 9.77 * pow(abs(omega / peakOmega), -2.5);
97		    } else {
98		        return 6.97 * pow(abs(omega / peakOmega), 5.0);
99		    }
100		
101		}
102		
103		
104		float DirectionSpectrum(float theta, float omega, SpectrumParameters pars) {
105		
106		    float s = SpreadPower(omega, pars.peakOmega)
107		        + 16.0 * tanh(min(omega / pars.peakOmega, 20.0)) * pars.swell * pars.swell;
108		    return mix(2.0 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
109		
110		}
111		
112		
113		float TMACorrection(float omega, float g, float depth) {
114		
115		    float omegaH = omega * sqrt(depth / g);
116		    if (omegaH <= 1.0) {
117		        return 0.5 * omegaH * omegaH;
118		    }
119		    if (omegaH < 2.0) {
120		        return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
121		    }
122		    return 1.0;
123		
124		}
125		
126		
127		float JONSWAP(float omega, float g, float depth, SpectrumParameters pars) {
128		
129		    float sigma;
130		    if (omega <= pars.peakOmega)
131		        sigma = 0.07;
132		    else
133		        sigma = 0.09;
134		    float r = exp(-(omega - pars.peakOmega) * (omega - pars.peakOmega)
135		        / 2.0 / sigma / sigma / pars.peakOmega / pars.peakOmega);
136		    
137		    float oneOverOmega = 1.0 / omega;
138		    float peakOmegaOverOmega = pars.peakOmega / omega;
139		    return pars.scale * TMACorrection(omega, g, depth) * pars.alpha * g * g
140		        * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
141		        * exp(-1.25 * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
142		        * pow(abs(pars.gamma), r);
143		
144		}
145		
146		
147		float ShortWavesFade(float kLength, SpectrumParameters pars) {
148		
149		    return exp(-pars.shortWavesFade * pars.shortWavesFade * kLength * kLength);
150		
151		}
152		
153		
154		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
155		void CalculateInitialSpectrum() {
156		    uvec3 id = gl_GlobalInvocationID;
157		    float deltaK = 2 * PI / LengthScale;
158		    int nx = int(id.x) - int(Size) / 2;
159		    int nz = int(id.y) - int(Size) / 2;
160		    vec2 k = vec2(nx, nz) * deltaK;
161		    float kLength = length(k);
162		    
163		    if (kLength <= CutoffHigh && kLength >= CutoffLow) {
164		        float kAngle = atan(k.y, k.x);
165		        float omega = Frequency(kLength, GravityAcceleration, Depth);
166		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1 / kLength, k.y, omega));
167		        float dOmegadk = FrequencyDerivative(kLength, GravityAcceleration, Depth);
168		
169		        vec8 spectrumParams0 = Spectrums[0];
170		        float spectrum = JONSWAP(omega, GravityAcceleration, Depth, spectrumParams0)
171		            * DirectionSpectrum(kAngle, omega, spectrumParams0) * ShortWavesFade(kLength, spectrumParams0);
172		
173		        vec8 spectrumParams1 = Spectrums[1];
174		        if (spectrumParams1.x > 0) {
175		            spectrum += JONSWAP(omega, GravityAcceleration, Depth, spectrumParams1)
176		            * DirectionSpectrum(kAngle, omega, spectrumParams1) * ShortWavesFade(kLength, spectrumParams1);
177		        }
178		
179		        vec2 noiseSample = texture(Noise, vec2(id.xy) / vec2(Size)).xy;
180		        imageStore(H0K, ivec2(id.xy), vec2(noiseSample.x, noiseSample.y)
181		            * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK));
182		    }
183		    else {
184		        imageStore(H0K, ivec2(id.xy), vec2(0));
185		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1, k.y, 0));
186		    }
187		}
188		
189		
190		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
191		void CalculateConjugatedSpectrum() {
192		    uvec3 id = gl_GlobalInvocationID;
193		    vec2 h0K = imageLoad(H0K, ivec2(id.xy)).xy;
194		    vec2 h0MinusK = imageLoad(H0K, ivec2(uvec2((Size - id.x) % Size, (Size - id.y) % Size))).xy;
195		    imageStore(H0, ivec2(id.xy), vec4(h0K.x, h0K.y, h0MinusK.x, -h0MinusK.y));
196		}
197		
198		
199		void main() {
200		    // Choose which kernel to run based on some condition
201		    // (you would dispatch different compute shaders in practice)
202		    bool runInitial = true; // This is just an example, set this based on your actual use case
203		    if (runInitial) {
204		        CalculateInitialSpectrum();
205		    } else {
206		        CalculateConjugatedSpectrum();
207		    }
208		}
209		
210		
          RDShaderFile                                    RSRC