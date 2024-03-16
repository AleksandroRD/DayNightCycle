//using static UnityEngine.Mathf;
using System;
using UnityEngine;
using static System.Math;

public static class AstroCalsulator
{   
    //helper functions
    static double degToRad = PI/180.0f;
    static double radToDeg = 180.0f/PI;
    //Local Standard Time Meridian
    static double CalculateLSTM(double GMT){return GMT*15;}

    static int GetDaysPassedSinceStartOfYear(int day,int month,int year)
    {
        DateTime currentDate = new(year, month, day);
     
        // Get the first day of the current year
        DateTime startOfYear = new(currentDate.Year, 1, 1);

        // Calculate the difference in days
        int daysPassed = (int)(currentDate - startOfYear).TotalDays;
        return daysPassed + 1;
    }


    static double CalculateEoT(int day,int month,int year){
        double b = 0.9863013698630137f * (GetDaysPassedSinceStartOfYear(day,month,year) - 81);
        b *= degToRad;
        
        return 9.87f*Sin(2*b) - 7.53f*Cos(b) - 1.5f*Sin(b);
    }


    static double CaclulateTC(double longitude, int GMT,int day,int month,int year){
        return 4.0f*(longitude - CalculateLSTM(GMT)) + CalculateEoT(day,month,year);
    }


    static double CalculateLST(double longitude, int GMT,int day,int month,int year,int seconds, int minutes,int hours){
        return (seconds + minutes * 60.0f + hours * 3600.0f) / 3600.0f + CaclulateTC(longitude,GMT,day,month,year) / 60.0f;
    }


    static double CalculateHRA(double longitude, int GMT,int day,int month,int year,int seconds, int minutes,int hours){
        return 15.0f * (CalculateLST(longitude, GMT,day,month,year,seconds, minutes,hours)-12.0f);
    }


    static double CalculateDeclination(int day,int month,int year){
        return 23.45f * Sin(0.9863013698630137f * (GetDaysPassedSinceStartOfYear(day,month,year) - 81.0f) * degToRad);
    }


    public static double CalculateSunElevation(double longitude,double latitude, int GMT,int day,int month,int year,int seconds, int minutes,int hours){
        double declination = CalculateDeclination(day,month,year) * degToRad;

        double HRA = CalculateHRA(longitude,GMT,day,month,year,seconds,minutes,hours) * degToRad;

        return Asin(Sin(declination) * Sin(latitude * degToRad) + Cos(declination) * Cos(latitude * degToRad) * Cos(HRA))*radToDeg;
        
    }

    //Elevation and Azimuth
    public static Vector2 CalculateSunPosition(double longitude,double latitude, int GMT,int day,int month,int year,int seconds, int minutes,int hours){
        double elevation = CalculateSunElevation(longitude ,latitude,GMT,day,month,year,seconds,minutes,hours);

        double declination = CalculateDeclination(day,month,year) * degToRad;

        double HRA = CalculateHRA(longitude,GMT,day,month,year,seconds,minutes,hours) * degToRad;

        if(HRA >= 0){
            return new Vector2((float)elevation,(float)(360 - Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }else{
            return new Vector2((float)elevation,(float)(Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }
        
    }

    public static Vector2 CalculateSunPosition1(double longitude,double latitude, int GMT,int day,int month,int year,int seconds, int minutes,int hours){

        double b = 0.9863013698630137f * (GetDaysPassedSinceStartOfYear(day,month,year) - 81);
        b *= degToRad;
        
        //Equation of Time
        double EOT = 9.87f*Sin(2*b) - 7.53f*Cos(b) - 1.5f*Sin(b);
        
        //Time Correction Factor
        double TC = 4.0f * (longitude - CalculateLSTM(GMT)) + EOT;

        //Local Solar Time
        double LST = (seconds + minutes * 60.0f + hours * 3600.0f) / 3600.0f + TC / 60.0f;

        //Hour Angle
        double HRA = 15.0f * (LST-12.0f) * degToRad;

        //Declination
        double declination = 23.45f * Sin(0.9863013698630137f * (GetDaysPassedSinceStartOfYear(day,month,year) - 81.0f) * degToRad) * degToRad;

        //Elevation
        double elevation = Asin(Sin(declination) * Sin(latitude * degToRad) + Cos(declination) * Cos(latitude * degToRad) * Cos(HRA)) * radToDeg;


        if(HRA >= 0){
            return new Vector2((float)elevation,(float)(360 - Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }else{
            return new Vector2((float)elevation,(float)(Acos((Sin(declination) * Cos(latitude * degToRad) - Cos(declination) * Sin(latitude * degToRad) * Cos(HRA)) / Cos(elevation*degToRad))*radToDeg));
        }
        
    }

}
