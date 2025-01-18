using UnityEngine;

[ExecuteAlways]
public class Obj : MonoBehaviour
{
    public Color color;
    public Color emissionColor;
    public float emissionStrength;
    public Sphere sphere;

    private void Update()
    {
        sphere.position = transform.position;
        sphere.radius = transform.localScale.x * 0.5f;
        sphere.material.color = color;
        sphere.material.emissionColor = emissionColor;
        sphere.material.emissionStrength = emissionStrength;
    }
}
public struct Sphere
{
    public Vector3 position;
    public float radius;
    public ObjMaterial material;
}