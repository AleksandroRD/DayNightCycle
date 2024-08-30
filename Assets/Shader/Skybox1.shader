//OS - Object space
//WS - World space
//CS - Clip space

Shader "Custom/Skybox1"
{   
    Properties
    {
        [Header(Earth Settings)]
        _EarthRadius("Earth Radius",Float) = 63600000.0
        _AtmosphereRadius("Atmosphere Radius",Float) = 64200000.0

        [Header(General Settings)]
        _ObserverAltitude("Observer Altitude",Float) = 2.0

        [Header(Sun Settings)]
        _SunRadius("Sun Radius",Float) = 5000.0
        _SunIntensity("Sun Intensity",Float) = 10.0

    }

    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }

        Cull Off ZWrite Off ZTest Always

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
            #define RAYLEIGH_SCTR_ONLY_ENABLE 0

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
            static const float3 _EarthCenter = (0.0,0.0,0.0);
            float _EarthRadius;
            float _AtmosphereRadius;
            
            //Atmosphere Options
            static const float Hr = 7994.0, Hm = 1200.0; // Atmosphire thiknes for rayleight and mie
            static const float g = 0.760;
            static const float mieScale = 1.11;
            static const float3 betaR = float3(5.8e-6, 13.5e-6, 33.1e-6);
            static const float3 betaM = float3(21e-6, 21e-6, 21e-6);
            // [Hillaire16]
            static const float3 betaO0 = float3(3.426, 8.298, 0.356) * 6e-7;
            static const float3 mOzoneMassParams = float3(0.6e-6, 0.0, 0.9e-6) * 2.504;
            static const float mOzoneMass = mOzoneMassParams.x;
            static const float3 mOzoneScatteringCoeff = float3(1.36820899679147, 3.31405330400124, 0.13601728252538);
        
            //Quality options
            static const bool uChapman = false;
            static const int numScatteringSamples = 16;
            static const int numLightSamples = 8;
  
            float ComputePhaseRayleigh(float mu)
            {
                return 3.0 / (16.0 * PI) * (1.0 + mu * mu);
            }
        
            float ComputePhaseMie(float mu, float g)
            {
                return 3.0 / (8.0 * PI) * ((1 - g * g) * (1 + mu * mu)) / ((2 + g * g)*pow(1 + g * g - 2 * g * mu, 1.5));
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
        
            float ChapmanApproximation(float X, float h, float coschi)
            {
            	float c = sqrt(X + h);
            	if (coschi >= 0.0)
            	{
            		return	c / (c*coschi + 1.0) * exp(-h);
            	}
            	else
            	{
            		float x0 = sqrt(1.0 - coschi * coschi) * (X + h);
            		float c0 = sqrt(x0);
            		return 2.0 * c0 * exp(X - x0) - c / (1.0 - c * coschi) * exp(-h);
            	}
            }
        
            bool opticalDepthLight(float3 s, float2 t, out float rayleigh, out float mie)
            {
            	if (!uChapman)
            	{
            		// start from position 's'
            		float lmin = 0.0;
            		float lmax = t.y;
            		float segmentLength = (lmax - lmin) / numLightSamples;
            		float r = 0.f;
            		float m = 0.f;
            		for (int i = 0; i < numLightSamples; i++)
            		{
            			float3 samplePosition = s + segmentLength * i * _SunDir;
            			float height = length(samplePosition) - _EarthRadius;
            			if (height < 0) return false;
            			r += exp(-height / Hr) * segmentLength;
            			m += exp(-height / Hm) * segmentLength;
            		}
            		rayleigh = r;
            		mie = m;
            		return true;
            	}
            	else
            	{
            		// approximate optical depth with chapman function  
            		float x = length(s);
            		float Xr = _EarthRadius / Hr; 
            		float Xm = _EarthRadius / Hm;
            		float coschi = dot(s/x, _SunDir);
            		float xr = x / Hr;
            		float xm = x / Hm;
            		float hr = xr - Xr;
            		float hm = xm - Xm;

            		rayleigh = ChapmanApproximation(Xr, hr, coschi);
            		mie = ChapmanApproximation(Xm, hm, coschi);
            		return true;
            	}
            }
        
            float3 ComputeIncidentLight(float3 origin, float3 direction, float3 sunIntensity, float tmin, float tmax)
            {
                float2 t = ComputeRaySphereIntersection(origin, direction, _AtmosphereRadius);
                 
                tmin = max(t.x, tmin);
                tmax = min(t.y, tmax);
                
                if (tmax < 0) discard;
                
                float opticalDepthR = 0.0;
                float opticalDepthM = 0.0;
                float segmentLength = (tmax - tmin) / (float)numScatteringSamples;

                float3 sumR = float3(0, 0, 0);
                float3 sumM = float3(0, 0, 0);
                
                for (int s = 0; s < numScatteringSamples; s++)
                {
                    float3 samplePosition = origin + (segmentLength * s * 0.5) * direction;
                    float height = length(samplePosition) - _EarthRadius;

                    // compute optical depth for light
                    float hr = exp(-height / Hr) * segmentLength;
                    float hm = exp(-height / Hm) * segmentLength;
                    
                    opticalDepthR += hr;
                    opticalDepthM += hm;
                
                    // find intersect sun lit with atmosphere
                    float2 tl = ComputeRaySphereIntersection(samplePosition, _SunDir, _AtmosphereRadius);
                    
                    // light delta segment 
                    float opticalDepthLightR = 0.0;
                    float opticalDepthLightM = 0.0;
                
                    if (!opticalDepthLight(samplePosition, tl, opticalDepthLightR, opticalDepthLightM))
                        continue;
                    
                #if RAYLEIGH_SCTR_ONLY_ENABLE 
                    // But, in 'Time of day.conf' state that ozone also has small scattering factor
                    // And use rayleigh beta only
                    float3 lambda = betaR + betaM + mOzoneScatteringCoeff * mOzoneMass;
                    float3 tau = lambda * (opticalDepthR + opticalDepthLightR);
                    float3 attenuation = exp(-(tau));
                #else
                    // It claims that ozone has 0 scattering (absorption only) [Gustav14](above eq.8)
                    // and beta is similar to hr (= with similar distribution) [Hillaire16]
                    // so, reuse optical depth for rayleigh
                    float3 tauO = betaO0 * (opticalDepthR + opticalDepthLightR);
                    
                    float3 tauR = betaR * (opticalDepthR + opticalDepthLightR);
                    float3 tauM = mieScale * betaM * (opticalDepthM + opticalDepthLightM);
                    float3 attenuation = exp(-(tauR + tauM + tauO));
                    
                #endif

                    sumR += attenuation * hr;
                    sumM += attenuation * hm;
                }
            
                float mu = dot(_SunDir, direction);
                float phaseR = ComputePhaseRayleigh(mu);
                float phaseM = ComputePhaseMie(mu, g);

                return sunIntensity * (sumR * phaseR * betaR + sumM * phaseM * betaM);
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
