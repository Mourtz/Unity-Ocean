Shader "CustomRenderTexture/New Custom Render Texture"
{
    Properties
    {
		_SeaOctaves("Octaves", Integer) = 8
		_SeaChoppiness("Choppiness", Float) = 4
        _SeaAmp("Amplitude", Float) = 2.8
		_SeaFreq("Frequency", Float) = 64
    }

     SubShader
     {
        Blend One Zero

        Pass
        {
            Name "New Custom Render Texture"

            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 3.0

            int _SeaOctaves;
            float _SeaChoppiness;
			float _SeaAmp;
			float _SeaFreq;

			
            float hash(float2 p) {
                float h = dot(p, float2(127.1, 311.7));
                return frac(sin(h) * 43758.5453123);
            }
			
            float noise(in float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return -1.0 + 2.0 * lerp(lerp(hash(i + float2(0.0, 0.0)),
                    hash(i + float2(1.0, 0.0)), u.x),
                    lerp(hash(i + float2(0.0, 1.0)),
                        hash(i + float2(1.0, 1.0)), u.x), u.y);
            }
			
            float sea_octave(float2 uv, float choppy) {
                uv += noise(uv);
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));
                wv = lerp(wv, swv, wv);
                return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
            }

            float frag(v2f_customrendertexture IN) : COLOR
            {
                float2 uv = IN.localTexcoord.xy;
                float SEA_CHOPPY = _SeaChoppiness;
                float SEA_AMP = _SeaAmp;
                float SEA_FREQ = _SeaFreq;
      
                const float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);
			
				const float SEA_TIME = sin(_Time.x*0.5);

                float d,h = 0;
                for (int i = 0; i < _SeaOctaves; ++i) {
                    d = sea_octave((uv + SEA_TIME) * SEA_FREQ, SEA_CHOPPY);
                    d += sea_octave((uv - SEA_TIME) * SEA_FREQ, SEA_CHOPPY);
                    h += d * SEA_AMP;
                    uv = mul(uv, octave_m);
                    SEA_FREQ *= 1.9;
                    SEA_AMP *= 0.22;
                    SEA_CHOPPY = lerp(SEA_CHOPPY, 1.0, 0.2);
                }

                return h;
            }
            ENDCG
        }
    }
}
