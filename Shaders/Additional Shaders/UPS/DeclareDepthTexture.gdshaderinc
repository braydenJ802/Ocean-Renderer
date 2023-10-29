// DeclareDepthTexture.gdshaderinc

uniform sampler2D _CameraDepthTexture;

// Function to sample the depth texture
float SampleSceneDepth(vec2 uv)
{
    return texture(_CameraDepthTexture, uv).r;
}

// For Godot, we don't have a direct equivalent to `LOAD_TEXTURE2D_X` from HLSL.
// The equivalent action in Godot would be to simply sample the texture, as done in `SampleSceneDepth`.
// If you need more precise or different functionality, you'll need to specify it or work around it in Godot.
float LoadSceneDepth(vec2 uv)
{
    return SampleSceneDepth(uv);
}
