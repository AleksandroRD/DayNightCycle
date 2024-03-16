using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(SkyboxController))]
public class GradientUpdater : Editor 
{
    
    public override void OnInspectorGUI() {
        SkyboxController sk = target as SkyboxController;
        DrawDefaultInspector();
        if(!sk.autoUpdate){
            if (GUILayout.Button("Update Textures")){
                sk.UpdateTextures();
            };
        }

    }
}

