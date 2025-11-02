Shader "Render/RayTracing"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
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
                float smooth;
                float transparency;  // 添加透明度属性 (0=完全不透明, 1=完全透明)
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
            //三角形信息
            struct Triangle{
                float3 posA, posB, posC;
                float3 normalA, normalB, normalC;
            };
            ///网格信息
            struct MeshInfo{
                uint numTriangles;
                float3 boundsMax;
                float3 boundsMin;
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
            int NumSpheres;    //球体个数
            //找到射线第一个碰到的点，并返回碰撞信息
            HitInfo CalculateRayColl(Ray ray) {
                HitInfo closestHit = (HitInfo)0;
                closestHit.dis = 1.#INF;

                for(int i = 0; i < NumSpheres; i++){
                    Sphere sphere = Spheres[i];
                    HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

                    if(hitInfo.didHit && hitInfo.dis < closestHit.dis){
                        closestHit = hitInfo;
                        closestHit.material = sphere.material;
                    }
                }
                return closestHit;
            }

            //计算射线和三角形 >> Möller–Trumbore 算法 (判断射线与三角形是否相交，并计算交点的相关信息)
            HitInfo RayTriangle(Ray ray, Triangle tri){
                float3 AB = tri.posB - tri.posA;
                float3 AC = tri.posC - tri.posA;
                float3 normalVec = cross(AB,AC);
                float3 ao = ray.origin - tri.posA;   //射线点到三角形A点的向量
                float3 dao = cross(ao, ray.dir);     //ao与射线方向的叉积，叉积用来计算射线与三角形相交的几何关系

                float determinant = -dot(ray.dir, normalVec);   //射线方向向量与法向量的点积取负值。这个行列式是计算射线与三角形平面相交的关键值。如果determinant接近零，意味着射线与三角形平面平行，不会相交。
                float invDet = 1 / determinant;     //行列式的倒数，用于加速后续计算。

                //通过射线-三角形相交的几何原理计算了交点的重心坐标(u,v,w)，重心坐标表示了交点在三角形内的相对位置
                float dis = dot(normalVec, ao) * invDet;    //表示射线与三角形平面相交的距离
                float u = dot(AC, dao) * invDet;    //交点相对于三角形的边AC的位置
                float v = -dot(AB, dao) * invDet;   //交点相对于三角形的边AB的位置
                float w = 1 - u - v;

                //初始化Hit信息
                HitInfo hitInfo;
                hitInfo.didHit = determinant >= 1E-6 && dis >= 0 && u >= 0 && v >= 0 && w >= 0;
                hitInfo.hitPoint = ray.origin + ray.dir * dis;
                //交点处的法线，通过插值计算得到。法线是根据三角形三个顶点的法线按重心坐标加权得到的
                hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
                hitInfo.dis = dis;

                return hitInfo;
            } 
            
            //计算射线与网格的BoundingBox关系(AABB算法)
            bool RayBoundingBox(Ray ray, float3 boundsMax, float3 boundsMin) {
                //设置一个小的容差，用于浮点数比较
                float EPSILON = 1e-6;
                //避免除以零的错误，检查 ray.dir 的每个分量是否接近零
                float3 invDir = float3(ray.dir.x != 0 ? 1.0f / ray.dir.x : 0.0f, 
                                       ray.dir.y != 0 ? 1.0f / ray.dir.y : 0.0f,
                                       ray.dir.z != 0 ? 1.0f / ray.dir.z : 0.0f);

                //计算 t0 和 t1，分别是射线与 AABB 的两个边界的交点
                float3 t0 = (boundsMin - ray.origin) * invDir;
                float3 t1 = (boundsMax - ray.origin) * invDir;

                //交换 t0 和 t1，如果 ray.dir 为负
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                //计算射线的进入和退出的 t 值
                float tenter = max(tmin.x, max(tmin.y, tmin.z));
                float texit = min(tmax.x, min(tmax.y, tmax.z));

                //考虑浮点数比较误差，使用 EPSILON 进行调整
                return (tenter <= texit + EPSILON && texit >= 0);
            }

            StructuredBuffer<Triangle> Triangles;
            StructuredBuffer<MeshInfo> AllMeshInfo;
            int NumMeshes;
            //射线与三角形碰撞函数
            HitInfo MeshRayCast(Ray ray) {
                HitInfo closestHit = (HitInfo)0;
                closestHit.dis = 1.#INF;
                int addNum = 0;
                for(int meshIndex = 0; meshIndex < NumMeshes; meshIndex++){
                    MeshInfo meshInfo = AllMeshInfo[meshIndex];
                    if(!RayBoundingBox(ray, meshInfo.boundsMax, meshInfo.boundsMin)){
                        addNum += meshInfo.numTriangles;
                        continue;
                    }

                    for(int i = 0; i < meshInfo.numTriangles; i++){
                        Triangle tri = Triangles[addNum + i];

                        HitInfo hitInfo = RayTriangle(ray, tri);
                        if(hitInfo.didHit && hitInfo.dis < closestHit.dis){
                            closestHit = hitInfo;
                            closestHit.material = meshInfo.material;
                        }
                    }
                    addNum += meshInfo.numTriangles;
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

            // 余弦加权的半球采样
            float3 RandomCosineHemisphereDirection(float3 normal, inout uint rng) {
                float u1 = RandomValue(rng);
                float u2 = RandomValue(rng);
                
                // 在单位圆盘上均匀采样
                float r = sqrt(u1);
                float phi = 2.0 * 3.1415926 * u2;
                
                // 转换为笛卡尔坐标（z轴对齐法线）
                float x = r * cos(phi);
                float y = r * sin(phi);
                float z = sqrt(max(0.0, 1.0 - u1)); // 确保在半球内
                
                // 创建正交基
                float3 tangent = normalize(cross(normal, abs(normal.y) > 0.9 ? 
                                           float3(0, 0, 1) : float3(0, 1, 0)));
                float3 bitangent = cross(normal, tangent);
                
                // 变换到世界空间
                return normalize(x * tangent + y * bitangent + z * normal);
            }

            int MaxBounceCount;
            //追踪函数
            /*
            float3 Trace(Ray ray, inout uint rng){

                float3 incomingLight = 0;
                float3 rayColor = 1;

                for (int i = 0; i <= MaxBounceCount; i++){
                    //HitInfo hitInfo = CalculateRayColl(ray);//球体模型渲染
                    HitInfo hitInfo = MeshRayCast(ray);//网格模型渲染
                    ObjectMaterial material = hitInfo.material;

                    if(hitInfo.didHit){
                        ray.origin = hitInfo.hitPoint;
                        // ray.dir = RandomHemisphereDirection(hitInfo.normal, rng); 光线将均匀的分布，不受夹角影响
                        float3 diffuseDir = normalize(hitInfo.normal + RandomDirection(rng));  //漫反射，光线受到入射角度影响产生的强度衰减(入射角越大,强度越弱)
                        float3 specularDir = reflect(ray.dir, hitInfo.normal);  //全反射光线
                        ray.dir = lerp(diffuseDir, specularDir, material.smooth);   //根据光滑度插值全反射计算光线

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
            */
            /*
            float3 Trace(Ray ray, inout uint rng) {
                float3 incomingLight = 0;
                float3 rayColor = 1;
                
                // 用于追踪当前是否在透明物体内部
                bool insideTransparentObject = false;
                float currentIOR = 1.0;  // 当前介质折射率（空气）

                for (int bounce = 0; bounce <= MaxBounceCount; bounce++) {
                    HitInfo hitInfo = MeshRayCast(ray);
                    ObjectMaterial material = hitInfo.material;

                    if (hitInfo.didHit) {
                        // 1. 计算进入/离开状态
                        bool isEntering = dot(ray.dir, hitInfo.normal) < 0;
                        float3 normal = isEntering ? hitInfo.normal : -hitInfo.normal;
                        
                        // 2. 处理发射光（自发光）
                        float3 emittedLight = material.emissionColor * material.emissionStrength;
                        incomingLight += emittedLight * rayColor;
                        
                        // 3. 处理透明材质
                        if (material.transparency > 0) {
                            // 3.1 设置折射率
                            float materialIOR = 1.5;  // 默认玻璃折射率
                            float iorRatio = isEntering ? (currentIOR / materialIOR) : (materialIOR / currentIOR);
                            
                            // 3.2 计算折射方向
                            float cosi = -dot(ray.dir, normal);
                            float sint2 = iorRatio * iorRatio * (1.0 - cosi * cosi);
                            
                            // 3.3 检查全内反射
                            if (sint2 > 1.0) {
                                // 全内反射
                                ray.dir = reflect(ray.dir, normal);
                                ray.origin = hitInfo.hitPoint + normal * 0.001;
                            } else {
                                // 3.4 计算菲涅尔反射率
                                float cost = sqrt(1.0 - sint2);
                                float Rparl = (iorRatio * cosi - cost) / (iorRatio * cosi + cost);
                                float Rperp = (cosi - iorRatio * cost) / (cosi + iorRatio * cost);
                                float reflectance = 0.5 * (Rparl * Rparl + Rperp * Rperp);
                                
                                // 3.5 随机选择反射或折射路径
                                if (RandomValue(rng) < reflectance) {
                                    // 反射
                                    ray.dir = reflect(ray.dir, normal);
                                    ray.origin = hitInfo.hitPoint + normal * 0.001;
                                } else {
                                    // 折射
                                    ray.dir = refract(ray.dir, normal, iorRatio);
                                    ray.origin = hitInfo.hitPoint - normal * 0.001;
                                    
                                    // 更新介质状态
                                    currentIOR = isEntering ? materialIOR : 1.0;
                                    insideTransparentObject = isEntering;
                                }
                            }
                            
                            // 3.6 光线衰减（考虑吸收和散射）
                            float3 attenuation = material.color.rgb * material.transparency;
                            
                            // 根据物体厚度计算吸收 (简化模型)
                            float thickness = length(hitInfo.hitPoint - ray.origin);
                            attenuation = exp(-(1.0 - attenuation) * thickness * 0.5);
                            
                            rayColor *= attenuation;
                        } 
                        // 4. 处理不透明材质
                        else {
                            // 4.1 更新光线起点（防止自相交）
                            ray.origin = hitInfo.hitPoint + hitInfo.normal * 0.001;
                            
                            // 4.2 计算散射方向
                            float3 diffuseDir = normalize(hitInfo.normal + RandomDirection(rng));
                            float3 specularDir = reflect(ray.dir, hitInfo.normal);
                            
                            // 4.3 混合漫反射和镜面反射
                            ray.dir = lerp(diffuseDir, specularDir, material.smooth);
                            
                            // 4.4 材质颜色衰减
                            rayColor *= material.color.rgb;
                            
                            // 离开透明物体后重置状态
                            insideTransparentObject = false;
                            currentIOR = 1.0;
                        }
                        
                        // 5. 俄罗斯轮盘终止（减少不必要的反弹）
                        if (bounce > 3) {
                            float survivalProbability = max(0.05, 1 - (0.2 * bounce));
                            if (RandomValue(rng) > survivalProbability) {
                                break;
                            }
                            rayColor /= survivalProbability;
                        }
                    } 
                    else {
                        // 6. 未击中任何物体 - 添加天空盒或环境光
                        float3 skyColor = float3(0.5, 0.7, 1.0) * (0.5 + 0.5 * ray.dir.y);
                        incomingLight += skyColor * rayColor;
                        break;
                    }
                }

                return incomingLight;
            }
            */
            float3 Trace(Ray ray, inout uint rng) {
                float3 incomingLight = 0;
                float3 rayColor = 1;
                
                // 用于追踪当前是否在透明物体内部
                bool insideTransparentObject = false;
                float currentIOR = 1.0;  // 当前介质折射率（空气）
                int transparencyDepth = 0; // 追踪透明物体的嵌套深度

                for (int bounce = 0; bounce <= MaxBounceCount; bounce++) {
                    HitInfo hitInfo = MeshRayCast(ray);
                    ObjectMaterial material = hitInfo.material;

                    if (hitInfo.didHit) {
                        // 1. 计算进入/离开状态
                        bool isEntering = dot(ray.dir, hitInfo.normal) < 0;
                        float3 normal = isEntering ? hitInfo.normal : -hitInfo.normal;
                        
                        // 2. 处理发射光（自发光）
                        float3 emittedLight = material.emissionColor * material.emissionStrength;
                        incomingLight += emittedLight * rayColor;
                        
                        // 3. 处理透明材质
                        if (material.transparency > 0) {
                            transparencyDepth++;
                            
                            // 3.1 设置折射率
                            float materialIOR = 1.5;  // 默认玻璃折射率
                            float iorRatio = isEntering ? (currentIOR / materialIOR) : (materialIOR / currentIOR);
                            
                            // 3.2 计算折射方向
                            float cosi = -dot(ray.dir, normal);
                            float sint2 = iorRatio * iorRatio * (1.0 - cosi * cosi);
                            
                            // 3.3 计算菲涅尔反射率
                            float reflectance;
                            if (sint2 <= 1.0) {
                                float cost = sqrt(1.0 - sint2);
                                float Rparl = (iorRatio * cosi - cost) / (iorRatio * cosi + cost);
                                float Rperp = (cosi - iorRatio * cost) / (cosi + iorRatio * cost);
                                reflectance = 0.5 * (Rparl * Rparl + Rperp * Rperp);
                            } else {
                                // 全内反射
                                reflectance = 1.0;
                            }
                            
                            // 3.4 随机选择反射或折射路径
                            if (RandomValue(rng) < reflectance) {
                                // 反射
                                ray.dir = reflect(ray.dir, normal);
                                ray.origin = hitInfo.hitPoint + normal * 0.001;
                            } else {
                                // 折射
                                ray.dir = refract(ray.dir, normal, iorRatio);
                                
                                // 更新介质状态
                                currentIOR = isEntering ? materialIOR : 1.0;
                                insideTransparentObject = isEntering;
                                
                                // 设置起点偏移（关键修复：确保光线能穿过物体）
                                if (isEntering) {
                                    ray.origin = hitInfo.hitPoint - normal * 0.001;
                                } else {
                                    ray.origin = hitInfo.hitPoint + normal * 0.001;
                                }
                            }
                            
                            // 3.5 光线衰减（关键修复：降低衰减强度以显示后方物体）
                            float3 attenuation = lerp(float3(1,1,1), material.color.rgb, 0.1);
                            rayColor *= attenuation * material.transparency;
                            
                            // 3.6 特别处理：当穿过玻璃时，增加一次反弹机会
                            if (bounce == MaxBounceCount && !isEntering) {
                                MaxBounceCount++;
                            }
                        } 
                        // 4. 处理不透明材质
                        else {
                            // 4.1 更新光线起点（防止自相交）
                            ray.origin = hitInfo.hitPoint + hitInfo.normal * 0.001;
                            
                            // 4.2 计算散射方向
                            //float3 diffuseDir = normalize(hitInfo.normal + RandomHemisphereDirection(hitInfo.normal, rng));
                            float3 diffuseDir = RandomCosineHemisphereDirection(hitInfo.normal, rng);
                            float3 specularDir = reflect(ray.dir, hitInfo.normal);
                            
                            // 4.3 混合漫反射和镜面反射
                            ray.dir = lerp(diffuseDir, specularDir, material.smooth);
                            
                            // 4.4 材质颜色衰减
                            rayColor *= material.color.rgb;
                            
                            // 离开透明物体后重置状态
                            insideTransparentObject = false;
                            currentIOR = 1.0;
                            transparencyDepth = 0;
                        }
                        
                        // 5. 俄罗斯轮盘终止（减少不必要的反弹）
                        if (bounce > 3) {
                            float survivalProbability = max(0.05, 1 - (0.1 * bounce));
                            if (RandomValue(rng) > survivalProbability) {
                                break;
                            }
                            rayColor /= survivalProbability;
                        }
                    } 
                    else {
                        // 6. 未击中任何物体 - 添加天空盒或环境光
                        float3 skyColor = float3(0.5, 0.7, 1.0) * (0.3 + 0.7 * ray.dir.y);
                        
                        // 特殊处理：在透明物体内部时使用不同的天空色
                        if (insideTransparentObject) {
                            skyColor = float3(0.8, 0.9, 1.0) * (0.5 + 0.5 * ray.dir.y);
                        }
                        
                        incomingLight += skyColor * rayColor;
                        break;
                    }
                }

                return incomingLight;
            }
            

            sampler2D _MainTex;
            sampler2D _OldMainTex;
            float4 _MainTex_ST;
            float3 ViewParam;
            float4x4 CamLocalToWorldMatrix; 
            int numRaysPerPixel;    //每个像素接受多少根光线
            int NumRenderFrames;    //渲染帧数量

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
                uint rng = pixelIndex + NumRenderFrames * 10086;

                //创建射线
                float3 viewPointLocal = float3(i.uv - 0.5, 1) * ViewParam;
                float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));
                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(viewPoint - ray.origin);

                //计算每个像素接受光的平均值(减少噪声)
                float3 totalIncomeLight = 0;
                for(int rayIndex = 0; rayIndex < numRaysPerPixel; rayIndex++){
                    totalIncomeLight += Trace(ray, rng);
                }
                float3 pixelCol = totalIncomeLight / numRaysPerPixel;
                // return float4(pixelCol, 1);

                float2 flippedUV = i.uv;
                flippedUV.y = 1.0 - i.uv.y;
                float4 oldRenderTex = tex2D(_OldMainTex, flippedUV.xy);
                float4 newRenderTex = float4(pixelCol, 1);

                float weight = 1.0 / (NumRenderFrames + 1);
                float4 accumulateAverage = oldRenderTex * (1 - weight) + newRenderTex * weight;

                return accumulateAverage;
            }
            ENDCG
        }
    }
}
