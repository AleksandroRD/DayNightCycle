Shader "Custom/Skybox"
{
    Properties
    {
        [NoScaleOffset] _SunZenithGrad ("Sun-Zenith gradient", 2D) = "white" {}
        [NoScaleOffset] _ViewZenithGrad ("View-Zenith gradient", 2D) = "white" {}
        [NoScaleOffset] _SunViewGrad ("Sun-View gradient", 2D) = "white" {}

        _SunRadius ("Sun Radius", Range(0,1)) = 0.05
        
        _MainLightColor ("Sun Color", Color) = (.25, .5, .5, 1)
        _SunHaloRadius ("Sun Halo Radius", Float) = 4.0
        _GroundHaloDistance ("Ground Halo Distanse", Float) = 4.0

        _TransitionSmoothness("Transition Smoothness",Float) = 1.5

        _MoonExposure ("Moon exposure", Range(-16, 16)) = 0
        _MoonRadius ("Moon Radius", Range(0,1)) = 0.05

        [NoScaleOffset] _MoonCubeMap ("Moon cube map", Cube) = "black" {}
        [NoScaleOffset] _StarCubeMap ("Star cube map", Cube) = "black" {}
        _StarExposure ("Star exposure", Range(-16, 16)) = 0
        _StarPower ("Star power", Range(1,5)) = 1
        
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 posOS    : POSITION;
            };

            struct v2f
            {
                float4 posCS        : SV_POSITION;
                float3 viewDirWS    : TEXCOORD0;
            };
            
            v2f Vertex(Attributes IN)
            {
                v2f OUT = (v2f)0;
    
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.posOS.xyz);
    
                OUT.posCS = vertexInput.positionCS;
                OUT.viewDirWS = vertexInput.positionWS;

                return OUT;
            }

            float3 _SunDir, _MoonDir;
            float _SunRadius, _MoonRadius;
            float _SunHaloRadius,_GroundHaloDistance;
            float _TransitionSmoothness;
            float4x4 _MoonSpaceMatrix;
            float _MoonExposure, _StarExposure;
            float _StarPower;

            TEXTURE2D(_SunZenithGrad);      SAMPLER(sampler_SunZenithGrad);
            TEXTURE2D(_ViewZenithGrad);     SAMPLER(sampler_ViewZenithGrad);
            TEXTURE2D(_SunViewGrad);        SAMPLER(sampler_SunViewGrad);
            TEXTURECUBE(_MoonCubeMap);      SAMPLER(sampler_MoonCubeMap);
            TEXTURECUBE(_StarCubeMap);      SAMPLER(sampler_StarCubeMap);

            float GetSunMask(float sunViewDot, float sunRadius)
            {
                float stepRadius = 1 - sunRadius * sunRadius;
                return step(stepRadius, sunViewDot);
            }

            float3 GetMoonTexture(float3 normal)
            {   
                //correction of texture(it rotates if not corrected)
                float3 uvw = mul(_MoonSpaceMatrix, float4(normal,0)).xyz;
                float3x3 correctionMatrix = float3x3(0, -0.2588190451, -0.9659258263,
                    0.08715574275, 0.9622501869, -0.2578341605,
                    0.9961946981, -0.08418598283, 0.02255756611);
                uvw = mul(correctionMatrix, uvw);
                
                return SAMPLE_TEXTURECUBE(_MoonCubeMap, sampler_MoonCubeMap, uvw).rgb;
            }

            float sphIntersect(float3 rayDir, float3 spherePos, float radius)
            {
                float3 oc = -spherePos;
                float b = dot(oc, rayDir);
                float c = dot(oc, oc) - radius * radius;
                float h = b * b - c;
                if(h < 0.0) return -1.0;
                h = sqrt(h);
                return -b - h;
            }

            float4 Fragment (v2f IN) : SV_TARGET
            {
                float3 viewDir = normalize(IN.viewDirWS);

                float sunViewDot = dot(_SunDir, viewDir);
                float sunZenithDot = _SunDir.y;
                float viewZenithDot = viewDir.y;
                float sunMoonDot = dot(_SunDir, _MoonDir);

                float sunViewDot01 = (sunViewDot + 1.0) * 0.5;
                float sunZenithDot01 = (sunZenithDot + 1.0) * 0.5;

                float3 sunZenithColor = SAMPLE_TEXTURE2D(_SunZenithGrad, sampler_SunZenithGrad, float2(sunZenithDot01, 0.5)).rgb;

                //world halo
                float3 viewZenithColor = SAMPLE_TEXTURE2D(_ViewZenithGrad, sampler_ViewZenithGrad, float2(sunZenithDot01, 0.5)).rgb;
                float vzMask = saturate(1.0 - viewZenithDot)* exp(_GroundHaloDistance);

                //sun halo
                float3 sunViewColor = SAMPLE_TEXTURE2D(_SunViewGrad, sampler_SunViewGrad, float2(sunZenithDot01, 0.5)).rgb;
                float svMask = pow(saturate(sunViewDot),_TransitionSmoothness) * exp(_SunHaloRadius);

                float3 skyColor = sunZenithColor + vzMask * viewZenithColor + svMask * sunViewColor;
                
                // sun
                float sunMask = GetSunMask(sunViewDot, _SunRadius);
                float3 sunColor = _MainLightColor.rgb * sunMask;
                
                //moon
                float moonIntersect = sphIntersect(viewDir, _MoonDir, _MoonRadius);
                float moonMask = moonIntersect > -1 ? 1 : 0;

                float3 moonNormal = normalize(_MoonDir - viewDir * moonIntersect);
                float moonNdotL = saturate(dot(moonNormal, -_SunDir));

                float3 moonTexture = GetMoonTexture(moonNormal);

                float3 moonColor = moonMask * moonNdotL * exp2(_MoonExposure) * moonTexture;

                // The stars
                float3 starUVW = viewDir;
                float3 starColor = SAMPLE_TEXTURECUBE_BIAS(_StarCubeMap, sampler_StarCubeMap, starUVW, -1).rgb;
                float starStrength = (1 - sunViewDot01) * (saturate(-sunZenithDot));
                starColor = pow(abs(starColor), _StarPower);
                starColor *= (1 - sunMask) * (1 - moonMask) * exp2(_StarExposure) * starStrength;
                
                float3 col = skyColor + sunColor + moonColor + starColor;
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}