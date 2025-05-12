Shader "Custom/Skybox2"
{
    Properties
    {
        _EarthRadius("Earth Radius", Float) = 6378000.0 //https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
        _AtmosphereRadius("Atmosphere Radius", Float) = 6478000.0 //https://www.grc.nasa.gov/www/k-12/airplane/atmosphere.html
        _ObserverAltitude("Observer Altitude", Float) = 2.0

        _MieG("Mie Anisotropy", Float) = 0.760
        _RayleighScaleHeight("Rayleigh Scale Height", Float) = 8000.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content
        _MieScaleHeight("Mie Scale Height", Float) = 1200.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content

        _Br("Rayleight RGB Scattering", Vector) = (0.0000058, 0.0000135, 0.0000331, 0)
        _Bm("Mie RGB Scattering", Vector) = (0.000021, 0.000021, 0.000021, 0)

        _solarRadiation("Spectral distribution of extraterrestrial solar radiation", Vector) = (1.6, 1.9, 2.0, 0)
        _NumScatteringSamples("Number of Scattering Samples", Integer) = 32
        _NumLightSamples("Number of Light Samples", Integer) = 16

        [NoScaleOffset] _StarCubeMap ("Star cube map", Cube) = "black" {}
        _StarExposure ("Star exposure", Range(-16, 16)) = 0
    }
    SubShader
    {
        Pass{
            Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" "ForceNoShadowCasting" = "True" }

            Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex vertex
            #pragma fragment fragment

            #include "UnityCG.cginc"

            //Math
            #define PI 3.1415926535
            const static float INF = 9.0e38; 

            float _ObserverAltitude;

            //Sun Options
            float3 _SunDir;

            //Earth options
            float _EarthRadius;
            float _AtmosphereRadius;

            //Quolity options
            int _NumScatteringSamples;
            int _NumLightSamples;

            //Atmosphere options
            float _RayleighScaleHeight;
            float _MieScaleHeight;
            float _MieG;
            float3 _Br;
            float3 _Bm;
            float3 _solarRadiation;
            
            //Stars
            samplerCUBE _StarCubeMap;
            float _StarExposure;

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
            
            //Fr(θ) = (3/4π)(1 + cos²θ) [Nishita 2000]
            float rayleighPhaseFunction(float cosTheta)
            {
                return 0.75 * (1.0 + pow(cosTheta,2));
            }

            //Fm(θ) = (3 * (1 - g²) * 1 + cos²θ) / ((2 + g²) * (1 + g² - 2 * g * cosθ)^1.5) Formula 5 http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf
            float miePhaseFunction(float cosTheta)
            {
                return 3 * (1 - _MieG * _MieG) * (1 + pow(cosTheta,2)) / pow(2 * (2 + _MieG * _MieG) * (1 + _MieG * _MieG - 2 * _MieG * cosTheta),1.5);
            }

            //https://iquilezles.org/articles/intersectors/ modified
            float2 calculateRayAtmosphereIntersection(float3 origin, float3 direction, float sphereRadius)
            {
                //we don't subtruct sphere center from the origin, because it is (0,0,0)
	            float b = dot(origin, direction);
	            float c = dot(origin, origin) - (sphereRadius * sphereRadius);
	            float d = b * b - c;

                if(d < 0) return float2(-1.0,-1.0);

                return float2(-b - sqrt(d) ,-b + sqrt(d));
            }

            //https://iquilezles.org/articles/intersectors/ modified
            float sphereIntersection(float3 rayOrigin, float3 rayDirection, float3 sherePosition, float radius)
            {
                float3 oc = rayOrigin - sherePosition;
                float b = dot(oc, rayDirection);
                float c = dot(oc, oc) - radius * radius;
                float h = b * b - c;

                if( h < 0.0 ) return -1.0; // no intersection

                return -b - sqrt(h);
            }

            //t(s,λ) = βr(λ)∫ρr(l)dl + βm(λ)∫ρm(l)dl [Nishita 2000 Formula 2]
            bool calculateOpticalLength(float3 observerPosition, float2 atmosphereIntersection, out float rayleighOpticalLength, out float mieOpticalLength)
            {
                float segmentLength = atmosphereIntersection.y  / (float)_NumLightSamples;

                float resultMie = 0;
                float resultRay = 0;

                for (int i = 0; i < _NumLightSamples; i++)
                {
                    float3 samplePosition = observerPosition +  segmentLength * (i + 0.5) * _SunDir;
                    float height = length(samplePosition) - _EarthRadius;

                    if (height < 0) return false;

                    resultRay += exp(-height / _RayleighScaleHeight) * segmentLength;
                    resultMie += exp(-height / _MieScaleHeight) * segmentLength;
                }

                rayleighOpticalLength = resultRay;
                mieOpticalLength = resultMie;
                return true;
            }

            //Iv(λ) = ∫ Is(λ) * R(λ,s,θ) * exp(-t(s,λ)-t(s',λ))ds [Nishita 2000 Formula 1]
            float3 calculateLightIntensity(float3 origin, float3 direction){
                float2 intersectDistance = calculateRayAtmosphereIntersection(origin, direction, _AtmosphereRadius);

                float tmin = max(intersectDistance.x, 0);
                float tmax = min(intersectDistance.y , INF);

                if (tmax < 0) discard;

                float segmentLength = (tmax - tmin) / (float)_NumScatteringSamples;

                float opticalDepthRayToSample = 0;
                float opticalDepthMieToSample = 0;

                float3 sum = (0,0,0);
                float cosTheta = dot(_SunDir, direction);
                float Fr = rayleighPhaseFunction(cosTheta);
                float Fm = miePhaseFunction(cosTheta);

                for(int i = 0; i < _NumScatteringSamples; i++){
                    //add 0.5 to one to be at the middle of the sample
                    float3 samplePosition = origin + segmentLength * (i + 0.5) * direction;
                    float height = length(samplePosition) - _EarthRadius;

                    //dencity at the sample point
                    float pr = exp(-height / _RayleighScaleHeight) * segmentLength;
                    float pm = exp(-height / _MieScaleHeight) * segmentLength;

                    opticalDepthRayToSample += pr;
                    opticalDepthMieToSample += pm;

                    float2 atmosphereIntersection = calculateRayAtmosphereIntersection(samplePosition, _SunDir, _AtmosphereRadius);

                    float opticalLenghtRayAtmosphere = 0.0;
                    float opticalLenghtMieAtmosphere = 0.0;

                    if(!calculateOpticalLength(samplePosition, atmosphereIntersection, opticalLenghtRayAtmosphere, opticalLenghtMieAtmosphere))
                    {
                        continue;
                    }

                    //R(λ,s,θ) = Kr(λ) * ρr(s) * Fr(θ) + Km(λ) * ρm(s) * Fm(θ)
                    float3 r = _Br * pr * Fr + _Bm * pm * Fm;

                    //t(s,λ) = βr(λ)∫ρr(l)dl + βm(λ)∫ρm(l)dl
                    float3 t = _Br * opticalDepthRayToSample + _Bm * opticalDepthMieToSample;
                    float3 t1 = _Br / 0.9 * _Br * opticalLenghtRayAtmosphere + _Bm * opticalLenghtMieAtmosphere;

                    sum +=  r * exp(-t - t1);
                }

                return sum;
            }

            FragmentInput vertex(VertexInput IN)
            {
                FragmentInput OUT;

                OUT.vertexPosition = UnityObjectToClipPos(IN.vertexPositionOS);
                OUT.viewDirection = IN.uv;

                return OUT;
            }

            float4 fragment(FragmentInput IN) : SV_TARGET
            {   
                float3 viewDirection = normalize(IN.viewDirection);
                float3 observerPosition = float3(0, _EarthRadius + _ObserverAltitude, 0);

                float sunViewDot = dot(_SunDir, viewDirection);

                float3 starColor = texCUBE(_StarCubeMap, IN.viewDirection).xyz;
                starColor *= (1 - sunViewDot) * saturate( -_SunDir.y) * exp2(_StarExposure);
                float3 skycolor = calculateLightIntensity(observerPosition, viewDirection);
                float3 color = skycolor + starColor;

                return float4(color, 1);
            }

            ENDHLSL
        }
    }
    Fallback Off
}
