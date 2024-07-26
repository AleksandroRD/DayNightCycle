using System;
using UnityEngine;
using static System.Math;

public static class AstroCalsulator
{
    private const double DEG_TO_RAD = PI / 180.0f;
    private const double RAD_TO_DEG = 180.0f / PI;
    private const double HOUR = 24.0 / 360.0;
    private static double CalculateLSTM(double GMT) { return GMT * 15; }

    private static int GetDaysPassedSinceStartOfYear(int day, int month, int year)
    {
        DateTime currentDate = new(year, month, day);

        DateTime startOfYear = new(currentDate.Year, 1, 1);

        int daysPassed = (int)(currentDate - startOfYear).TotalDays;
        return daysPassed + 1;
    }

    public static (double Azimuth, double Elevation) CalculateSunPosition(double longitude, double latitude, int GMT, DateTime dateTime)
    {
        double daysPassed = GetDaysPassedSinceStartOfYear(dateTime.Day, dateTime.Month, dateTime.Year);
        double b = 0.9863013698630137f * (daysPassed - 81);
        b *= DEG_TO_RAD;

        //Equation of Time
        double EOT = 9.87f * Sin(2 * b) - 7.53f * Cos(b) - 1.5f * Sin(b);

        //Time Correction Factor
        double TC = 4.0f * (longitude - CalculateLSTM(GMT)) + EOT;

        //Local Solar Time
        double LST = (dateTime.Second + dateTime.Minute * 60.0f + dateTime.Hour * 3600.0f) / 3600.0f + TC / 60.0f;

        //Hour Angle
        double HRA = 15.0f * (LST - 12.0f) * DEG_TO_RAD;

        //Declination
        double declination = 23.45f * Sin(0.9863013698630137f * (daysPassed - 81.0f) * DEG_TO_RAD) * DEG_TO_RAD;

        //Elevation
        double elevation = Asin(Sin(declination) * Sin(latitude * DEG_TO_RAD) + Cos(declination) * Cos(latitude * DEG_TO_RAD) * Cos(HRA)) * RAD_TO_DEG;


        if (HRA >= 0)
        {
            return (elevation, 360 - Acos((Sin(declination) * Cos(latitude * DEG_TO_RAD) - Cos(declination) * Sin(latitude * DEG_TO_RAD) * Cos(HRA)) / Cos(elevation * DEG_TO_RAD)) * RAD_TO_DEG);
        }
        else
        {
            return (elevation, Acos((Sin(declination) * Cos(latitude * DEG_TO_RAD) - Cos(declination) * Sin(latitude * DEG_TO_RAD) * Cos(HRA)) / Cos(elevation * DEG_TO_RAD)) * RAD_TO_DEG);
        }
    }
}