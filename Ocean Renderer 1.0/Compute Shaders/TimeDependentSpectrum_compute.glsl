#version 450
void CalculateAmplitudes()

layout(rgba32f) writeonly uniform image2D<vec2> Dx_Dz;
layout(rgba32f) writeonly uniform image2D<vec2> Dy_Dxz;
layout(rgba32f) writeonly uniform image2D<vec2> Dyx_Dyz;
layout(rgba32f) writeonly uniform image2D<vec2> Dxx_Dzz;

layout(rgba32f) readonly uniform image2D<vec4> H0;
// wave vector x, 1 / magnitude, wave vector z, frequency
layout(rgba32f) readonly uniform image2D<vec4> WavesData;
float Time;


vec2 ComplexMult(vec2 a, vec2 b)
{
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

[numthreads(8,8,1)]
void CalculateAmplitudes(uint3 id : SV_DispatchThreadID)
{
	vec4 wave = WavesData[id.xy];
	float phase = wave.w * Time;
	vec2 exponent = vec2(cos(phase), sin(phase));
	vec2 h = ComplexMult(H0[id.xy].xy, exponent)
		+ ComplexMult(H0[id.xy].zw, vec2(exponent.x, -exponent.y));
	vec2 ih = vec2(-h.y, h.x);
	
	vec2 displacementX = ih * wave.x * wave.y;
	vec2 displacementY = h;
	vec2 displacementZ = ih * wave.z * wave.y;
		 
	vec2 displacementX_dx = -h * wave.x * wave.x * wave.y;
	vec2 displacementY_dx = ih * wave.x;
	vec2 displacementZ_dx = -h * wave.x * wave.z * wave.y;
		 
	vec2 displacementY_dz = ih * wave.z;
	vec2 displacementZ_dz = -h * wave.z * wave.z * wave.y;
	
	Dx_Dz[id.xy] = vec2(displacementX.x - displacementZ.y, displacementX.y + displacementZ.x);
	Dy_Dxz[id.xy] = vec2(displacementY.x - displacementZ_dx.y, displacementY.y + displacementZ_dx.x);
	Dyx_Dyz[id.xy] = vec2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x);
	Dxx_Dzz[id.xy] = vec2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x);
}

