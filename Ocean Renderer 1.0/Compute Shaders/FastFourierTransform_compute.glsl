#[compute]
#version 450

const float PI = 3.14159265358979323846264338327950;

layout(binding = 0, rgba32f) uniform image2D PrecomputeBuffer;
layout(binding = 1, rgba32f) readonly uniform image2D PrecomputedData;
layout(binding = 2, rg32f) uniform image2D Buffer0;
layout(binding = 3, rg32f) uniform image2D Buffer1;

bool PingPong;
uint Step;
uint Size;

vec2 ComplexMult(vec2 a, vec2 b) {
    return vec2(a.r * b.r - a.g * b.g, a.r * b.g + a.g * b.r);
}

vec2 ComplexExp(vec2 a) {
    return vec2(cos(a.y), sin(a.y)) * exp(a.x);
}

layout(local_size_x = 1, local_size_y = 8, local_size_z = 1) in;
void PrecomputeTwiddleFactorsAndInputIndices() {
    uvec3 id = gl_GlobalInvocationID;
    uint b = Size >> (id.x + 1);
	vec2 mult = 2 * PI * vec2(0, 1) / Size;
	uint i = (2 * b * (id.y / b) + id.y % b) % Size;
	vec2 twiddle = ComplexExp(-mult * ((id.y / b) * b));
	PrecomputeBuffer[id.xy] = vec4(twiddle.x, twiddle.y, i, i + b);
	PrecomputeBuffer[uint2(id.x, id.y + Size / 2)] = vec4(-twiddle.x, -twiddle.y, i, i + b);
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void HorizontalStepFFT() {
    uvec3 id = gl_GlobalInvocationID;
    vec4 data = PrecomputedData[uint2(Step, id.x)];
	uvec2 inputsIndices = uvec2(data.zw);
	if (PingPong)
	{
		Buffer1[id.xy] = Buffer0[uint2(inputsIndices.x, id.y)]
			+ ComplexMult(data.rg, Buffer0[uint2(inputsIndices.y, id.y)]);
	}
	else
	{
		Buffer0[id.xy] = Buffer1[uint2(inputsIndices.x, id.y)]
			+ ComplexMult(data.rg, Buffer1[uint2(inputsIndices.y, id.y)]);
	}
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void VerticalStepFFT() {
    uvec3 id = gl_GlobalInvocationID;
    vec4 data = PrecomputedData[uint2(Step, id.y)];
	uvec2 inputsIndices = uvec2(data.zw);
	if (PingPong)
	{
		Buffer1[id.xy] = Buffer0[uint2(id.x, inputsIndices.x)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(id.x, inputsIndices.y)]);
	}
	else
	{
		Buffer0[id.xy] = Buffer1[uint2(id.x, inputsIndices.x)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(id.x, inputsIndices.y)]);
	}
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void HorizontalStepInverseFFT() {
    uvec3 id = gl_GlobalInvocationID;
	vec4 data = PrecomputedData[uint2(Step, id.x)];
	uvec2 inputsIndices = uvec2(data.zw);
	if (PingPong)
	{
		Buffer1[id.xy] = Buffer0[uint2(inputsIndices.x, id.y)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(inputsIndices.y, id.y)]);
	}
	else
	{
		Buffer0[id.xy] = Buffer1[uint2(inputsIndices.x, id.y)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(inputsIndices.y, id.y)]);
	}
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void VerticalStepInverseFFT() {
    uvec3 id = gl_GlobalInvocationID;
	vec4 data = PrecomputedData[uint2(Step, id.y)];
	uvec2 inputsIndices = uvec2(data.zw);
	if (PingPong)
	{
		Buffer1[id.xy] = Buffer0[uint2(id.x, inputsIndices.x)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer0[uint2(id.x, inputsIndices.y)]);
	}
	else
	{
		Buffer0[id.xy] = Buffer1[uint2(id.x, inputsIndices.x)]
			+ ComplexMult(vec2(data.r, -data.g), Buffer1[uint2(id.x, inputsIndices.y)]);
	}
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void Scale() {
    uvec3 id = gl_GlobalInvocationID;
    Buffer0[id.xy] = Buffer0[id.xy] / Size / Size;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void Permute() {
    uvec3 id = gl_GlobalInvocationID;
	Buffer0[id.xy] = Buffer0[id.xy] * (1.0 - 2.0 * ((id.x + id.y) % 2));
}
