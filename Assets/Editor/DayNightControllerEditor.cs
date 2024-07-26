using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(DayNightController))]
public class DayNightControllerEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DayNightController sk = target as DayNightController;
        DrawDefaultInspector();

        if (GUILayout.Button("Set Current Real Time"))
        {
            sk.SetCurrentRealTime();
        };

    }
}
