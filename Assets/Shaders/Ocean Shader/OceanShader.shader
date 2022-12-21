Shader "Terrain Shader Tessellation Diffuse"
{
    Properties
    {
		_HeightTexture("Height Texture", 2D) = "white" {}
        //_HeightFactor("Height Factor", Range(1.0, 12.0)) = 1.0
        _TesselationFactor("Tesselation factor", Float) = 32
		_Cubemap("Cubemap", Cube) = "white" {}
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "SimpleLit" "IgnoreProjector" = "True" "ShaderModel" = "5.0"}
        LOD 300
        Pass
        {
			Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM

            #pragma vertex vertex_shader
            #pragma hull hull_shader
            #pragma domain domain_shader
            #pragma fragment pixel_shader
            #pragma target 5.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
            float4 _LightColor0;
            sampler2D _HeightTexture;
			samplerCUBE _Cubemap;
			float _TesselationFactor;
			
            struct APPDATA
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct VS_CONTROL_POINT_OUTPUT
            {
                float4 position : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 _ShadowCoord : TEXCOORD4;
            };

            struct HS_CONSTANT_DATA_OUTPUT
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };


            VS_CONTROL_POINT_OUTPUT vertex_shader(APPDATA i)
            {
                VS_CONTROL_POINT_OUTPUT vs;
                vs.position = i.vertex;
                vs.normal = i.normal;
                vs.uv = i.uv;
				// compute screen position
				vs._ShadowCoord = mul(UNITY_MATRIX_MVP, i.vertex);
                return vs;
            }
            HS_CONSTANT_DATA_OUTPUT constantsHS(InputPatch<VS_CONTROL_POINT_OUTPUT,3> V, uint PatchID : SV_PrimitiveID)
            {
                HS_CONSTANT_DATA_OUTPUT output = (HS_CONSTANT_DATA_OUTPUT)0;
				
                // dynamic tesselation 
				float3 v0 = V[0].position.xyz;
				float3 v1 = V[1].position.xyz;
				float3 v2 = V[2].position.xyz;
				float3 p01 = (v0 + v1) / 2.0;
				float3 p02 = (v0 + v2) / 2.0;
				float3 p12 = (v1 + v2) / 2.0;
				float h01 = tex2Dlod(_HeightTexture, float4(p01.xz, 0, 0)).r;
				float h02 = tex2Dlod(_HeightTexture, float4(p02.xz, 0, 0)).r;
				float h12 = tex2Dlod(_HeightTexture, float4(p12.xz, 0, 0)).r;
				// compute tesselation factor based on the height difference
				float tesselationFactor = max(h01, max(h02, h12));
				tesselationFactor = tesselationFactor * _TesselationFactor;
				output.edge[0] = tesselationFactor;
				output.edge[1] = tesselationFactor;
				output.edge[2] = tesselationFactor;
				output.inside = tesselationFactor;
				
                return output;
            }

            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("constantsHS")]
            [outputcontrolpoints(3)]
            VS_CONTROL_POINT_OUTPUT hull_shader(InputPatch<VS_CONTROL_POINT_OUTPUT,3> V, uint ID : SV_OutputControlPointID)
            {
                return V[ID];
            }

            [domain("tri")]
            VS_CONTROL_POINT_OUTPUT domain_shader(HS_CONSTANT_DATA_OUTPUT input, const OutputPatch<VS_CONTROL_POINT_OUTPUT,3> P, float3 K : SV_DomainLocation)
            {
                APPDATA ds;
                ds.vertex = TransformObjectToHClip(P[0].position * K.x + P[1].position * K.y + P[2].position * K.z);
                ds.normal = (P[0].normal * K.x + P[1].normal * K.y + P[2].normal * K.z);
                ds.uv = (P[0].uv * K.x + P[1].uv * K.y + P[2].uv * K.z);
                
                // apply height map
                float h = tex2Dlod(_HeightTexture, float4(ds.uv, 0, 0)).r;
                ds.vertex.y += h;

                // compute normal using height map
                float h0 = tex2Dlod(_HeightTexture, float4(ds.uv.x - 0.01, ds.uv.y, 0, 0)).r;
                float h1 = tex2Dlod(_HeightTexture, float4(ds.uv.x + 0.01, ds.uv.y, 0, 0)).r;
                float h2 = tex2Dlod(_HeightTexture, float4(ds.uv.x, ds.uv.y - 0.01, 0, 0)).r;
                float h3 = tex2Dlod(_HeightTexture, float4(ds.uv.x, ds.uv.y + 0.01, 0, 0)).r;
				float3 normal = normalize(float3(h1 - h0, 0.02, h3 - h2));
				ds.normal = normalize(ds.normal + normal);

                return vertex_shader(ds);
            }

            float4 pixel_shader(APPDATA i) : SV_TARGET
            {
                float3 height = tex2Dlod(_HeightTexture, float4(i.uv, 0, 0)).rgb;

				// add simple phong lighting
				float3 lightDir = normalize(float3(0, -1, 5));
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.vertex.xyz);
                float3 halfDir = normalize(lightDir + viewDir);
                float3 normal = normalize(i.normal);
                float3 reflectDir = reflect(-lightDir, normal);
                float3 refractDir = refract(-lightDir, normal, 1.0);
   
                const float3 diffuse = float3(0.0, 0.4, 0.9);
				const float3 specular = texCUBE(_Cubemap, reflectDir).rgb;
				const float3 ambient = float3(0.05, 0.2, 0.4);

				// use schnells law to compute fresnel
				float fresnel = pow(1.0 - dot(normal, lightDir), 5.0);
				
                // compute color using fresnel
				float3 color = ambient + diffuse * saturate(dot(normal, lightDir)) + specular * pow(saturate(dot(normal, halfDir)), 32.0) * fresnel;
				color += pow(1.0-0.1*height.r, 10);

				// toon shading
				color = floor(color * 32) / 32;
				
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
        FallBack "Diffuse"
}