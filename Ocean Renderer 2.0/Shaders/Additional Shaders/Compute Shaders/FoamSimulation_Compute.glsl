
#[compute]
#version 450

RWTexture2DArray<float4> Turbulence;
// DxDyDzDxz, DyxDyzDxxDzz for each cascade
RWTexture2DArray<float4> Input;

cbuffer Params
{
    uint CascadesCount;
    float DeltaTime;
    float FoamDecayRate;
};


void SimulateForCascade(uint3 id)
{
	float Dxz = Input[uint3(id.xy, id.z * 2)].w;
	vec2 DxxDzz = Input[uint3(id.xy, id.z * 2 + 1)].zw;
	
	float jxx = 1 + DxxDzz.x;
	float jzz = 1 + DxxDzz.y;
	float jxz = Dxz;
	
	float jacobian = jxx * jzz - jxz * jxz;
	float jminus = 0.5 * (jxx + jzz) - 0.5 * sqrt((jxx - jzz) * (jxx - jzz) + 4 * jxz * jxz);
	
	float bias = 1;
	vec2 current = vec2(-jminus, - jacobian) + bias;
	vec2 persistent = Turbulence[id].zw;
	persistent -= FoamDecayRate * DeltaTime;
	persistent = max(current, persistent);

	Turbulence[id] = float4(current, persistent);
}

[numthreads(8, 8, 1)]
void Simulate(uint3 id : SV_DispatchThreadID)
{
	for (uint i = 0; i < CascadesCount; i++)
	{
		SimulateForCascade(uint3(id.xy, i));
	}
}

[numthreads(8, 8, 1)]
void Initialize(uint3 id : SV_DispatchThreadID)
{
	for (uint i; i < CascadesCount; i++)
	{
		Turbulence[uint3(id.xy, i)] = -5;
	}
}

