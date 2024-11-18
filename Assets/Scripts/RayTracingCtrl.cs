using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways][ImageEffectAllowedInSceneView]
public class RayTracingCtrl : MonoBehaviour
{
    [SerializeField] bool useShaderInSceneView;
    [SerializeField] Shader RayTracingShader;
    public Material rayTracingMaterial;
    public Obj[] objs;
    Sphere[] spheres;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (Camera.current.name != "SceneCamera" || useShaderInSceneView)
        {
            //TODO:设置使用RayTracing的材质
            //ShaderHelper.InitMaterial(rayTracingShader, ref rayTracingMaterial);
            UpdateCam(Camera.current);
            UpdateObj();
            //使用ray tracing并渲染到屏幕
            Graphics.Blit(null, destination, rayTracingMaterial);
        }
        else
        {
            //渲染默认管线到屏幕
            Graphics.Blit(source, destination);
        }
    }

    private void UpdateCam(Camera cam)
    {
        float PlaneH = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float PlaneW = PlaneH * cam.aspect;
        //Send data to shader
        rayTracingMaterial.SetVector("ViewParam", new Vector3(PlaneW, PlaneH, cam.nearClipPlane));
        rayTracingMaterial.SetMatrix("CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);
    }
    private void UpdateObj()
    {
        spheres = new Sphere[objs.Length];
        for (int i = 0; i < objs.Length; i++)
        {
            spheres[i] = objs[i].sphere;
        }
        ComputeBuffer buffer = new(spheres.Length, sizeof(float) * 8);
        buffer.SetData(spheres);
        rayTracingMaterial.SetBuffer("Spheres", buffer);
        rayTracingMaterial.SetInteger("Num", spheres.Length);
    }
}
