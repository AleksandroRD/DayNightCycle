using System;
using UnityEngine;
using static System.Math;

public static class AstroCalsulator
{   
    static double degToRad = PI/180.0f;
    static double radToDeg = 180.0f/PI;
    static double CalculateLSTM(double GMT){return GMT*15;}

    static int GetDaysPassedSinceStartOfYear(int day,int month,int year)
    {
        DateTime currentDate = new(year, month, day);
     
        DateTime startOfYear = new(currentDate.Year, 1, 1);

        int daysPassed = (int)(currentDate - startOfYear).TotalDays;
        return daysPassed + 1;
    }

    public static Vector2 CalculateSunPosition(double longitude,double latitude, int GMT,DateTime dateTime){

        double daysPassed = GetDaysPassedSinceStartOfYear( dateTime.Day,dateTime.Month,dateTime.Year);
        double b = 0.9863013698630137f * (daysPassed - 81);
        b *= degToRad;
        
        //Equation of Time
        double EOT = 9.87f*Sin(2*b) - 7.53f*Cos(b) - 1.5f*Sin(b);
        
        //Time Correction Factor
        double TC = 4.0f * (longitude - CalculateLSTM(GMT)) + EOT;

        //Local Solar Time
        double LST = (dateTime.Second + dateTime.Minute * 60.0f + dateTime.Hour * 3600.0f) / 3600.0f + TC / 60.0f;

        //Hour Angle
        double HRA = 15.0f * (LST-12.0f) * degToRad;

        //Declination
        double declination = 23.45f * Sin(0.9863013698630137f * (daysPassed - 81.0f) * degToRad) * degToRad;

        //Elevation
        double elevation = Asin(Sin(declination) * Sin(latitude * degToRad) + Cos(declination) * Cos(latitude * degToRad) * Cos(HRA)) * radToDeg;


        if(HRA >= 0){
            return new Vector2((float)elevation,(float)(360 - Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }else{
            return new Vector2((float)elevation,(float)(Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }
        
    }

}
