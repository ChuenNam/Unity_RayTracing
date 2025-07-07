using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways][ImageEffectAllowedInSceneView]
public class RayTracingCtrl : MonoBehaviour
{
    private static readonly int ViewParam = Shader.PropertyToID("ViewParam");
    private static readonly int CamLocalToWorldMatrix = Shader.PropertyToID("CamLocalToWorldMatrix");
    private static readonly int Triangles = Shader.PropertyToID("Triangles");
    private static readonly int AllMeshInfo = Shader.PropertyToID("AllMeshInfo");
    private static readonly int NumMeshes = Shader.PropertyToID("NumMeshes");
    private static readonly int BounceCount = Shader.PropertyToID("MaxBounceCount");
    private static readonly int NumRaysPerPixel = Shader.PropertyToID("numRaysPerPixel");
    private static readonly int RenderFrames = Shader.PropertyToID("NumRenderFrames");
    private static readonly int OldMainTex = Shader.PropertyToID("_OldMainTex");
    
    [SerializeField] bool useShaderInSceneView;
    [SerializeField] Shader RayTracingShader;
    [SerializeField] Material rayTracingMaterial;
    [SerializeField] int MaxBounceCount = 2;
    [SerializeField] int numRaysPerPixel = 1;
    [SerializeField] int NumRenderFrames = -1;

    public Obj[] objs;
    Sphere[] spheres;

    public RenderingMesh[] RenderingMesh;
    MeshInfo[] meshInfo;

    RenderTexture preFrameRenderTex;

    void Start()
    {
        preFrameRenderTex = new RenderTexture(Screen.width, Screen.height, 24);
        preFrameRenderTex.Create();
    }
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (Camera.current.name != "SceneCamera" || useShaderInSceneView)
        {
            //TODO:����ʹ��RayTracing�Ĳ���
            //ShaderHelper.InitMaterial(rayTracingShader, ref rayTracingMaterial);

            //更新信息给shader
            UpdateCam(Camera.current);
            UpdateObj();
            UpdateData();
            //开始ray tracing渲染
            Graphics.Blit(null, destination, rayTracingMaterial);
            Graphics.Blit(destination, preFrameRenderTex);
        }
        else
        {
            //正常渲染
            Graphics.Blit(source, destination);
        }
    }
    private void UpdateCam(Camera cam)
    {
        float PlaneH = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float PlaneW = PlaneH * cam.aspect;
        //Send data to shader
        rayTracingMaterial.SetVector(ViewParam, new Vector3(PlaneW, PlaneH, cam.nearClipPlane));
        rayTracingMaterial.SetMatrix(CamLocalToWorldMatrix, cam.transform.localToWorldMatrix);
    }
    private void UpdateObj()
    {
        #region 球体
        //if (objs.Length != 0)
        //{
        //    spheres = new Sphere[objs.Length];
        //    for (int i = 0; i < objs.Length; i++)
        //    {
        //        spheres[i] = objs[i].sphere;
        //    }
        //    ComputeBuffer buffer = new(spheres.Length, sizeof(float) * 13);
        //    buffer.SetData(spheres);
        //    rayTracingMaterial.SetBuffer("Spheres", buffer);
        //    rayTracingMaterial.SetInteger("NumSpheres", spheres.Length);
        //}
        #endregion

        #region 网格体
        if (RenderingMesh.Length != 0)
        {
            meshInfo = new MeshInfo[RenderingMesh.Length];
            List<Triangle> triangleList = new();
            for (int i = 0; i < RenderingMesh.Length; i++)
            {
                meshInfo[i] = RenderingMesh[i].meshInfo;
                foreach (var triangle in RenderingMesh[i].allTriangles)
                {
                    triangleList.Add(triangle);
                }
            }

            ComputeBuffer triangleBuffer = new(triangleList.Count, sizeof(float) * 18);
            triangleBuffer.SetData(triangleList);
            rayTracingMaterial.SetBuffer(Triangles, triangleBuffer);

            ComputeBuffer meshBuffer = new(meshInfo.Length, sizeof(float) * 17 + sizeof(int) * 1);
            meshBuffer.SetData(meshInfo);
            rayTracingMaterial.SetBuffer(AllMeshInfo, meshBuffer);

            rayTracingMaterial.SetInteger(NumMeshes, RenderingMesh.Length);
        }
        #endregion
    }
    private void UpdateData()
    {
        NumRenderFrames++;
        rayTracingMaterial.SetInteger(BounceCount, MaxBounceCount);
        rayTracingMaterial.SetInteger(NumRaysPerPixel, numRaysPerPixel);
        rayTracingMaterial.SetInteger(RenderFrames, NumRenderFrames);
        rayTracingMaterial.SetTexture(OldMainTex, preFrameRenderTex);
    }
}
