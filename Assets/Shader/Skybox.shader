Shader "Custom/Skybox"
{
    Properties
    {
        [Header(Ground Halo Settings)]
        _GroundHaloDistance ("Ground Halo Distanse", Float) = 4.0

        [Header(Sun Settings)]
        _SunRadius ("Sun Radius", Range(0,1)) = 0.05
        _SunColor ("Sun Color", Color) = (.25, .5, .5, 1)
        _SunHaloRadius ("Sun Halo Radius", Float) = 4.0
        _TransitionSmoothness("Transition Smoothness",Float) = 1.5

        [Header(Moon Settings)]
        _MoonExposure ("Moon exposure", Range(-16, 16)) = 0
        _MoonRadius ("Moon Radius", Range(0,1)) = 0.05
        [NoScaleOffset] _MoonCubeMap ("Moon cube map", Cube) = "black" {}

        [Header(Star Settings)]
        [NoScaleOffset] _StarCubeMap ("Star cube map", Cube) = "black" {}
        _StarExposure ("Star exposure", Range(-16, 16)) = 0
        _StarPower ("Star power", Range(1,5)) = 1
        _StarLatitude ("Star latitude", Range(-90, 90)) = 0
        
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
            float _SunRadius,_SunHaloRadius,_TransitionSmoothness;
            float _GroundHaloDistance;
            float4x4 _MoonSpaceMatrix;
            float _MoonExposure, _StarExposure, _MoonRadius;
            float _StarPower, _StarLatitude, _StarSpeed;
            float4 _SunColor;

            TEXTURE2D(_SunZenithGrad);      SAMPLER(sampler_SunZenithGrad);
            TEXTURE2D(_ViewZenithGrad);     SAMPLER(sampler_ViewZenithGrad);
            TEXTURE2D(_SunViewGrad);        SAMPLER(sampler_SunViewGrad);
            TEXTURECUBE(_MoonCubeMap);      SAMPLER(sampler_MoonCubeMap);
            TEXTURECUBE(_StarCubeMap);      SAMPLER(sampler_StarCubeMap);
            
            // From: https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
            float3x3 AngleAxis3x3(float angle, float3 axis)
            {
                float c, s;
                sincos(angle, s, c);
            
                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;
            
                return float3x3(
                    t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                    t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                    t * x * z - s * y, t * y * z + s * x, t * z * z + c
                    );
            }

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

            float3 GetStarUVW(float3 viewDir, float latitude, float localSiderealTime)
            {
               // tilt = 0 at the north pole, where latitude = 90 degrees
               float tilt = PI * (latitude - 90) / 180;
               float3x3 tiltRotation = AngleAxis3x3(tilt, float3(1,0,0));
            
               // 0.75 is a texture offset for lST = 0 equals noon
               float spin = (0.75-localSiderealTime) * 2 * PI;
               float3x3 spinRotation = AngleAxis3x3(spin, float3(0, 1, 0));
            
               // The order of rotation is important
               float3x3 fullRotation = mul(spinRotation, tiltRotation);
            
               return mul(fullRotation,  viewDir);
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
                float3 sunColor = _SunColor.rgb * sunMask;

                //moon
                float moonIntersect = sphIntersect(viewDir, _MoonDir, _MoonRadius);
                float moonMask = moonIntersect > -1 ? 1 : 0;

                float3 moonNormal = normalize(_MoonDir - viewDir * moonIntersect);
                float moonNdotL = saturate(dot(moonNormal, -_SunDir));

                float3 moonTexture = GetMoonTexture(moonNormal);

                float3 moonColor = moonMask * moonNdotL * exp2(_MoonExposure) * moonTexture;

                // The stars
                float3 starUVW = GetStarUVW(viewDir, _StarLatitude, _Time.y * _StarSpeed % 1);
                float3 starColor = SAMPLE_TEXTURECUBE_BIAS(_StarCubeMap, sampler_StarCubeMap, starUVW, -1).rgb;
                float starStrength = (1 - sunViewDot01) * (saturate(-sunZenithDot));
                starColor = pow(abs(starColor), _StarPower);
                starColor *= (1 - sunMask) * (1 - moonMask) * exp2(_StarExposure) * starStrength;
                
                float3 col = sunColor + skyColor + moonColor + starColor;
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}