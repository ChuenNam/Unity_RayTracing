Shader "RayTracing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            //物体材质
            struct ObjectMaterial{
                float4 color;
                float4 emissionColor;
                float emissionStrength;
            };
            //定义球体 >> 需要和外部结构体顺序保持一致!!!
            struct Sphere{
                float3 position;
                float radius;
                ObjectMaterial material;
            };
            //射线信息
            struct Ray{
                float3 origin;
                float3 dir;
            };
            //射线检测信息
            struct HitInfo{
                bool didHit;        //是否击中
                float dis;          //距离
                float3 hitPoint;    //交点坐标
                float3 normal;      //交点法线
                ObjectMaterial material;
            };


            //计算射线和球的交集
            HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius) {
                HitInfo hitInfo = (HitInfo)0;
                float3 offsetRayOrigin = ray.origin - sphereCenter;     //球心指向射线点的向量

                float a = dot(ray.dir, ray.dir);
                float b = 2 * dot(offsetRayOrigin, ray.dir);
                float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
                float discriminant = b * b - 4 * a * c;     //判别式

                //判别式 >=0 时方程有解，与球相交
                if(discriminant >= 0) {
                    float dis = (-b - sqrt(discriminant)) / (2 * a);    //距离公式
                    //忽略射线后的交点
                    if(dis >= 0) {
                        hitInfo.didHit = true;
                        hitInfo.dis = dis;
                        hitInfo.hitPoint = ray.origin + ray.dir * dis;
                        hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
                    }
                }
                return hitInfo;
            }

            StructuredBuffer<Sphere> Spheres;     //球体信息缓冲区
            int Num;    //球体个数
            //找到射线第一个碰到的点，并返回碰撞信息
            HitInfo CalculateRayColl(Ray ray) {
                HitInfo closestHit = (HitInfo)0;
                closestHit.dis = 1.#INF;

                for(int i = 0; i < Num; i++){
                    Sphere sphere = Spheres[i];
                    HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

                    if(hitInfo.didHit && hitInfo.dis < closestHit.dis){
                        closestHit = hitInfo;
                        closestHit.material = sphere.material;
                    }
                }
                return closestHit;
            }

            //随机数生成器
            float RandomValue(inout uint state){
                // state *= (state + 195439) * (state + 547913) * (state + 910307);
                // return state /4294967295.0;

                state = state * 747796405 + 281336453;
                uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
                result = (result >> 22) ^ result;
                return result / 4294967295.0;
            }

            //返回正态分布的随机数
            float RandomValueNormalDistribution(inout uint state){
                float theta = 2 * 3.1415926 * RandomValue(state);
                float rho = sqrt(-2 * log(RandomValue(state)));
                return rho * cos(theta);
            }
            
            //计算随机方向
            float3 RandomDirection(inout uint state) {
                float x = RandomValueNormalDistribution(state);
                float y = RandomValueNormalDistribution(state);
                float z = RandomValueNormalDistribution(state);
                return normalize(float3(x,y,z));
            }

            //围绕给出法向的半球内随即方向
            float3 RandomHemisphereDirection(float3 normal, inout uint rngstate){
                float3 dir = RandomDirection(rngstate);
                return dir * sign(dot(normal, dir));
            }

            int MaxBounceCount;
            //追踪函数
            float3 Trace(Ray ray, inout uint rng){

                float3 incomingLight = 0;
                float3 rayColor = 1;

                for (int i = 0; i <= MaxBounceCount; i++){
                    HitInfo hitInfo = CalculateRayColl(ray);
                    if(hitInfo.didHit){
                        ray.origin = hitInfo.hitPoint;
                        ray.dir = RandomHemisphereDirection(hitInfo.normal, rng);

                        ObjectMaterial material = hitInfo.material;
                        float3 emittedLight = material.emissionColor * material.emissionStrength;
                        incomingLight += emittedLight * rayColor;
                        rayColor *= material.color;
                    }
                    else{
                        break;
                    }
                }

                return incomingLight;
            }


            sampler2D _MainTex;
            float4 _MainTex_ST;
            float3 ViewParam;
            float4x4 CamLocalToWorldMatrix; 

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //Random(noisy)
                uint2 numPixel = uint2(1920,1080);
                uint2 pixelCoord = i.uv * numPixel;
                uint pixelIndex = pixelCoord.y * numPixel.x + pixelCoord.x;
                uint rng = pixelIndex;

                //创建射线
                float3 viewPointLocal = float3(i.uv - 0.5, 1) * ViewParam;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(viewPoint - ray.origin);
                // return CalculateRayColl(ray).material.color;

                float3 pixelCol = Trace(ray, rng);
                return float4(pixelCol, 1);
            }
            ENDCG
        }
    }
}
