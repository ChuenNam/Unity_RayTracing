using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class Obj : MonoBehaviour
{
    public Color color;
    public Sphere sphere;

    private void Update()
    {
        sphere.position = transform.position;
        sphere.radius = transform.localScale.x;
        sphere.color = color;

    }
}
public struct Sphere
{
    public Vector3 position;
    public float radius;
    public Color color;
}
