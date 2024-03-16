using System.Collections;
using UnityEngine;

public class DayNightController : MonoBehaviour
{   
    [SerializeField]
    private Light sun;
    [SerializeField]
    private Light moon;
    [Header("Time")]
    [SerializeField]
    [Range(0,59)]
    private int seconds;
    [SerializeField]
    [Range(0,59)]
    private int minutes;
    [Range(0,23)]
    [SerializeField]
    private int hours;
    [Header("Date")]
    [SerializeField]
    [Range(1,31)]
    private int day;
    [SerializeField]
    [Range(1,12)]
    private int month;
    [SerializeField]
    private int year;
    [SerializeField]
    [Header("Position")]
    private float latitude = 50;
    [SerializeField]
    private float longitude = 30;
    [SerializeField]
    [Range(-12,12)]
    private int GMT = 0;
    [SerializeField]
    [Range(1f,1410f)]
    [Header("Day Night Cycle")]
    private float timeScale;
    [SerializeField]
    [Range(0.01f,5f)]
    private float updateRate = 0.1f;
    [SerializeField]
    private bool dayNightCycle = false;
    public float currentTime{get; private set;}

    void Start(){
        
        currentTime = seconds + minutes * 60 + hours * 3600;
        if(dayNightCycle){
            StartCoroutine(RunTime());
        }
    }

    IEnumerator RunTime(){
        while(true){
            currentTime += 1.0f*updateRate*timeScale;
            UpdateTime();
            Vector2 sunPosition = AstroCalsulator.CalculateSunPosition(longitude,latitude,GMT,new System.DateTime(year, month, day, hours, minutes, seconds));
            sun.transform.eulerAngles = new Vector3(sunPosition.x,sunPosition.y,0);
            moon.transform.eulerAngles = new Vector3(-sunPosition.x, -(180.0f-sunPosition.y), 0);
            yield return new WaitForSeconds(updateRate);
        }
    }

    private void UpdateTime(){
        hours = (int)(currentTime / 3600);
        minutes = (int)(currentTime % 3600);
        seconds = (int)currentTime % 3600 - minutes * 60;
        if(currentTime > 84600.0){
            currentTime = 0;
        }
    }

    private void OnValidate(){
        Vector2 sunPosition = AstroCalsulator.CalculateSunPosition(longitude,latitude,GMT,new System.DateTime(year, month, day, hours, minutes, seconds));
        sun.transform.eulerAngles = new Vector3(sunPosition.x,sunPosition.y,0);
        moon.transform.eulerAngles = new Vector3(-sunPosition.x, -(180.0f-sunPosition.y), 0);
    }
    
}

