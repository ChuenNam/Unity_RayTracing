using UnityEngine;

[ExecuteAlways]
public class RenderingMesh : MonoBehaviour
{
    private Mesh mesh;
    private MeshFilter meshFilter;
    private Renderer Renderer;
    public int triangleNums;

    [Header("Material")]
    [SerializeField] Color color;
    [SerializeField] Color emissionColor;
    [SerializeField][Range(0, 10)] float emissionStrength;
    [SerializeField][Range(0, 1)] float smooth;
    [SerializeField][Range(0, 1)] float transparency;  // 添加透明度属性 (0=完全透明, 1=完全不透明)

    public MeshInfo meshInfo;
    public Triangle[] allTriangles;

    void Update()
    {
        meshFilter = GetComponent<MeshFilter>();
        Renderer = GetComponent<MeshRenderer>();
        mesh = meshFilter.sharedMesh;
        triangleNums = mesh.triangles.Length / 3;
        meshInfo.numTriangles = triangleNums;
        allTriangles = new Triangle[triangleNums];

        meshInfo.boundsMax = Renderer.bounds.max;
        meshInfo.boundsMin = Renderer.bounds.min;

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
        meshInfo.material.smooth = smooth;
        meshInfo.material.transparency = transparency;  // 添加透明度属性 (0=完全透明, 1=完全不透明)
    }
}

//三角形信息
public struct Triangle
{
    public Vector3 posA, posB, posC;
    public Vector3 normalA, normalB, normalC;
}
//网格信息
public struct MeshInfo
{
    public int numTriangles;
    public Vector3 boundsMax;
    public Vector3 boundsMin;
    public ObjMaterial material;
}
//材质信息
public struct ObjMaterial
{
    public Color color;
    public Color emissionColor;
    public float emissionStrength;
    public float smooth;
    public float transparency;  // 添加透明度属性 (0=完全透明, 1=完全不透明)
}