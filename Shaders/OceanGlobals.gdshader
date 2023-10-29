shader_type spatial;

#ifndef OCEAN_GLOBALS_INCLUDED


#define OCEAN_PI 3.1415926535897932384626

// submergence
uniform sampler2D Ocean_CameraSubmergenceTexture;
uniform float Ocean_ElevationBelowCamera = 0.0;

// simulation
uniform float Ocean_WindSpeed = 0.0;
uniform float Ocean_WavesScale = 0.0;
uniform float Ocean_WavesAlignement = 0.0;
uniform vec2 Ocean_WindDirection = vec2(0.0);
uniform mat4 Ocean_WorldToWindSpace = mat4(1.0);
uniform float Ocean_ReferenceWaveHeight = 0.0;

// foam
uniform float Ocean_FoamCoverage = 0.0;
uniform float Ocean_FoamDensity = 0.0;
uniform float Ocean_FoamSharpness = 0.0;
uniform float Ocean_FoamPersistence = 0.0;
uniform float Ocean_FoamTrail = 0.0;
uniform float Ocean_FoamTrailTextureStrength = 0.0;
uniform float Ocean_FoamUnderwater = 0.0;
uniform vec4 Ocean_FoamCascadesWeights = vec4(0.0);
uniform vec2 Ocean_FoamTrailTextureSize0 = vec2(0.0);
uniform vec2 Ocean_FoamTrailTextureSize1 = vec2(0.0);
uniform vec2 Ocean_FoamTrailDirection0 = vec2(0.0);
uniform vec2 Ocean_FoamTrailDirection1 = vec2(0.0);
uniform float Ocean_FoamTrailBlendValue = 0.0;

// camera
uniform mat4 Ocean_InverseViewMatrix = mat4(1.0);
uniform mat4 Ocean_InverseProjectionMatrix = mat4(1.0);

// environment maps
//TEXTURECUBE(Ocean_SpecCube);
//SAMPLER(samplerOcean_SpecCube);
uniform vec4 Ocean_SpecCube_HDR = vec4(1.0);
uniform sampler2D Ocean_SkyMap;
//SAMPLER(samplerOcean_SkyMap;
// reflections mask
uniform vec4 Ocean_ReflectionsMaskColor = vec4(0.0);
uniform float Ocean_ReflectionsMaskRadius = 0.0;
uniform float Ocean_ReflectionsMaskSharpness = 0.0;

// colors
uniform vec3 Ocean_DeepScatterColor = vec3(0.0);
uniform vec3 Ocean_SssColor = vec3(0.0);
uniform vec3 Ocean_DiffuseColor = vec3(0.0);

uniform vec4 Ocean_AbsorptionColor0 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor1 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor2 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor3 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor4 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor5 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor6 = vec4(0.0);
uniform vec4 Ocean_AbsorptionColor7 = vec4(0.0);
uniform vec2 Ocean_AbsorptionGradientParams = vec2(0.0);

uniform float Ocean_FogDensity = 0.0;
uniform float Ocean_AbsorptionDepthScale = 0.0;


vec3 SampleOceanSpecCube(vec3 dir)
{
    vec4 envSample = SAMPLE_TEXTURECUBE_LOD(Ocean_SpecCube, samplerOcean_SpecCube, dir, 0;
    return DecodeHDREnvironment(envSample, Ocean_SpecCube_HDR;
}

vec3 OceanEnvironmentDiffuse(vec3 dir)
{
    vec4 coefficients[7];
    coefficients[0] = unity_SHAr;
    coefficients[1] = unity_SHAg;
    coefficients[2] = unity_SHAb;
    coefficients[3] = unity_SHBr;
    coefficients[4] = unity_SHBg;
    coefficients[5] = unity_SHBb;
    coefficients[6] = unity_SHC;
    return max(0.0, SampleSH9(coefficients, dir);
}

vec3 DeepScatterColor(float t)
{
    return Ocean_DeepScatterColor;
}

vec3 SssColor(float t)
{
    return Ocean_SssColor;
}

vec3 DiffuseColor(float t)
{
    return Ocean_DiffuseColor;
}

vec3 AbsorptionTint(float t)
{
    vec4 colors[GRADIENT_MAX_KEYS] =
    {
        Ocean_AbsorptionColor0,
        Ocean_AbsorptionColor1,
        Ocean_AbsorptionColor2,
        Ocean_AbsorptionColor3,
        Ocean_AbsorptionColor4,
        Ocean_AbsorptionColor5,
        Ocean_AbsorptionColor6,
        Ocean_AbsorptionColor7
    };
    Gradient g = CreateGradient(colors, Ocean_AbsorptionGradientParams;
    return SampleGradient(g, t;
}

#endif