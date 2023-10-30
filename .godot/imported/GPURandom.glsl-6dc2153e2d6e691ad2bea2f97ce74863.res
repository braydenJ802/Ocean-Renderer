RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_jw7e7 ;         local://RDShaderFile_pm2r5 �         RDShaderSPIRV          S  Failed parse:
ERROR: 0:71: 'resolution' : undeclared identifier 
ERROR: 0:71: 'xy' : vector swizzle selection out of range 
ERROR: 0:71: '' : compilation terminated 
ERROR: 3 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		//Quality hashes collection by nimitz 2018 (twitter: @stormoid)
4		// License details omitted for brevity
5		
6		#if 1
7		//Modified from: iq's "Integer Hash - III" (https://www.shadertoy.com/view/4tXyWN)
8		//Faster than "full" xxHash and good quality
9		uint baseHash(uvec2 p)
10		{
11		    p = 1103515245U*((p >> 1U)^(p.yx));
12		    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
13		    return h32^(h32 >> 16);
14		}
15		#else
16		//XXHash32 based (https://github.com/Cyan4973/xxHash)
17		//Slower, higher quality
18		uint baseHash(uvec2 p)
19		{
20		    const uint PRIME32_2 = 2246822519U, PRIME32_3 = 3266489917U;
21			const uint PRIME32_4 = 668265263U, PRIME32_5 = 374761393U;
22		    uint h32 = p.y + PRIME32_5 + p.x*PRIME32_3;
23		    h32 = PRIME32_4*((h32 << 17) | (h32 >> (32 - 17)));
24		    h32 = PRIME32_2*(h32^(h32 >> 15));
25		    h32 = PRIME32_3*(h32^(h32 >> 13));
26		    return h32^(h32 >> 16);
27		}
28		#endif
29		
30		//---------------------2D input---------------------
31		
32		float hash12(uvec2 x)
33		{
34		    uint n = baseHash(x);
35		    return float(n)*(1.0/float(0xffffffffU));
36		}
37		
38		vec2 hash22(uvec2 x)
39		{
40		    uint n = baseHash(x);
41		    uvec2 rz = uvec2(n, n*48271U);
42		    return vec2((rz.xy >> 1) & uvec2(0x7fffffffU))/float(0x7fffffff);
43		}
44		
45		vec3 hash32(uvec2 x)
46		{
47		    uint n = baseHash(x);
48		    uvec3 rz = uvec3(n, n*16807U, n*48271U);
49		    return vec3((rz >> 1) & uvec3(0x7fffffffU))/float(0x7fffffff);
50		}
51		
52		vec4 hash42(uvec2 x)
53		{
54		    uint n = baseHash(x);
55		    uvec4 rz = uvec4(n, n*16807U, n*48271U, n*69621U);
56		    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
57		}
58		
59		//--------------------------------------------------
60		
61		//Example taking an arbitrary float value as input
62		vec4 hash42(vec2 x)
63		{
64		    uint n = baseHash(floatBitsToUint(x));
65		    uvec4 rz = uvec4(n, n*16807U, n*48271U, n*69621U);
66		    return vec4((rz >> 1) & uvec4(0x7fffffffU))/float(0x7fffffff);
67		}
68		
69		void mainImage( out vec4 fragColor, in vec2 fragCoord )
70		{   
71		    vec2 p = fragCoord/resolution.xy;
72		    p.x *= resolution.x/resolution.y;
73		    
74		    //float input
75		    //fragColor = hash42(p);
76		    
77		    //2D input
78		    fragColor = hash42(uvec2(fragCoord));
79		    
80		    //1D input
81		    //fragColor = hash41(uint(fragCoord.x + fragCoord.y*900.));
82		    
83		    //3D input
84		    //fragColor = hash43(uvec3(fragCoord.xy, uint(fragCoord.y)*0xffffU));
85		}
86		
87		
          RDShaderFile                                    RSRC