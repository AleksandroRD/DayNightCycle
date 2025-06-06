Shader "Custom/Skybox3"
{
    Properties
    {
        _EarthRadius("Earth Radius", Float) = 6378000.0 //https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
        _AtmosphereRadius("Atmosphere Radius", Float) = 6478000.0 //https://www.grc.nasa.gov/www/k-12/airplane/atmosphere.html
        _ObserverAltitude("Observer Altitude", Float) = 2.0

        _MieG("Mie Anisotropy", Float) = 0.760
        _RayleighScaleHeight("Rayleigh Scale Height", Float) = 8000.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content
        _MieScaleHeight("Mie Scale Height", Float) = 1200.0 //https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content

        _Br("Rayleight RGB Scattering", Vector) = (0.00000655, 0.0000173, 0.0000230, 0) //[chalmers] 3.2.2
        _Bm("Mie RGB Scattering", Vector) = (0.000021, 0.000021, 0.000021, 0) //[chalmers] 3.2.2

        _NumSingleScatteringSamples("Number of Single Scattering Samples", Integer) = 32
        _NumDencitySamples("Number of Light Samples", Integer) = 16
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
            #define PI 3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679
            const static float INF = 9.0e38; 

            float _ObserverAltitude;

            //Sun Options
            float3 _SunDir;

            //Earth options
            float _EarthRadius;
            float _AtmosphereRadius;

            //Quolity options
            int _NumSingleScatteringSamples;
            int _NumDencitySamples;

            //Atmosphere options
            float _RayleighScaleHeight;
            float _MieScaleHeight;
            float _MieG;
            float3 _Br;
            float3 _Bm;

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
            
            //[chalmers] 4
            float rayleighPhaseFunction(float cosTheta)
            {
                return 0.75 * (1.0 + pow(cosTheta,2));
            }

            //[chalmers] 5
            float miePhaseFunction(float cosTheta)
            {
                return (3.0 * (1.0 - _MieG * _MieG) / 2.0 * (2.0 + _MieG * _MieG)) * ((1 + pow(cosTheta,2)) / pow(1 + _MieG * _MieG - 2 * _MieG * pow(cosTheta,2),1.5));
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

            //[chalmers] 7
            float3 calculateTransmitance(float3 point1, float3 point2){
                float  stepSize = length(point2 - point1) / _NumDencitySamples;
                float3 direction = normalize(point2 - point1);

                float  mieSum   = 0.0;
                float  raySum   = 0.0;

                float  height       = GetAltitude(point1);
                float  previousMie  = getMieDensity(height);
                float  previousRay  = getRayDensity(height);

                for(int i = 1; i < _NumDencitySamples; i++)
                {
                    float3  samplePoint  = point1 + i * stepSize * direction;
                    float   height       = GetAltitude(samplePoint);

                    if(height < 0){ continue; }
                    
                    float   currentMie   = getMieDensity(height);
                    float   currentRay   = getRayDensity(height);

                    mieSum += (currentMie + previousMie) * 0.5 * stepSize;
                    raySum += (currentRay + previousRay) * 0.5 * stepSize;

                    previousMie = currentMie;
                    previousRay = currentRay;
                }

                return exp(-(raySum * _Br + mieSum * _Bm / 0.9));
            }
            
            //[chalmers] 11
            void gatherLight(float3 origin, out float rayleighOpticalLength, out float mieOpticalLength){
                
                for(int i = 0; i < _NumSingleScatteringSamples; i++){

                }
            }

            //[chalmers] 9
            float3 calculateSingleScatering(float3 origin, float3 direction){
                float2 intersectAtmosph = calculateRayAtmosphereIntersection(origin, direction, _AtmosphereRadius);
                float stepSize = length(direction * intersectAtmosph.y - direction * intersectAtmosph.x) / _NumSingleScatteringSamples;
                
                float3 sampleOrigin;

                if(intersectAtmosph.x < 0 && intersectAtmosph.y < 0){       // ray haven't hit the atmosphere 
                    return (0,0,0);
                }else if(intersectAtmosph.x < 0 && intersectAtmosph.y > 0){ // ray origin is inside atmosphere
                    sampleOrigin = origin;
                }else{                                                     // ray origin is outside atmosphere 
                    sampleOrigin = origin + direction * intersectAtmosph.x;
                }

                float3  previousRay = 0;
                float3  previousMie = 0;

                float height = GetAltitude(sampleOrigin);

                float3 sumRay = getRayDensity(height);
                float3 sumMie = getMieDensity(height);

                //float2 intersectSun             = calculateRayAtmosphereIntersection(sampleOrigin, _SunDir, _AtmosphereRadius);
                //float3 transmitanceToSun        = calculateTransmitance(samplePoint, samplePoint + _SunDir * intersectSun.y);
                //float3 transmitanceToSample     = calculateTransmitance(sampleOrigin, samplePoint);

                for(int i = 1; i < _NumSingleScatteringSamples; i++){
                    float3  samplePoint  = sampleOrigin + i * stepSize * direction;
                    float   height       = GetAltitude(samplePoint);

                    if(height < 0){ return(0,0,0); }

                    float2 intersectSun             = calculateRayAtmosphereIntersection(sampleOrigin, _SunDir, _AtmosphereRadius);
                    float3 transmitanceToSun        = calculateTransmitance(samplePoint, samplePoint + _SunDir * intersectSun.y);
                    float3 transmitanceToSample     = calculateTransmitance(sampleOrigin, samplePoint);
                    
                    // fix that transmitanceToSample is zero at the first iteration
                    float3  currentRay    = getRayDensity(height) * transmitanceToSun * transmitanceToSample;
                    float3  currentMie    = getMieDensity(height) * transmitanceToSun * transmitanceToSample;

                    sumRay += (currentRay + previousRay) * 0.5 * stepSize;
                    sumMie += (currentMie + previousMie) * 0.5 * stepSize;

                    previousRay = currentRay;
                    previousMie = currentMie;
                }

                float cosTheta = dot(_SunDir, direction);

                sumRay *= _Br / (4 * PI) * rayleighPhaseFunction(cosTheta) ;
                sumMie *= _Bm / (4 * PI) * miePhaseFunction(cosTheta);

                return (sumMie + sumRay);
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

                float3 color = calculateSingleScatering(observerPosition, viewDirection);

                color = color/(1 + color);
                return float4(color, 1);
            }

            ENDHLSL
        }
    }
    Fallback Off
}
