            
            
            #include "GeoClipMap.gdshaderinc"
         //   #include "OceanGlobals.gdshaderinc"
            #include "OceanSimulationSampling.gdshaderinc"
        //    #include "OceanFoam.gdshaderinc"
        //    #include "OceanSurface.gdshaderinc"

            struct Attributes
            {
                vec4 positionOS;
                vec2 uv;
            };

            struct Varyings
            {
                vec4 positionHCS;
                vec3 positionWS;
                float viewDepth;
                vec4 positionNDC;
                vec2 worldUV;
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                vec4 shadowCoord  : TEXCOORD4;
                #endif
            };

            Varyings OceanMainVert(Attributes input)
            {
                Varyings output;

                output.positionWS = ClipMapVertex(input.positionOS.xyz, input.uv);
                output.worldUV = output.positionWS.xz;

                //vec3 viewVector = output.positionWS - _WorldSpaceCameraPos;
                //float viewDist = length(viewVector);
               // float viewDistXzSquared = dot(viewVector.xz, viewVector.xz);

               // float warpDistance = Ocean_LengthScales.x * 0.5;
               // output.worldUV += sin(output.worldUV.yx / warpDistance)
                //    * min(1, viewDistXzSquared / (warpDistance * warpDistance * 100))
                //    * warpDistance * 0.4 * _UvWarpStrength;

              //  vec4 weights = LodWeights(viewDist, _CascadesFadeDist);
              //  output.positionWS += SampleDisplacement(output.worldUV, weights, 1);

                vec3 positionOS = TransformWorldToObject(output.positionWS);
                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);
                output.viewDepth = -positionInputs.positionVS.z;
                output.positionNDC = positionInputs.positionNDC;
                output.positionHCS = positionInputs.positionCS;
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                output.shadowCoord = GetShadowCoord(positionInputs);
                #endif
                return output;
            }

            half4 OceanMainFrag(Varyings input, float facing : VFACE) : SV_Target
            {
                vec3 viewDir = _WorldSpaceCameraPos - input.positionWS;
                float viewDist = length(viewDir);
                viewDir = viewDir / viewDist;

                vec4 lodWeights = LodWeights(viewDist, _CascadesFadeDist);

                vec4 shoreWeights = 1;// ShoreModulation(i.shore.x);
                vec4x4 derivatives = SampleDerivatives(input.worldUV, lodWeights * shoreWeights);
                vec3 normal = NormalFromDerivatives(derivatives, 1);

                FoamInput fi;
                fi.derivatives = derivatives;
                fi.worldUV = input.worldUV;
                fi.viewDist = viewDist;
                fi.lodWeights = lodWeights;
                fi.shoreWeights = shoreWeights;
                fi.positionNDC = input.positionNDC;
                fi.viewDepth = input.viewDepth;
                fi.time = _Time.y;
                fi.viewDir = viewDir;
                fi.normal = normal;
                FoamData foamData = GetFoamData(fi);

                vec4 shadowCoord = 0;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    shadowCoord = input.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #else
                    shadowCoord = vec4(0, 0, 0, 0);
                #endif

                Light mainLight = GetMainLight(shadowCoord);
                float roughnessMap = SAMPLE_TEXTURE2D(_DistantRoughnessMap, sampler_DistantRoughnessMap,
                    TRANSFORM_TEX(input.worldUV, _DistantRoughnessMap) * 0.001).r;
                roughnessMap *= saturate(viewDist / Ocean_LengthScales.x * 0.05);

                LightingInput li;
                li.normal = normal;
                li.viewDir = viewDir;
                li.viewDist = viewDist;
                li.roughnessMap = roughnessMap;
                li.positionWS = input.positionWS;
                li.shore = 0;
                li.positionNDC = input.positionNDC;
                li.viewDepth = input.viewDepth;
                li.cameraPos = _WorldSpaceCameraPos;
                li.mainLight = mainLight;

                bool backface = dot(normal, viewDir) < 0;
                vec3 oceanColor = vec3(0.0);

                #ifdef OCEAN_UNDERWATER_ENABLED
                float submergence = SAMPLE_TEXTURE2D(Ocean_CameraSubmergenceTexture, 
                    samplerOcean_CameraSubmergenceTexture,
                    input.positionNDC.xy / input.positionNDC.w).r;
                clip(-(facing < 0 && submergence > 0.6));

                bool underwater = facing < 0 || submergence < 0.3;
                if (!underwater && backface)
                {
                    li.normal = reflect(li.normal, li.viewDir);
                }
                else if (underwater && !backface)
                {
                    li.normal = reflect(li.normal, li.viewDir);
                }
                if (underwater)
                    oceanColor = GetOceanColorUnderwater(li);
                else
                    oceanColor = GetOceanColor(li, foamData);
                #else
                if (backface)
                    li.normal = reflect(li.normal, li.viewDir);
                oceanColor = GetOceanColor(li, foamData);
                #endif

                return vec4(oceanColor, 1);
            }
            ENDHLSL
        }