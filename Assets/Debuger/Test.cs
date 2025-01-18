//using System.Collections;
//using System.Collections.Generic;
//using UnityEngine;

//public class Test : MonoBehaviour
//{
//    [SerializeField] Mesh mesh;
//    [SerializeField] MeshFilter meshFilter;
//    [SerializeField] int triangleNums;
//    [SerializeField] int[] Check;
//    [SerializeField] Vector3 vertexCheck;

//    void Start()
//    {
//        meshFilter = GetComponent<MeshFilter>();
//        mesh = meshFilter.mesh;
//        triangleNums = mesh.triangles.Length / 3;
//        Check = mesh.triangles;
//        vertexCheck = transform.TransformPoint(mesh.vertices[Check[0]]);
//        //Debug.Log(mesh.bounds.max);
//        //Debug.Log(mesh.bounds.min);

//        for (int i = 0; i < triangleNums; i += 3)
//        {
//            int idx0 = mesh.triangles[i];
//            int idx1 = mesh.triangles[i + 1];
//            int idx2 = mesh.triangles[i + 2];

//            Vector3 vertex0 = transform.TransformPoint(mesh.vertices[idx0]);
//            Debug.Log(vertex0);
//            return;
//            Vector3 vertex1 = mesh.vertices[idx1];
//            Vector3 vertex2 = mesh.vertices[idx2];

//            Vector3 normal0 = mesh.normals[idx0];
//            Vector3 normal1 = mesh.normals[idx1];
//            Vector3 normal2 = mesh.normals[idx2];
//        }
//    }

//    void Update()
//    {
//        vertexCheck = transform.TransformPoint(mesh.vertices[Check[0]]);

//        //Debug.Log(transform.TransformPoint(mesh.bounds.max));
//        //Debug.Log(transform.TransformPoint(mesh.bounds.min));
//    }
//}
