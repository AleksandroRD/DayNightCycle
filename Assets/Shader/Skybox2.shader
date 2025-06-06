//[Nishita 1993] http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf
//[Nishita 2000] https://www.researchgate.net/publication/242513955_Display_method_of_the_sky_color_taking_into_account_multiple_scattering
Shader "Custom/Skybox2"
{
    Properties
    {
        [Header(Planet Settings)]
        _EarthRadius("Earth Radius(m)", Float) = 6378000.0 //https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
        _AtmosphereRadius("Atmosphere Radius(m)", Float) = 6478000.0 //https://www.grc.nasa.gov/www/k-12/airplane/atmosphere.html
        _ObserverAltitude("Observer Altitude(m)", Float) = 2.0

        [Header(Scattering Settings)]
        _MieG("Mie Anisotropy", Float) = 0.760
        _RayleighScaleHeight("Rayleigh Scale Height", Float) = 8000.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content
        _MieScaleHeight("Mie Scale Height", Float) = 1200.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content

        _Br("Rayleight RGB Scattering", Vector) = (0.0000058, 0.0000135, 0.0000331, 0)
        _Bm("Mie RGB Scattering", Vector) = (0.000021, 0.000021, 0.000021, 0)

        _NumScatteringSamples("Number of Scattering Samples", Integer) = 32
        _NumLightSamples("Number of Light Samples", Integer) = 16

        //[NoScaleOffset] _StarCubeMap ("Star cube map", Cube) = "black" {}
        //_StarExposure ("Star exposure", Range(-16, 16)) = 0

        [Header(Other Planet settings)]
        _SunRadius("Sun Radius", Float) = 695700.0 //https://nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html
        _SunDistance("Distance to the Sun(km)", Float) = 149600000 //https://nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html
        _MoonDistance("Distance to the Moon(km)", Float) = 385000000.6 //https://science.nasa.gov/moon/facts/
        _MoonRadius("Moon Radius", Float) = 1737000.4 //https://science.nasa.gov/moon/facts/

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
            float _SunRadius;
            float _SunDistance;

            //Moon Options
            float _MoonDistance;
            float _MoonRadius;
            float3 _MoonDir;

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

            float GetSunMask(float sunViewDot, float sunRadius)
            {
                float stepRadius = 1 - sunRadius * sunRadius;
                return step(stepRadius, sunViewDot);
            }

            //[Nishita 2000] Page 7
            float rayleighPhaseFunction(float cosTheta)
            {
                return 0.75 * (1.0 + pow(cosTheta,2));
            }

            //[Nishita 1993] Formula 5
            float miePhaseFunction(float cosTheta)
            {
                return (3.0 * (1.0 - _MieG * _MieG) / 2.0 * (2.0 + _MieG * _MieG)) * ((1 + pow(cosTheta,2)) / pow(1.0 + _MieG * _MieG - 2.0 * _MieG * pow(cosTheta,2),1.5));
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

            float getMieDensity(float height){
                return exp(-height / _MieScaleHeight);
            }

            float getRayDensity(float height){
                return exp(-height / _RayleighScaleHeight);
            }

            float GetAltitude(float3 point1){
                return length(point1) - _EarthRadius;
            }

            //[Nishita 2000] Formula 2
            bool calculateOpticalLength(float3 observerPosition, out float rayleighOpticalLength, out float mieOpticalLength)
            {
                float2 atmosphereIntersection = calculateRayAtmosphereIntersection(observerPosition, _SunDir, _AtmosphereRadius);
                float segmentLength = atmosphereIntersection.y  / (float)_NumLightSamples;

                float resultMie = 0;
                float resultRay = 0;

                for (int i = 0; i < _NumLightSamples; i++)
                {
                    float3 samplePoint = observerPosition +  segmentLength * i * _SunDir;
                    float height = GetAltitude(samplePoint);

                    if (height < 0) return false;

                    resultRay += getRayDensity(height) * segmentLength;
                    resultMie += getMieDensity(height) * segmentLength;
                }

                rayleighOpticalLength = resultRay;
                mieOpticalLength = resultMie;
                return true;
            }

            //[Nishita 2000] Formula 1
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
                    float3 samplePoint = origin + segmentLength * (i + 0.5) * direction;
                    float height = GetAltitude(samplePoint);

                    //dencity at the sample point
                    float pr = getRayDensity(height) * segmentLength;
                    float pm = getMieDensity(height) * segmentLength;

                    opticalDepthRayToSample += pr;
                    opticalDepthMieToSample += pm;

                    float opticalLenghtRayAtmosphere = 0.0;
                    float opticalLenghtMieAtmosphere = 0.0;

                    if(!calculateOpticalLength(samplePoint, opticalLenghtRayAtmosphere, opticalLenghtMieAtmosphere))
                    {
                        continue;
                    }

                    //[Nishita 2000] Page 7 (R formula)
                    float3 r = _Br * pr * Fr + _Bm * pm * Fm;

                    //[Nishita 2000] Formula 2
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
                float sunViewDot01 = (sunViewDot + 1.0) * 0.5;

                //float3 starColor = texCUBE(_StarCubeMap, IN.viewDirection).xyz;
                //starColor *= (1 - sunViewDot01) * saturate( -_SunDir.y) * exp2(_StarExposure);

                //Moon
                float moonIntersection = sphereIntersection(observerPosition, viewDirection, _MoonDir * _MoonDistance, _MoonRadius);
                float moonMask = moonIntersection > -1? 1 : 0;
                float3 moonNormal = normalize(_MoonDir - viewDirection * moonIntersection);
                float moonNdotL = saturate(dot(moonNormal, _SunDir));
                float3 moonColor = moonMask * moonNdotL;


                //Sun
                float sunMask = sunViewDot  > cos(asin(_SunRadius / _SunDistance)) ? 1 : 0;
                float3 sunColor = (1,1,1) * sunMask;

                //Sky
                float3 skycolor = calculateLightIntensity(observerPosition, viewDirection);
                skycolor = skycolor / (1 + skycolor);
                float3 color = skycolor + sunColor + moonColor;
                
                return float4(color, 1);
            }

            ENDHLSL
        }
    }
    Fallback Off
}
