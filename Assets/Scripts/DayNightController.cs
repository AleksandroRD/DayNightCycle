using System;
using System.Collections;
using UnityEngine;

public class DayNightController : MonoBehaviour
{
    [SerializeField] public Light sun;
    [SerializeField] public Light moon;

    [Header("Time")]
    [SerializeField][Range(0, 59)] private int second = 0;
    [SerializeField][Range(0, 59)] private int minute = 0;

    [SerializeField][Range(0, 23)] private int hour = 0;

    [Header("Date")]
    [SerializeField][Range(1, 30)] private int day = 1;
    [SerializeField][Range(1, 12)] private int month = 1;
    [SerializeField] private int year = 2000;

    [Header("Position")]
    [SerializeField] private float latitude = 50;
    [SerializeField] private float longitude = 30;
    [SerializeField][Range(-12, 12)] private int UTC = 0;

    [Header("Day Night Cycle")]
    public float dayLenght;
    [SerializeField][Range(0.01f, 5f)] private float updateRate = 0.1f;
    [SerializeField] private bool dayNightCycle = false;
    public float currentTime { get; private set; }
    public const int REAL_DAY_LENGHT = 84600;

    void Start()
    {
        currentTime = second + minute * 60 + hour * 3600;

        if (dayNightCycle) { StartCoroutine(RunTime()); }
    }

    IEnumerator RunTime()
    {
        while (true)
        {
            currentTime += REAL_DAY_LENGHT / dayLenght * updateRate;

            UpdateTime();

            UpdateSunMoonPosition();

            yield return new WaitForSeconds(updateRate);
        }
    }

    private void UpdateTime()
    {
        if (currentTime > 84600.0) { currentTime = 0; }

        hour = (int)(currentTime / 3600);
        minute = (int)(currentTime % 3600 / 60);
        second = (int)(currentTime % 3600 - minute * 60);
    }

    private void UpdateSunMoonPosition()
    {
        var sunPosition = AstroCalsulator.CalculateSunPosition(new DateTime(year, month, day, hour, minute, second), UTC, longitude, latitude);
        sun.transform.eulerAngles = new Vector3((float)sunPosition.Azimuth, (float)sunPosition.Elevation, 0);

        var moonPosition = AstroCalsulator.CalculateMoonPosition(new DateTime(year, month, day, hour - UTC, minute, second), longitude, latitude);
        moon.transform.eulerAngles = new Vector3((float)moonPosition.Azimuth, (float)moonPosition.Elevation, 0);
    }

    public void SetCurrentRealTime()
    {
        DateTime now = DateTime.Now;
        year = now.Year;
        day = now.Day;
        month = now.Month;

        currentTime = now.Second + now.Minute * 60 + now.Hour * 3600;

        UpdateTime();

        UpdateSunMoonPosition();
    }

#if UNITY_EDITOR
    private void OnValidate()
    {
        UpdateSunMoonPosition();
    }
#endif
}

