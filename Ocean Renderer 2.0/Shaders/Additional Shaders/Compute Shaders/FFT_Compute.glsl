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
const uint BUFFER_SIZE = 2 * SIZE;

#ifdef FFT_ARRAY_TARGET
layout(binding = 0, rgba32f) uniform coherent image3D Target;
#else
layout(binding = 0, rgba32f) uniform coherent image2D Target;
#endif

layout(std140, binding = 1) uniform Params {
	uint TargetsCount;
	bool Direction;
	bool Inverse;
	bool Scale;
	bool Permute;
};

layout(std140, binding = 3) buffer BufferObject {
    vec4 bufferData[BUFFER_SIZE];
};

vec2 ComplexMult(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void ButterflyValues(uint step, uint index, out uvec2 indices, out vec2 twiddle) {
    const float twoPi = 6.28318530718;
    uint b = Size >> (step + 1);
    uint w = b * (index / b);
    uint i = (w + index) % Size;
    float angle = -twoPi / float(Size) * float(w);
    float s = sin(angle);
    float c = cos(angle);
    twiddle = vec2(c, s);
    if (Inverse)
        twiddle.y = -twiddle.y;
    indices = uvec2(i, i + b);
}

vec4 DoFft(uint threadIndex, vec4 FFTinput) {
    // Compute the index manually when accessing the buffer
    uint idx = 0 * SIZE + threadIndex;
    bufferData[idx] = FFTinput;
    barrier();
    bool flag = false;

    for (uint step = 0; step < LOG_SIZE; step++) {
        uvec2 FFTinputsIndices;
        vec2 twiddle;
        ButterflyValues(step, threadIndex, FFTinputsIndices, twiddle);

		uint idx_y = (flag ? 1u : 0u) * SIZE + FFTinputsIndices.y;
        vec4 v = bufferData[idx_y];  // Corrected this line
		uint idx_x = (!flag ? 1u : 0u) * SIZE + threadIndex;
		bufferData[idx_x] = bufferData[(flag ? 1u : 0u) * SIZE + FFTinputsIndices.x]
		   + vec4(ComplexMult(twiddle, v.xy), ComplexMult(twiddle, v.zw));
        flag = !flag;
        barrier();
    }

	return bufferData[(flag ? 1u : 0u) * SIZE + threadIndex];
}


layout(local_size_x = SIZE, local_size_y = 1, local_size_z = 1) in;
void main() {
    uint threadIndex = gl_GlobalInvocationID.x;
    vec4 FFTinput = imageLoad(Target, ivec2(gl_LocalInvocationID.xy));
    vec4 FFToutput = DoFft(threadIndex, FFTinput);
    imageStore(Target, ivec2(gl_LocalInvocationID.xy), FFToutput);
}

vec4 DoPostProcess(vec4 FFTinput, uvec2 id) {
	if (Scale)
		FFTinput /= float(Size * Size);
	if (Permute)
		FFTinput *= 1.0 - 2.0 * float((id.x + id.y) % 2);
	return FFTinput;
}

// Additional function for post-processing if needed
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
