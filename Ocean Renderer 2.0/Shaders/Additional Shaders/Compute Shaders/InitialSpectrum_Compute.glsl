#[compute]
#version 450

const float PI = 3.141592653589793238462643383279502884197;

layout(binding = 0, rgba32f) uniform image2D H0;
layout(binding = 1, rgba32f) uniform image2D WavesData;
layout(binding = 2, rg32f) uniform image2D H0K;
layout(binding = 3) uniform sampler2D Noise;

layout(set = 0, binding = 4) uniform ParamsBlock {
    uint Size;
    float LengthScale;
    float CutoffHigh;
    float CutoffLow;
    float GravityAcceleration;
    float Depth;
} params;

struct SpectrumParameters {
    float scale;
    float angle;
    float spreadBlend;
    float swell;
    float alpha;
    float peakOmega;
    float gamma;
    float shortWavesFade;
};

layout(std140, binding = 5) buffer SpectrumParametersBuffer {
    SpectrumParameters Spectrums[];
};

float Frequency(float k, float g, float depth) {
    return sqrt(g * k * tanh(min(k * depth, 20.0)));
}

float FrequencyDerivative(float k, float g, float depth) {
    float th = tanh(min(k * depth, 20.0));
    float ch = cosh(k * depth);
    return g * (depth * k / ch / ch + th) / Frequency(k, g, depth) / 2.0;
}

float NormalisationFactor(float s) {
    float s2 = s * s;
    float s3 = s2 * s;
    float s4 = s3 * s;
    if (s < 5.0) {
        return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
    } else {
        return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
    }
}

float DonelanBannerBeta(float x) {
    if (x < 0.95) {
        return 2.61 * pow(abs(x), 1.3);
    }
    if (x < 1.6) {
        return 2.28 * pow(abs(x), -1.3);
    }
    float p = -0.4 + 0.8393 * exp(-0.567 * log(x * x));
    return pow(10.0, p);
}

float DonelanBanner(float theta, float omega, float peakOmega) {
    float beta = DonelanBannerBeta(omega / peakOmega);
    float sech = 1.0 / cosh(beta * theta);
    return beta / 2.0 / tanh(beta * 3.1416) * sech * sech;
}

float Cosine2s(float theta, float s) {
    return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2.0 * s);
}

float SpreadPower(float omega, float peakOmega) {
    if (omega > peakOmega) {
        return 9.77 * pow(abs(omega / peakOmega), -2.5);
    } else {
        return 6.97 * pow(abs(omega / peakOmega), 5.0);
    }
}

