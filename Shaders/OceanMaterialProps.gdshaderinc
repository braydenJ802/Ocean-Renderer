
// Textures
uniform sampler2D _FoamAlbedo;
uniform sampler2D _FoamUnderwaterTexture;
uniform sampler2D _ContactFoamTexture;
uniform sampler2D _FoamTrailTexture;
uniform sampler2D _DistantRoughnessMap;
uniform sampler2D _FoamDetailMap;

// Texture coordinates scaling and translation
uniform vec4 _FoamAlbedo_ST = vec4(0.0);
uniform vec4 _FoamUnderwaterTexture_ST = vec4(0.0);
uniform vec4 _ContactFoamTexture_ST = vec4(0.0);
uniform vec4 _FoamTrailTexture_ST = vec4(0.0);
uniform vec4 _DistantRoughnessMap_ST = vec4(0.0);
uniform vec4 _FoamDetailMap_ST = vec4(0.0);

// Specular
uniform float _SpecularStrength = 0.0;
uniform float _SpecularMinRoughness = 0.0;

// Horizon
uniform float _RoughnessScale = 0.0;
uniform float _RoughnessDistance = 0.0;
uniform float _HorizonFog = 0.0;
uniform float _CascadesFadeDist = 0.0;
uniform float _UvWarpStrength = 0.0;

// Local reflections
uniform float _ReflectionNormalStength = 0.0;

// Underwater
uniform float _RefractionStrength = 0.0;
uniform float _RefractionStrengthUnderwater = 0.0;

// Subsurface scattering
uniform float _SssSunStrength = 0.0;
uniform float _SssEnvironmentStrength = 0.0;
uniform float _SssSpread = 0.0;
uniform float _SssNormalStrength = 0.0;
uniform float _SssHeightBias = 0.0;
uniform float _SssFadeDistance = 0.0;

// Foam
uniform float _FoamNormalsDetail = 0.0;
uniform vec4 _FoamTint = vec4(0.0);
uniform vec4 _UnderwaterFoamColor = vec4(0.0);
uniform float _UnderwaterFoamParallax = 0.0;
uniform float _ContactFoam = 0.0;
