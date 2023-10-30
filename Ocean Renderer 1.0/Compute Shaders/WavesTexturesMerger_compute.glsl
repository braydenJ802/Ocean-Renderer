#version 450

layout(rgba32f) writeonly uniform image2D<vec3> Displacement;
layout(rgba32f) writeonly uniform image2D<vec4> Derivatives;
layout(rgba32f) writeonly uniform image2D<vec4> Turbulence;

layout(rgba32f) readonly uniform image2D<vec2> Dx_Dz;
layout(rgba32f) readonly uniform image2D<vec2> Dy_Dxz;
layout(rgba32f) readonly uniform image2D<vec2> Dyx_Dyz;
layout(rgba32f) readonly uniform image2D<vec2> Dxx_Dzz;

float Lambda;
float DeltaTime;

[numthreads(8, 8, 1)]
void FillResultTextures(uint3 id : SV_DispatchThreadID)
{
	vec2 DxDz = Dx_Dz[id.xy];
	vec2 DyDxz = Dy_Dxz[id.xy];
	vec2 DyxDyz = Dyx_Dyz[id.xy];
	vec2 DxxDzz = Dxx_Dzz[id.xy];
	
	Displacement[id.xy] = vec3(Lambda * DxDz.x, DyDxz.x, Lambda * DxDz.y);
	Derivatives[id.xy] = vec4(DyxDyz, DxxDzz * Lambda);
	float jacobian = (1 + Lambda * DxxDzz.x) * (1 + Lambda * DxxDzz.y) - Lambda * Lambda * DyDxz.y * DyDxz.y;
	Turbulence[id.xy] = Turbulence[id.xy].r + DeltaTime * 0.5 / max(jacobian, 0.5);
	Turbulence[id.xy] = min(jacobian, Turbulence[id.xy].r);
}