float DirectionSpectrum(float theta, float omega, SpectrumParameters pars) {
    float s = SpreadPower(omega, pars.peakOmega)
        + 16.0 * tanh(min(omega / pars.peakOmega, 20.0)) * pars.swell * pars.swell;
    return mix(2.0 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
}

float TMACorrection(float omega, float g, float depth) {
    float omegaH = omega * sqrt(depth / g);
    if (omegaH <= 1.0) {
        return 0.5 * omegaH * omegaH;
    }
    if (omegaH < 2.0) {
        return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
    }
    return 1.0;
}

float JONSWAP(float omega, float g, float depth, SpectrumParameters pars) {
    float sigma;
    if (omega <= pars.peakOmega)
        sigma = 0.07;
    else
        sigma = 0.09;
    float r = exp(-(omega - pars.peakOmega) * (omega - pars.peakOmega)
        / 2.0 / sigma / sigma / pars.peakOmega / pars.peakOmega);
    
    float oneOverOmega = 1.0 / omega;
    float peakOmegaOverOmega = pars.peakOmega / omega;
    return pars.scale * TMACorrection(omega, g, depth) * pars.alpha * g * g
        * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
        * exp(-1.25 * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
        * pow(abs(pars.gamma), r);
}

float ShortWavesFade(float kLength, SpectrumParameters pars) {
    return exp(-pars.shortWavesFade * pars.shortWavesFade * kLength * kLength);
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void CalculateInitialSpectrum() {
    uvec3 id = gl_GlobalInvocationID;
    float deltaK = 2 * PI / params.LengthScale;
    int nx = int(id.x) - int(params.Size) / 2;
    int nz = int(id.y) - int(params.Size) / 2;
    vec2 k = vec2(nx, nz) * deltaK;
    float kLength = length(k);
    
    if (kLength <= params.CutoffHigh && kLength >= params.CutoffLow) {
        float kAngle = atan(k.y, k.x);
        float omega = Frequency(kLength, params.GravityAcceleration, params.Depth);
        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1 / kLength, k.y, omega));
        float dOmegadk = FrequencyDerivative(kLength, params.GravityAcceleration, params.Depth);

        SpectrumParameters spectrumparams0 = Spectrums[0];
        float spectrum = JONSWAP(omega, params.GravityAcceleration, params.Depth, spectrumparams0)
            * DirectionSpectrum(kAngle, omega, spectrumparams0) * ShortWavesFade(kLength, spectrumparams0);

        SpectrumParameters spectrumparams1 = Spectrums[1];
        if (spectrumparams1.scale > 0) {
            spectrum += JONSWAP(omega, params.GravityAcceleration, params.Depth, spectrumparams1)
            * DirectionSpectrum(kAngle, omega, spectrumparams1) * ShortWavesFade(kLength, spectrumparams1);
        }

    vec2 noiseSample = texture(Noise, vec2(id.xy) / vec2(params.Size)).xy;
    imageStore(H0K, ivec2(id.xy), vec4(vec2(noiseSample.x, noiseSample.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK), 0.0, 0.0));

    }
    else {
        imageStore(H0K, ivec2(id.xy), vec4(vec2(0), 0.0, 0.0));
        imageStore(WavesData, ivec2(id.xy), vec4(k.x, 1, k.y, 0));
    }
}


layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void CalculateConjugatedSpectrum() {
    uvec3 id = gl_GlobalInvocationID;
    vec2 h0K = imageLoad(H0K, ivec2(id.xy)).xy;
    vec2 h0MinusK = imageLoad(H0K, ivec2(uvec2((params.Size - id.x) % params.Size, (params.Size - id.y) % params.Size))).xy;
    imageStore(H0, ivec2(id.xy), vec4(h0K.x, h0K.y, h0MinusK.x, -h0MinusK.y));
}

void main() {
    bool runInitial = true;
    if (runInitial) {
        CalculateInitialSpectrum();
    } else {
        CalculateConjugatedSpectrum();
    }
}

//-------------- END OF COMPUTE SHADER --------------

//----------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------

//-------------- CHATGPT EVALUATION -----------------

// Your translated GLSL code appears to be faithful to the original HLSL code, with the necessary changes made to accommodate the different syntax and constructs of the two shading languages. Here are some points to confirm the translation's accuracy:

// 1) Function Translation: All the functions from the original HLSL code seem to have been translated accurately to GLSL, keeping the same logic and mathematical operations.

// 2) Variable and Structure Translation: The ParamsBlock and SpectrumParametersBuffer in GLSL correspond to direct variable declarations and StructuredBuffer<SpectrumParameters> in HLSL. The translation has grouped the global variables into structures, which is a good practice for GLSL.

// 3) Texture and Image Handling: The RWTexture2D and Texture2D from HLSL have been translated to image2D and sampler2D in GLSL respectively, which is correct.

// 4) Shader Invocation: The #pragma kernel directives in HLSL have been translated to layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in; and function declarations in GLSL. This is a proper translation as it specifies the workgroup size and defines the compute shader functions.

// 5) Data Storage: The imageStore and imageLoad functions in GLSL are used in place of direct texture assignments in HLSL, which is the correct way to handle image reads and writes in GLSL.

// 6) Texture Coordinate Handling: The texture coordinate calculations and accesses appear to be translated correctly, with the necessary adjustments for the different coordinate systems and texture access functions between HLSL and GLSL.

// 7) Mathematical Constants and Functions: Mathematical constants like PI and functions like sqrt, tanh, exp, pow, etc., are used consistently between the HLSL and GLSL code.

// 8) Control Flow: Control flow constructs like if-else and for loops have been translated accurately.

// 9) Type Conversions: The modifications made to ensure the proper vector types are used with imageStore are correct and do not alter the logic of the original code.

// The adjustments made, such as expanding vec2 to vec4 where necessary for imageStore, are correct and should not affect the functionality of the original code. This change was necessary to comply with GLSL's imageStore function requirements and does not change the underlying logic of your shader.

// In conclusion, your GLSL translation appears to be a faithful representation of the original HLSL code, with the necessary adjustments made for the differences between HLSL and GLSL.


// ------------ ORIGINAL HLSL CODE -------------

// #pragma kernel CalculateInitialSpectrum
// #pragma kernel CalculateConjugatedSpectrum

// static const float PI = 3.1415926;

// RWTexture2D<float4> H0;
// // wave vector x, 1 / magnitude, wave vector z, frequency
// RWTexture2D<float4> WavesData;
// RWTexture2D<float2> H0K;

// Texture2D<float2> Noise;
// uint Size;
// float LengthScale;
// float CutoffHigh;
// float CutoffLow;
// float GravityAcceleration;
// float Depth;

// struct SpectrumParameters
// {
// 	float scale;
// 	float angle;
// 	float spreadBlend;
// 	float swell;
// 	float alpha;
// 	float peakOmega;
// 	float gamma;
// 	float shortWavesFade;
// };

// StructuredBuffer<SpectrumParameters> Spectrums;


// float Frequency(float k, float g, float depth)
// {
// 	return sqrt(g * k * tanh(min(k * depth, 20)));
// }

// float FrequencyDerivative(float k, float g, float depth)
// {
// 	float th = tanh(min(k * depth, 20));
// 	float ch = cosh(k * depth);
// 	return g * (depth * k / ch / ch + th) / Frequency(k, g, depth) / 2;
// }

// float NormalisationFactor(float s)
// {
// 	float s2 = s * s;
// 	float s3 = s2 * s;
// 	float s4 = s3 * s;
// 	if (s < 5)
// 		return -0.000564 * s4 + 0.00776 * s3 - 0.044 * s2 + 0.192 * s + 0.163;
// 	else
// 		return -4.80e-08 * s4 + 1.07e-05 * s3 - 9.53e-04 * s2 + 5.90e-02 * s + 3.93e-01;
// }

// float DonelanBannerBeta(float x)
// {
// 	if (x < 0.95)
// 		return 2.61 * pow(abs(x), 1.3);
// 	if (x < 1.6)
// 		return 2.28 * pow(abs(x), -1.3);
// 	float p = -0.4 + 0.8393 * exp(-0.567 * log(x * x));
// 	return pow(10, p);
// }

// float DonelanBanner(float theta, float omega, float peakOmega)
// {
// 	float beta = DonelanBannerBeta(omega / peakOmega);
// 	float sech = 1 / cosh(beta * theta);
// 	return beta / 2 / tanh(beta * 3.1416) * sech * sech;
// }

// float Cosine2s(float theta, float s)
// {
// 	return NormalisationFactor(s) * pow(abs(cos(0.5 * theta)), 2 * s);
// }

// float SpreadPower(float omega, float peakOmega)
// {
// 	if (omega > peakOmega)
// 	{
// 		return 9.77 * pow(abs(omega / peakOmega), -2.5);
// 	}
// 	else
// 	{
// 		return 6.97 * pow(abs(omega / peakOmega), 5);
// 	}
// }

// float DirectionSpectrum(float theta, float omega, SpectrumParameters pars)
// {
// 	float s = SpreadPower(omega, pars.peakOmega)
// 		+ 16 * tanh(min(omega / pars.peakOmega, 20)) * pars.swell * pars.swell;
// 	return lerp(2 / 3.1415 * cos(theta) * cos(theta), Cosine2s(theta - pars.angle, s), pars.spreadBlend);
// }

// float TMACorrection(float omega, float g, float depth)
// {
// 	float omegaH = omega * sqrt(depth / g);
// 	if (omegaH <= 1)
// 		return 0.5 * omegaH * omegaH;
// 	if (omegaH < 2)
// 		return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
// 	return 1;
// }

// float JONSWAP(float omega, float g, float depth, SpectrumParameters pars)
// {
// 	float sigma;
// 	if (omega <= pars.peakOmega)
// 		sigma = 0.07;
// 	else
// 		sigma = 0.09;
// 	float r = exp(-(omega - pars.peakOmega) * (omega - pars.peakOmega)
// 		/ 2 / sigma / sigma / pars.peakOmega / pars.peakOmega);
	
// 	float oneOverOmega = 1 / omega;
// 	float peakOmegaOverOmega = pars.peakOmega / omega;
// 	return pars.scale * TMACorrection(omega, g, depth) * pars.alpha * g * g
// 		* oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega * oneOverOmega
// 		* exp(-1.25 * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega * peakOmegaOverOmega)
// 		* pow(abs(pars.gamma), r);
// }

// float ShortWavesFade(float kLength, SpectrumParameters pars)
// {
// 	return exp(-pars.shortWavesFade * pars.shortWavesFade * kLength * kLength);
// }

// [numthreads(8, 8, 1)]
// void CalculateInitialSpectrum(uint3 id : SV_DispatchThreadID)
// {
// 	float deltaK = 2 * PI / LengthScale;
// 	int nx = id.x - Size / 2;
// 	int nz = id.y - Size / 2;
// 	float2 k = float2(nx, nz) * deltaK;
// 	float kLength = length(k);
	
// 	if (kLength <= CutoffHigh && kLength >= CutoffLow)
// 	{
// 		float kAngle = atan2(k.y, k.x);
// 		float omega = Frequency(kLength, GravityAcceleration, Depth);
// 		WavesData[id.xy] = float4(k.x, 1 / kLength, k.y, omega);
// 		float dOmegadk = FrequencyDerivative(kLength, GravityAcceleration, Depth);

// 		float spectrum = JONSWAP(omega, GravityAcceleration, Depth, Spectrums[0])
// 			* DirectionSpectrum(kAngle, omega, Spectrums[0]) * ShortWavesFade(kLength, Spectrums[0]);
// 		if (Spectrums[1].scale > 0)
// 			spectrum += JONSWAP(omega, GravityAcceleration, Depth, Spectrums[1])
// 			* DirectionSpectrum(kAngle, omega, Spectrums[1]) * ShortWavesFade(kLength, Spectrums[1]);
// 		H0K[id.xy] = float2(Noise[id.xy].x, Noise[id.xy].y)
// 			* sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK);
// 	}
// 	else
// 	{
// 		H0K[id.xy] = 0;
// 		WavesData[id.xy] = float4(k.x, 1, k.y, 0);
// 	}
// }

// [numthreads(8,8,1)]
// void CalculateConjugatedSpectrum(uint3 id : SV_DispatchThreadID)
// {
// 	float2 h0K = H0K[id.xy];
// 	float2 h0MinusK = H0K[uint2((Size - id.x) % Size, (Size - id.y) % Size)];
// 	H0[id.xy] = float4(h0K.x, h0K.y, h0MinusK.x, -h0MinusK.y);
// }


