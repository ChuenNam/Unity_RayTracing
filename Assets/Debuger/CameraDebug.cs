using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class CameraDebug : MonoBehaviour
{
    public Vector2 debugPoint;
    public float pointRadius;
    public Color color = Color.white;

    [SerializeField]GameObject pointPrefab;
    Transform[,] pointList = new Transform[16, 9];


    void OnEnable()
    {
        if (pointList.Length <= 144)
        {
            InitPoint();
            Debug.Log(pointList.Length);
        }
    }
    private void Update()
    {
        DebugCam();
    }


    void DebugCam()
    {
        Camera cam = Camera.main;
        Transform camT = cam.transform;

        //计算投影平面宽高
        float PlaneH = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float PlaneW = PlaneH * cam.aspect;
        //平面左下角的坐标（Cam.Local）
        Vector3 localOrigin = new(-PlaneW / 2, -PlaneH / 2, cam.nearClipPlane);

        //绘制point到近平面
        for (int i = 0; i < debugPoint.x; i++)
        {
            for (int j = 0; j < debugPoint.y; j++)
            {
                float tx = i / (debugPoint.x - 1.0f);
                float ty = j / (debugPoint.y - 1.0f);

                //计算每个点的本地坐标与世界坐标
                Vector3 pointLocal = localOrigin + new Vector3(PlaneW * tx, PlaneH * ty);
                Vector3 point = camT.position + camT.right * pointLocal.x + camT.up * pointLocal.y + camT.forward * pointLocal.z;

                //Draw
                DrawPoint(point, i, j);
            }
        }
    }
    void DrawPoint(Vector3 pos, int x, int y)
    {
        pointList[x, y].position = pos;
    }
    void InitPoint()
    {
        Camera cam = Camera.main;
        Transform camT = cam.transform;

        //计算投影平面宽高
        float PlaneH = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float PlaneW = PlaneH * cam.aspect;
        //平面左下角的坐标（Cam.Local）
        Vector3 localOrigin = new(-PlaneW / 2, -PlaneH / 2, cam.nearClipPlane);

        //绘制point到近平面
        for (int i = 0; i < debugPoint.x; i++)
        {
            for (int j = 0; j < debugPoint.y; j++)
            {
                float tx = i / (debugPoint.x - 1.0f);
                float ty = j / (debugPoint.y - 1.0f);
                //计算每个点的本地坐标与世界坐标
                Vector3 pointLocal = localOrigin + new Vector3(PlaneW * tx, PlaneH * ty);
                Vector3 point = camT.position + camT.right * pointLocal.x + camT.up * pointLocal.y + camT.forward * pointLocal.z;
                //Draw
                var p = Instantiate(pointPrefab, point, Quaternion.identity, transform);
                pointList[i, j] = p.transform;
            }
        }
    }
}
