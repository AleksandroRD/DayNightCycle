//OS - Object space
//WS - World space
//CS - Clip space

Shader "Custom/Skybox1"
{   
    Properties
    {
        _EarthRadius("Earth Radius", Float) = 63600000.0
        _AtmosphereRadius("Atmosphere Radius", Float) = 64200000.0

        _ObserverAltitude("Observer Altitude", Float) = 2.0

        _SunRadius("Sun Radius", Float) = 5000.0
        _SunIntensity("Sun Intensity", Float) = 10.0

        [Header(Atmoshere Setting)]
        _G("Mie Anisotropy", Float) = 0.760
        _Hr("Rayleight Atmosphere Thikness", Float) = 7994.0
        _Hm("Mie Atmosphere Thikness", Float) = 1200.0
        _MieScale("Mie Scale", Float) = 1.11
        _BetaR("Rayleight RGB Scattering", Vector) = (0.0000058, 0.00000135, 0.00000331, 0)
        _BetaM("Mie RGB Scattering", Vector) = (0.0000021, 0.0000021, 0.0000021, 0)

        _NumScatteringSamples("Number of Scattering Samples", Integer) = 16
        _NumLightSamples("Number of Light Samples", Integer) = 8
    }

    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" "ForceNoShadowCasting" = "True" }

        Cull Off ZWrite Off

        Pass
        {

            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment

            #include "UnityCG.cginc"

            struct VertexInput
            {
                float3 vertexPositionOS          : POSITION;
                float4 uv                        : TEXCOORD0;
            };

            struct FragmentInput
            {
                float4 vertexPosition            : SV_POSITION;
                float3 viewDirection             : TEXCOORD0;
            };
            
            FragmentInput vertex(VertexInput IN)
            {
                FragmentInput OUT;

                OUT.vertexPosition = UnityObjectToClipPos(IN.vertexPositionOS);
                OUT.viewDirection = IN.uv;
            
                return OUT;
            }

            //Math
            #define PI 3.1415926535
            const static float INF = 9.0e9; 
        
            //General options
            float _ObserverAltitude;
        
            //Sun Options
            float _SunRadius;
            float3 _SunDir;
            float _SunIntensity;

            //Earth options
            float _EarthRadius;
            float _AtmosphereRadius;
            
            //Atmosphere Options
            float _Hr = 7994.0, _Hm = 1200.0; // Atmosphire thiknes for rayleight and mie
            float _G = 0.760;
            float _MieScale = 1.11;
            float3 _BetaR = float3(5.8e-6, 13.5e-6, 33.1e-6);
            float3 _BetaM = float3(21e-6, 21e-6, 21e-6);
            // [Hillaire16]
            static const float3 betaO0 = float3(3.426, 8.298, 0.356) * 6e-7;
        
            //Quality options
            int _NumScatteringSamples = 16;
            int _NumLightSamples = 8;

            float ComputePhaseRayleigh(float mu)
            {
                return 3.0 / (16.0 * PI) * (1.0 + mu * mu);
            }
        
            float ComputePhaseMie(float mu, float _G)
            {
                return 3.0 / (8.0 * PI) * ((1 - _G * _G) * (1 + mu * mu)) / ((2 + _G * _G)*pow(1 + _G * _G - 2 * _G * mu, 1.5));
            }
        
            float2 ComputeRaySphereIntersection(float3 origin, float3 direction, float sphereRadius)
            {
                float a = dot(direction, direction);
	            float b = 2.0 * dot(direction, origin);
	            float c = dot(origin, origin) - (sphereRadius * sphereRadius);
	            float d = (b * b) - 4.0 * a * c;
                        
	            if (d < 0.0)
	            	return float2(1.0, -1.0);
                        
	            return float2
	            (
	            	(-b - sqrt(d)) / (2.0 * a),
	            	(-b + sqrt(d)) / (2.0 * a)
	            );
            }
        
            bool ComputeOpticalDepthLight(float3 samplePosition, float2 atmoshereIntersection, out float rayleighOpticalDepth, out float mieOpticalDepth)
            {

            	float lmin = 0.0;
            	float lmax = atmoshereIntersection.y;

            	float segmentLength = (lmax - lmin) / _NumLightSamples;

            	float r = 0;
            	float m = 0;

            	for (int i = 0; i < _NumLightSamples; i++)
            	{
            		float3 sampleDirection = samplePosition + segmentLength * i * _SunDir;
            		float height = length(sampleDirection) - _EarthRadius;
                    
            		if (height < 0) return false;

            		r += exp(-height / _Hr) * segmentLength;
            		m += exp(-height / _Hm) * segmentLength;
            	}

            	rayleighOpticalDepth = r;
            	mieOpticalDepth = m;

            	return true;

            }
        
            float3 ComputeIncidentLight(float3 origin, float3 direction, float3 sunIntensity, float tmin, float tmax)
            {
                float2 t = ComputeRaySphereIntersection(origin, direction, _AtmosphereRadius);
                 
                tmin = max(t.x, tmin);
                tmax = min(t.y, tmax);
                
                if (tmax < 0) discard;
                
                float opticalDepthR = 0.0;
                float opticalDepthM = 0.0;
                float segmentLength = (tmax - tmin) / (float)_NumScatteringSamples;

                float3 sumR = float3(0, 0, 0);
                float3 sumM = float3(0, 0, 0);
                
                for (int s = 0; s < _NumScatteringSamples; s++)
                {
                    float3 samplePosition = origin + (segmentLength * s * 0.5) * direction;
                    float height = length(samplePosition) - _EarthRadius;

                    // compute optical depth for light
                    float hr = exp(-height / _Hr) * segmentLength;
                    float hm = exp(-height / _Hm) * segmentLength;
                    
                    opticalDepthR += hr;
                    opticalDepthM += hm;
                
                    // find intersect sun lit with atmosphere
                    float2 tl = ComputeRaySphereIntersection(samplePosition, _SunDir, _AtmosphereRadius);
                    
                    // light delta segment 
                    float opticalDepthLightR = 0.0;
                    float opticalDepthLightM = 0.0;
                
                    if (!ComputeOpticalDepthLight(samplePosition, tl, opticalDepthLightR, opticalDepthLightM))
                        continue;
                    
                    // It claims that ozone has 0 scattering (absorption only) [Gustav14](above eq.8)
                    // and beta is similar to hr (= with similar distribution) [Hillaire16]
                    // so, reuse optical depth for rayleigh
                    float3 tauO = betaO0 * (opticalDepthR + opticalDepthLightR);
                    
                    float3 tauR = _BetaR * (opticalDepthR + opticalDepthLightR);
                    float3 tauM = _MieScale * _BetaM * (opticalDepthM + opticalDepthLightM);
                    float3 attenuation = exp(-(tauR + tauM + tauO));              

                    sumR += attenuation * hr;
                    sumM += attenuation * hm;
                }
            
                float mu = dot(_SunDir, direction);
                float phaseR = ComputePhaseRayleigh(mu);
                float phaseM = ComputePhaseMie(mu, _G);

                return sunIntensity * (sumR * phaseR * _BetaR + sumM * phaseM * _BetaM);
            }
        
        
            float4 fragment(FragmentInput IN) : SV_TARGET
            {   
                float3 direction = normalize(IN.viewDirection);
                float3 observerPosition = float3(0, _EarthRadius + _ObserverAltitude, 0);
            
                float3 color = ComputeIncidentLight(observerPosition, direction, _SunIntensity, 0, INF);

                return float4(color,1);
            }
            
            ENDHLSL

        }

    }

    Fallback Off
}
