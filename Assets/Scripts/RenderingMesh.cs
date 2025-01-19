using UnityEngine;

[ExecuteAlways]
public class RenderingMesh : MonoBehaviour
{
    [SerializeField] Mesh mesh;
    [SerializeField] MeshFilter meshFilter;
    public int triangleNums;

    [SerializeField] Color color;
    [SerializeField] Color emissionColor;
    [SerializeField] float emissionStrength;
    public MeshInfo meshInfo;
    public Triangle[] allTriangles;

    [Header("Debug")]
    public Vector3 boundingMax;
    public Vector3 boundingMin;


    void Update()
    {
        meshFilter = GetComponent<MeshFilter>();
        mesh = meshFilter.sharedMesh;
        triangleNums = mesh.triangles.Length / 3;
        meshInfo.numTriangles = triangleNums;
        allTriangles = new Triangle[triangleNums];

        meshInfo.boundsMin = transform.TransformPoint(mesh.bounds.min);
        meshInfo.boundsMax = transform.TransformPoint(mesh.bounds.max);

        for (int i = 0; i < mesh.triangles.Length; i+=3)
        {
            int idx0 = mesh.triangles[i];
            int idx1 = mesh.triangles[i + 1];
            int idx2 = mesh.triangles[i + 2];

            int id = i / 3;

            allTriangles[id].posA = transform.TransformPoint(mesh.vertices[idx0]);
            allTriangles[id].posB = transform.TransformPoint(mesh.vertices[idx1]);
            allTriangles[id].posC = transform.TransformPoint(mesh.vertices[idx2]);

            allTriangles[id].normalA = transform.TransformDirection(mesh.normals[idx0]).normalized;
            allTriangles[id].normalB = transform.TransformDirection(mesh.normals[idx1]).normalized;
            allTriangles[id].normalC = transform.TransformDirection(mesh.normals[idx2]).normalized;
        }

        meshInfo.material.color = color;
        meshInfo.material.emissionColor = emissionColor;
        meshInfo.material.emissionStrength = emissionStrength;

        //Debug
        boundingMin = meshInfo.boundsMin;
        boundingMax = meshInfo.boundsMax;
    }
}

//三角形信息
public struct Triangle
{
    public Vector3 posA, posB, posC;
    public Vector3 normalA, normalB, normalC;
}
///网格信息
public struct MeshInfo
{
    public int numTriangles;
    public Vector3 boundsMax;
    public Vector3 boundsMin;
    public ObjMaterial material;
}
public struct ObjMaterial
{
    public Color color;
    public Color emissionColor;
    public float emissionStrength;
}