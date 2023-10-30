#[compute]
#version 450

#define FFT_SIZE_256 // Adjust this define as needed

#if defined(FFT_SIZE_512)
#define SIZE 512
#define LOG_SIZE 9
#elif defined(FFT_SIZE_256)
#define SIZE 256
#define LOG_SIZE 8
#elif defined(FFT_SIZE_128)
#define SIZE 128
#define LOG_SIZE 7
#else
#define SIZE 64
#define LOG_SIZE 6
#endif

const uint Size = SIZE;

#ifdef FFT_ARRAY_TARGET
layout(binding = 0, rgba32f) coherent image3D Target;
#else
layout(binding = 0, rgba32f) coherent image2D Target;
#endif

layout(std140, binding = 1) uniform Params {
	uint TargetsCount;
	bool Direction;
	bool Inverse;
	bool Scale;
	bool Permute;
};

shared vec4 buffer[2][SIZE];

vec2 ComplexMult(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void ButterflyValues(uint step, uint index, out uvec2 indices, out vec2 twiddle) {
	const float twoPi = 6.28318530718;
	uint b = Size >> (step + 1);
	uint w = b * (index / b);
	uint i = (w + index) % Size;
	float s, c;
	sincos(-twoPi / float(Size) * float(w), s, c);
	twiddle = vec2(c, s);
	if (Inverse)
		twiddle.y = -twiddle.y;
	indices = uvec2(i, i + b);
}

vec4 DoFft(uint threadIndex, vec4 input) {
	buffer[0][threadIndex] = input;
	barrier();
	bool flag = false;

	for (uint step = 0; step < LOG_SIZE; step++) {
		uvec2 inputsIndices;
		vec2 twiddle;
		ButterflyValues(step, threadIndex, inputsIndices, twiddle);

		vec4 v = buffer[flag][inputsIndices.y];
		buffer[!flag][threadIndex] = buffer[flag][inputsIndices.x]
			+ vec4(ComplexMult(twiddle, v.xy), ComplexMult(twiddle, v.zw));
		flag = !flag;
		barrier();
	}

	return buffer[flag][threadIndex];
}

layout(local_size_x = SIZE, local_size_y = 1, local_size_z = 1) in;
void Fft() {
	uint threadIndex = gl_LocalInvocationID.x;
	uvec2 targetIndex;
	if (Direction)
		targetIndex = gl_WorkGroupID.yx;
	else
		targetIndex = gl_WorkGroupID.xy;

#ifdef FFT_ARRAY_TARGET
	for (uint k = 0; k < TargetsCount; k++) {
		imageStore(Target, ivec3(targetIndex, k), DoFft(threadIndex, imageLoad(Target, ivec3(targetIndex, k))));
	}
#else
	imageStore(Target, ivec2(targetIndex), DoFft(threadIndex, imageLoad(Target, ivec2(targetIndex))));
#endif
}

vec4 DoPostProcess(vec4 input, uvec2 id) {
	if (Scale)
		input /= float(Size * Size);
	if (Permute)
		input *= 1.0 - 2.0 * float((id.x + id.y) % 2);
	return input;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void PostProcess() {
#ifdef FFT_ARRAY_TARGET
	for (uint i = 0; i < TargetsCount; i++) {
		uvec2 id = gl_LocalInvocationID.xy;
		imageStore(Target, ivec3(id, i), DoPostProcess(imageLoad(Target, ivec3(id, i)), id));
	}
#else
	uvec2 id = gl_LocalInvocationID.xy;
	imageStore(Target, ivec2(id), DoPostProcess(imageLoad(Target, ivec2(id)), id));
#endif
}
