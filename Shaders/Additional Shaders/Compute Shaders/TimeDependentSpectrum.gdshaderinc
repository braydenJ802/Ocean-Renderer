

#define PI 3.1415926

// DxDyDzDxz, DyxDyzDxxDzz for each cascade
RWTexture2DArray<vec4> Result;

Texture2DArray<float4> H0;
// wave vector x, chop, wave vector z, frequency
Texture2DArray<float4> WavesData;

cbuffer Params
{
    uint CascadesCount;
    float Time;
};



vec2 ComplexMult(vec2 a, vec2 b)
{
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void CalculateForCascade(uint3 id)
{
	float4 wave = WavesData[id];
	
	float phase = wave.w * Time;
	vec2 exponent = vec2(cos(phase), sin(phase));
	float4 h0 = H0[id];
	vec2 h = ComplexMult(h0.xy, exponent)
		+ ComplexMult(h0.zw, vec2(exponent.x, -exponent.y));
	vec2 ih = vec2(-h.y, h.x);
	
	float oneOverKLength = 1 / max(0.001, length(wave.xz));
	
	float lambda = wave.y;
	vec2 displacementX = lambda * ih * wave.x * oneOverKLength;
	vec2 displacementY = h;
	vec2 displacementZ = lambda * ih * wave.z * oneOverKLength;
	
	vec2 displacementX_dx = -lambda * h * wave.x * wave.x * oneOverKLength;
	vec2 displacementY_dx = ih * wave.x;
	vec2 displacementZ_dx = -lambda * h * wave.x * wave.z * oneOverKLength;
		 
	vec2 displacementY_dz = ih * wave.z;
	vec2 displacementZ_dz = -lambda * h * wave.z * wave.z * oneOverKLength;
	
	Result[uint3(id.xy, id.z * 2)] = float4(vec2(displacementX.x - displacementY.y, displacementX.y + displacementY.x),
							  vec2(displacementZ.x - displacementZ_dx.y, displacementZ.y + displacementZ_dx.x));
	Result[uint3(id.xy, id.z * 2 + 1)] = float4(vec2(displacementY_dx.x - displacementY_dz.y, displacementY_dx.y + displacementY_dz.x),
							     vec2(displacementX_dx.x - displacementZ_dz.y, displacementX_dx.y + displacementZ_dz.x));
}

[numthreads(8,8,1)]
void CalculateAmplitudes(uint3 id : SV_DispatchThreadID)
{
	for (uint i = 0; i < CascadesCount; i++)
	{
		CalculateForCascade(uint3(id.xy, i));
	}
}

