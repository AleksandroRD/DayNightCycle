using UnityEngine;

[ExecuteAlways]
public class SkyboxController : MonoBehaviour
{
    [SerializeField] private Transform _Sun = default;
    [SerializeField] private Transform _Moon = default;

    [SerializeField] private DayNightController dayNightController;

    void LateUpdate()
    {
        Shader.SetGlobalVector("_SunDir", -_Sun.transform.forward);

        Shader.SetGlobalVector("_MoonDir", -_Moon.transform.forward);
    }

}
