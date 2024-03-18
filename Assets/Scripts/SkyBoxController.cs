using UnityEngine;

[ExecuteAlways]
public class SkyboxController : MonoBehaviour
{
    [SerializeField] private Transform _Sun = default;
    [SerializeField] private Transform _Moon = default;

    [SerializeField] private DayNightController dayNightController;
    [SerializeField] private Gradient sunViewGradient;
    [SerializeField] private Gradient sunZenithGradient;
    [SerializeField] private Gradient viewZenithGradient;

    private readonly int resolution = 128;

    public bool autoUpdate = false;

    void LateUpdate()
    {  
        Shader.SetGlobalVector("_SunDir", -_Sun.transform.forward);

        Shader.SetGlobalVector("_MoonDir", -_Moon.transform.forward);

        Shader.SetGlobalMatrix("_MoonSpaceMatrix", new Matrix4x4(-_Moon.transform.forward, -_Moon.transform.up, -_Moon.transform.right, Vector4.zero).transpose);
    }

    void OnValidate(){
        if(autoUpdate){
            UpdateTextures();
        }
        if(!dayNightController){
            Shader.SetGlobalFloat("_StarSpeed",0.0001f);
        }else{
            Shader.SetGlobalFloat("_StarSpeed",(1 - dayNightController.dayLenght / dayNightController.realDayLenght) * 0.001f);
        }
    }

    public void UpdateTextures(){
        Texture2D sunViewGradientTexture = new Texture2D(resolution,1);
        sunViewGradientTexture.SetPixels(GenerateColorsArray(sunViewGradient));
        sunViewGradientTexture.Apply();
        Shader.SetGlobalTexture("_SunViewGrad",sunViewGradientTexture);

        Texture2D sunZenithGradientTexture = new Texture2D(resolution,1);
        Shader.SetGlobalTexture("_SunZenithGrad",sunZenithGradientTexture);
        sunZenithGradientTexture.SetPixels(GenerateColorsArray(sunZenithGradient));
        sunZenithGradientTexture.Apply();

        Texture2D viewZenithGradientTexture = new Texture2D(resolution,1);
        viewZenithGradientTexture.SetPixels(GenerateColorsArray(viewZenithGradient));
        Shader.SetGlobalTexture("_ViewZenithGrad",viewZenithGradientTexture);
        viewZenithGradientTexture.Apply();
    }

    private Color[] GenerateColorsArray(Gradient gradient){

        Color[] colors = new Color[resolution];

        for (int i = 0; i < resolution; i++)
        {
           float t = (float)i/(float)resolution;
           Color color = gradient.Evaluate(t);
           colors[i] = color;

        }

        return colors;
    }

}
