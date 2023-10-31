
#ifndef OCEAN_GRADIENT_INCLUDED
#define OCEAN_GRADIENT_INCLUDED

const int GRADIENT_MAX_KEYS = 8;

struct Gradient
{
    vec4 colors[GRADIENT_MAX_KEYS];
    int colorsCount;
    bool type;
};

// Default values for the colors array
// Default values for the colors array
const vec4 DEFAULT_COLORS[GRADIENT_MAX_KEYS] = {vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0)};

Gradient CreateGradient(mat4 colorsMatrix1, mat4 colorsMatrix2, float colorsCount, bool type) {
    Gradient g;
    g.colors[0] = colorsMatrix1[0];
    g.colors[1] = colorsMatrix1[1];
    g.colors[2] = colorsMatrix1[2];
    g.colors[3] = colorsMatrix1[3];
    g.colors[4] = colorsMatrix2[0];
    g.colors[5] = colorsMatrix2[1];
    g.colors[6] = colorsMatrix2[2];
    g.colors[7] = colorsMatrix2[3];
    g.colorsCount = int(colorsCount);
    g.type = type;
    return g;
}

vec3 SampleGradient(Gradient grad, float t)
{
    vec3 color = grad.colors[0].rgb;
    
    for (int i = 1; i < GRADIENT_MAX_KEYS; i++)
    {
        float colorPos = clamp((t - grad.colors[i - 1].w) / (grad.colors[i].w - grad.colors[i - 1].w), 0.0, 1.0) * step(float(i), float(grad.colorsCount - 1));
		color = mix(color, grad.colors[i].rgb, mix(colorPos, step(0.01, colorPos), float(grad.type)));

    }
    return color;
}
#endif

//-------------------END OF SHADER--------------------

//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------

//---------------CHATGPT EVALUATION OF TRANSLATION------

//Your translation from HLSL to a Godot Shader language appears largely accurate and consistent with the original HLSL code. Here are some specific observations:
//
//Preprocessor Directives:
//
//You've correctly translated #if !defined(...) to #ifndef ... which is more idiomatic in GLSL.
//Constant Definitions:
//
//The definition of GRADIENT_MAX_KEYS has been translated correctly.
//Struct Definitions:
//
//The Gradient struct has been translated accurately, with float4 changed to vec4.
//Array Initialization:
//
//In the original HLSL code, the CreateGradient function takes a float4 array as an argument to initialize the colors array. In your translated code, you've chosen a different approach by passing two mat4 arguments to initialize the colors array. This is a clever way to work around the limitation in GLSL that prevents passing arrays as function arguments. This change is functional and adheres to the limitations of GLSL while achieving the same goal.
//Function Definitions:
//
//The CreateGradient and SampleGradient functions have been translated correctly, with HLSL specific syntaxes like lerp changed to GLSL's mix and saturate to clamp.
//Loop Translation:
//
//The [unroll] directive has been omitted in your translation as GLSL doesn't have a direct equivalent. This directive is a hint to the compiler in HLSL to unroll the loop for potential performance benefits. It's not critical, but it's something to be aware of. The loop itself has been translated correctly.
//Function Calls and Mathematical Operations:
//
//The translation of mathematical operations and function calls within SampleGradient appears to be correct.
//Type Casting:
//
//You've added explicit type casting in the SampleGradient function, which is a good practice to ensure correct behavior.
//Commenting:
//
//The comments from the original code have not been carried over. While not critical, including comments can be helpful for understanding the code.
//Default Values:
//
//You've added a DEFAULT_COLORS constant array as a workaround for not being able to pass an array as a parameter to a function in GLSL. This is a logical addition given the constraints of GLSL.
//In summary, your translation is thoughtful and demonstrates a good understanding of both HLSL and GLSL. While there are some minor differences due to the languages' differing capabilities and syntax, the translated code seems to maintain the intent and functionality of the original HLSL code. Testing the shader in Godot to ensure it behaves as expected, and comparing the output with the original HLSL shader, would be the next steps to validate the translation fully.

//---------------------------------------------

//-----------ORIGINAL HLSL CODE---------------------
//#if !defined(OCEAN_GRADIENT_INCLUDED)
//#define OCEAN_GRADIENT_INCLUDED
//#define GRADIENT_MAX_KEYS 8
//
//struct Gradient
//{
	//float4 colors[GRADIENT_MAX_KEYS];
	//int colorsCount;
	//bool type;
//};
//
//Gradient CreateGradient(float4 colors[GRADIENT_MAX_KEYS], float2 params)
//{
	//Gradient g;
	//g.colors = colors;
	//g.colorsCount = params.x;
	//g.type = params.y;
	//return g;
//}
//
//float3 SampleGradient(Gradient grad, float t)
//{
	//float3 color = grad.colors[0].rgb;
	//[unroll]
	//for (int i = 1; i < GRADIENT_MAX_KEYS; i++)
	//{
		//float colorPos = saturate((t - grad.colors[i - 1].w) / (grad.colors[i].w - grad.colors[i - 1].w)) * step(i, grad.colorsCount - 1);
		//color = lerp(color, grad.colors[i].rgb, lerp(colorPos, step(0.01, colorPos), grad.type));
	//}
	//return color;
//}
//#endif

