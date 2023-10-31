RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_2wwgf ;         local://RDShaderFile_40deh +         RDShaderSPIRV          �  Failed parse:
ERROR: 0:148: 'imageStore' : no matching overloaded function found 
ERROR: 0:148: '' : compilation terminated 
ERROR: 2 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		const float PI = 3.141592653589793238462643383279502884197;
4		
5		layout(binding = 0, rgba32f) uniform image2D H0;
6		layout(binding = 1, rgba32f) uniform image2D WavesData;
7		layout(binding = 2, rg32f) uniform image2D H0K;
8		layout(binding = 3) uniform sampler2D Noise;
9		
10		layout(set = 0, binding = 4) uniform ParamsBlock {
11		    uint Size;
12		    float LengthScale;
13		    float CutoffHigh;
14		    float CutoffLow;
15		    float GravityAcceleration;
16		    float Depth;
17		} params;
18		
19		struct SpectrumParameters {
20		    float scale;
21		    float angle;
22		    float spreadBlend;
23		    float swell;
24		    float alpha;
25		    float peakOmega;
26		    float gamma;
27		    float shortWavesFade;
28		};
29		
30		layout(std140, binding = 5) buffer SpectrumParametersBuffer {
31		    SpectrumParameters Spectrums[];
32		};
33		
34		float Frequency(float k, float g, float depth) {
35		    return sqrt(g * k * tanh(min(k * depth, 20.0)));
36		}
37		
38		float FrequencyDerivative(float k, float g, float depth) {
39		    float th = tanh(min(k * depth, 20.0));
40		    float ch = cosh(k * depth);
41		    return g * (depth * k / ch / ch + th) / Frequency(k, g, depth) / 2.0;
42		}
43		
44		float NormalisationFactor(float s) {
45		    float s2 = s * s;
46		    float s3 = s2 * s;
47		    float s4 = s3 * s;
48		    if (s < 5.0) {
49		        return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
50		    } else {
51		        return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
52		    }
53		}
54		
55		float DonelanBannerBeta(float x) {
56		    if (x < 0.95) {
57		        return 2.61 * pow(abs(x), 1.3);
58		    }
59		    if (x < 1.6) {
60		        return 2.28 * pow(abs(x), -1.3);
61		    }
62		    float p = -0.4 + 0.8393 * exp(-0.567 * log(x * x));
63		    return pow(10.0, p);
64		}
65		
66		float DonelanBanner(float theta, float omega, float peakOmega) {
67		    float beta = DonelanBannerBeta(omega / peakOmega);
68		    float sech = 1.0 / cosh(beta * theta);
69		    return beta / 2.0 / tanh(beta * 3.1416) * sech * sech;
70		}
71		
72		float Cosine2s(float theta, float s) {
73		    return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2.0 * s);
74		}
75		
76		float SpreadPower(float omega, float peakOmega) {
77		    if (omega > peakOmega) {
78		        return 9.77 * pow(abs(omega / peakOmega), -2.5);
79		    } else {
80		        return 6.97 * pow(abs(omega / peakOmega), 5.0);
81		    }
82		}
83		
84		float DirectionSpectrum(float theta, float omega, SpectrumParameters pars) {
85		    float s = SpreadPower(omega, pars.peakOmega)
86		        + 16.0 * tanh(min(omega / pars.peakOmega, 20.0)) * pars.swell * pars.swell;
87		    return mix(2.0 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
88		}
89		
90		float TMACorrection(float omega, float g, float depth) {
91		    float omegaH = omega * sqrt(depth / g);
92		    if (omegaH <= 1.0) {
93		        return 0.5 * omegaH * omegaH;
94		    }
95		    if (omegaH < 2.0) {
96		        return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
97		    }
98		    return 1.0;
99		}
100		
101		float JONSWAP(float omega, float g, float depth, SpectrumParameters pars) {
102		    float sigma;
103		    if (omega <= pars.peakOmega)
104		        sigma = 0.07;
105		    else
106		        sigma = 0.09;
107		    float r = exp(-(omega - pars.peakOmega) * (omega - pars.peakOmega)
108		        / 2.0 / sigma / sigma / pars.peakOmega / pars.peakOmega);
109		    
110		    float oneOverOmega = 1.0 / omega;
111		    float peakOmegaOverOmega = pars.peakOmega / omega;
112		    return pars.scale * TMACorrection(omega, g, depth) * pars.alpha * g * g
113		        * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
114		        * exp(-1.25 * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
115		        * pow(abs(pars.gamma), r);
116		}
117		
118		float ShortWavesFade(float kLength, SpectrumParameters pars) {
119		    return exp(-pars.shortWavesFade * pars.shortWavesFade * kLength * kLength);
120		}
121		
122		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
123		void CalculateInitialSpectrum() {
124		    uvec3 id = gl_GlobalInvocationID;
125		    float deltaK = 2 * PI / params.LengthScale;
126		    int nx = int(id.x) - int(params.Size) / 2;
127		    int nz = int(id.y) - int(params.Size) / 2;
128		    vec2 k = vec2(nx, nz) * deltaK;
129		    float kLength = length(k);
130		    
131		    if (kLength <= params.CutoffHigh && kLength >= params.CutoffLow) {
132		        float kAngle = atan(k.y, k.x);
133		        float omega = Frequency(kLength, params.GravityAcceleration, params.Depth);
134		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1 / kLength, k.y, omega));
135		        float dOmegadk = FrequencyDerivative(kLength, params.GravityAcceleration, params.Depth);
136		
137		        SpectrumParameters spectrumparams0 = Spectrums[0];
138		        float spectrum = JONSWAP(omega, params.GravityAcceleration, params.Depth, spectrumparams0)
139		            * DirectionSpectrum(kAngle, omega, spectrumparams0) * ShortWavesFade(kLength, spectrumparams0);
140		
141		        SpectrumParameters spectrumparams1 = Spectrums[1];
142		        if (spectrumparams1.scale > 0) {
143		            spectrum += JONSWAP(omega, params.GravityAcceleration, params.Depth, spectrumparams1)
144		            * DirectionSpectrum(kAngle, omega, spectrumparams1) * ShortWavesFade(kLength, spectrumparams1);
145		        }
146		
147		        vec2 noiseSample = texture(Noise, vec2(id.xy) / vec2(params.Size)).xy;
148		        imageStore(H0K, ivec2(id.xy), vec2(noiseSample.x, noiseSample.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK));
149		
150		    }
151		    else {
152		        imageStore(H0K, ivec2(id.xy), vec2(0));
153		        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1, k.y, 0));
154		    }
155		}
156		
157		
158		layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
159		void CalculateConjugatedSpectrum() {
160		    uvec3 id = gl_GlobalInvocationID;
161		    vec2 h0K = imageLoad(H0K, ivec2(id.xy)).xy;
162		    vec2 h0MinusK = imageLoad(H0K, ivec2(uvec2((params.Size - id.x) % params.Size, (params.Size - id.y) % params.Size))).xy;
163		    imageStore(H0, ivec2(id.xy), vec4(h0K.x, h0K.y, h0MinusK.x, -h0MinusK.y));
164		}
165		
166		void main() {
167		    bool runInitial = true;
168		    if (runInitial) {
169		        CalculateInitialSpectrum();
170		    } else {
171		        CalculateConjugatedSpectrum();
172		    }
173		}
174		
175		
          RDShaderFile                                    RSRC