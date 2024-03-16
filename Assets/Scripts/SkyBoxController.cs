using System.IO;
using UnityEngine;

[ExecuteAlways]
public class SkyboxController : MonoBehaviour
{
    [SerializeField] private Transform _Sun = default;
    [SerializeField] private Transform _Moon = default;

    [SerializeField]
    private Gradient sunViewGradient;
    [SerializeField]
    private Gradient sunZenithGradient;
    [SerializeField]
    private Gradient viewZenithGradient;

    [SerializeField]
    private Texture2D sunViewGradientTexture;
    [SerializeField]
    private Texture2D sunZenithGradientTexture;
    [SerializeField]
    private Texture2D viewZenithGradientTexture;

    private readonly int resolution = 128;

    public bool autoUpdate = false;
    void LateUpdate()
    {
        // Directions are defined to point towards the object
        
        // Sun
        Shader.SetGlobalVector("_SunDir", -_Sun.transform.forward);

        // Moon
        Shader.SetGlobalVector("_MoonDir", -_Moon.transform.forward);

        Shader.SetGlobalMatrix("_MoonSpaceMatrix", new Matrix4x4(-_Moon.transform.forward, -_Moon.transform.up, -_Moon.transform.right, Vector4.zero).transpose);
    }
    void OnValidate(){
        if(autoUpdate){
            UpdateTextures();
        }
    }
    public void UpdateTextures(){
        sunViewGradientTexture.SetPixels(GenerateColorsArray(sunViewGradient));
        sunViewGradientTexture.Apply();
        sunZenithGradientTexture.SetPixels(GenerateColorsArray(sunZenithGradient));
        sunZenithGradientTexture.Apply();
        viewZenithGradientTexture.SetPixels(GenerateColorsArray(viewZenithGradient));
        viewZenithGradientTexture.Apply();
    }
    private Color[] GenerateColorsArray(Gradient gradient){

        Color[] colors = new Color[resolution*4];

        for (int i = 0; i < resolution; i++)
        {
           float t = (float)i/(float)resolution;
           Color color = gradient.Evaluate(t);
           colors[i] = color;
           colors[i+resolution] = color ;
           colors[i+resolution*2] = color ;
           colors[i+resolution*3] = color ;
        }

        return colors;
    }

}
