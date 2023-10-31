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
        imageStore(H0K, ivec2(id.xy), vec2(noiseSample.x, noiseSample.y) * sqrt(2 * spectrum * abs(dOmegadk) / kLength * deltaK * deltaK));

    }
    else {
        imageStore(H0K, ivec2(id.xy), vec2(0));
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
