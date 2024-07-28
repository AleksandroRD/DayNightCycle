using System;
using System.Runtime.InteropServices;
using UnityEngine;
using static System.Math;

public static class AstroCalsulator
{
    private const double DEG_TO_RAD = PI / 180.0f;
    private const double RAD_TO_DEG = 180.0f / PI;

    private const double JULIAN_CENTURY = 36525;
    private const double JULIAN_EPOCH = 2451545.0;

    private static double CalculateLSTM(double UTC) { return UTC * 15; }

    private static int GetDaysPassedSinceStartOfYear(int day, int month, int year)
    {
        DateTime currentDate = new(year, month, day);

        DateTime startOfYear = new(currentDate.Year, 1, 1);

        int daysPassed = (int)(currentDate - startOfYear).TotalDays;
        return daysPassed + 1;
    }

    public static (double Azimuth, double Elevation) CalculateSunPosition(double longitude, double latitude, int UTC, DateTime dateTime)
    {
        double daysPassed = GetDaysPassedSinceStartOfYear(dateTime.Day, dateTime.Month, dateTime.Year);
        double b = 0.9863013698630137f * (daysPassed - 81);
        b *= DEG_TO_RAD;

        //Equation of Time
        double EOT = 9.87f * Sin(2 * b) - 7.53f * Cos(b) - 1.5f * Sin(b);

        //Time Correction Factor
        double TC = 4.0f * (longitude - CalculateLSTM(UTC)) + EOT;

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

    public static (double Azimuth, double Elevation) CalculateMoonPosition(DateTime date, double longitude, double latitude)
    {
        double JD = JulianDay(date);
        //double JD = JulianDay(new DateTime(1991, 5, 19, 13, 0, 0));
        //longitude = 10;
        //latitude = 50; 
        double T = (JD - JULIAN_EPOCH) / JULIAN_CENTURY;

        //MOON MEAN LONGITUDE
        double L = Clamp360(218.3164477 + (481267.88123421 * T) - (0.0015786 * Pow(T, 2)) + (Pow(T, 3) / 538841) - (Pow(T, 4) / 65194000));

        //MOON MEAN ELONGATION
        double D = Clamp360(297.8501921 + (445267.1114034 * T) - (0.0018819 * Pow(T, 2)) + (Pow(T, 3) / 545868) - (Pow(T, 4) / 113065000));

        //SUN MEAN ANOMALY
        double M = Clamp360(357.5291092 + (35999.0502909 * T) - (0.0001536 * Pow(T, 2)) + (Pow(T, 3) / 24490000));

        //MOON MEAN ANOMALY
        double MA = Clamp360(134.9633964 + (477198.8675055 * T) + (0.0087414 * Pow(T, 2)) + (Pow(T, 3) / 69699) - (Pow(T, 4) / 14712000));

        //MOON ARGUMENT OF LATITUDE
        double F = Clamp360(93.2720950 + (483202.0175233 * T) - (0.0036539 * Pow(T, 2)) - (Pow(T, 3) / 3526000) + (Pow(T, 4) / 863310000));

        //Earth's eccentricity of its orbit around the Sun
        double E = Clamp360(1 - (0.002516 * T) - (0.0000074 * Pow(T, 2)));

        //Calculate "A1" (due to the action of Venus)
        double A1 = Clamp360(119.75 + (131.849 * T));

        //Calculate "A2" (due to the action of Jupiter)
        double A2 = Clamp360(53.09 + (479264.290 * T));

        //Calculate "A3"
        double A3 = Clamp360(313.45 + (481266.484 * T));

        double sumL = 0;

        for (int i = 0; i < 60; i++)
        {
            int[] terms = sumLArray.GetRow(i);

            double termD = terms[0] * D;
            double termMSun = terms[1] * M;
            double termMMoon = terms[2] * MA;
            double termF = terms[3] * F;

            double term = termD + termMSun + termMMoon + termF; //Add up the four fundamental arguments D, M, M' and F.

            term = Sin(DEG_TO_RAD * term);

            if (terms[1] != 0)
            { //Term M depends on eccentricity of the Earth's orbit around the Sun
                if (terms[4] != 0)
                { //In case of last term, the coefficient does not exist, so exclude it
                    term = terms[4] * E * term; //Multiply sum of fundamental arguments by coefficient (include "E")
                }
                else
                {
                    term = E * term; //Multiply sum of fundamental arguments by coefficient (include "E")
                }
            }
            else
            {
                if (terms[4] != 0)
                {
                    term = terms[4] * term; //Multiply sum of fundamental arguments by coefficient (exclude "E")
                }
            }

            sumL += term;
        }

        sumL += 3958 * Sin(DEG_TO_RAD * A1);
        sumL += 1962 * Sin(DEG_TO_RAD * (L - F));
        sumL += 318 * Sin(DEG_TO_RAD * A2);

        double sumB = 0;
        //Loop through the linear combination array
        for (int i = 0; i < 60; i++)
        {
            int[] terms = sumBArray.GetRow(i);

            double termD = terms[0] * D;
            double termMSun = terms[1] * M;
            double termMMoon = terms[2] * MA;
            double termF = terms[3] * F;

            double term = termD + termMSun + termMMoon + termF; //Add up the four fundamental arguments D, M, M' and F.

            term = Sin(DEG_TO_RAD * term);

            if (terms[1] != 0)
            { //Term M depends on eccentricity of the Earth's orbit around the Sun
                if (terms[4] != 0)
                { //In case of last term, the coefficient does not exist, so exclude it
                    term = terms[4] * E * term; //Multiply sum of fundamental arguments by coefficient (include "E")
                }
                else
                {
                    term = E * term; //Multiply sum of fundamental arguments by coefficient (include "E")
                }
            }
            else
            {
                if (terms[4] != 0)
                {
                    term = terms[4] * term; //Multiply sum of fundamental arguments by coefficient (exclude "E")
                }
            }

            sumB = sumB + term;
        }

        //Additives to ∑b
        sumB -= 2235 * Sin(DEG_TO_RAD * L);
        sumB += 382 * Sin(DEG_TO_RAD * A3);
        sumB += 175 * Sin(DEG_TO_RAD * (A1 - F));
        sumB += 175 * Sin(DEG_TO_RAD * (A1 + F));
        sumB += 127 * Sin(DEG_TO_RAD * (L - MA));
        sumB -= 115 * Sin(DEG_TO_RAD * (L + MA));

        //Geocentric Longitude Moon
        double λ = L + sumL / 1000000;

        //Geocentric Latitude Moon
        double β = sumB / 1000000;

        double eps = 23.0 + 26.0 / 60.0 + 21.448 / 3600.0 - (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600;
        double X = Cos(β * DEG_TO_RAD) * Cos(λ * DEG_TO_RAD);
        double Y = Cos(eps * DEG_TO_RAD) * Cos(β * DEG_TO_RAD) * Sin(λ * DEG_TO_RAD) - Sin(eps * DEG_TO_RAD) * Sin(β * DEG_TO_RAD);
        double Z = Sin(eps * DEG_TO_RAD) * Cos(β * DEG_TO_RAD) * Sin(λ * DEG_TO_RAD) + Cos(eps * DEG_TO_RAD) * Sin(β * DEG_TO_RAD);
        double R = Sqrt(1 - Z * Z);

        double δ = RAD_TO_DEG * Atan(Z / R); // declination in degrees
        double RAH = 24 / PI * Atan(Y / (X + R)); // right a
        double RA = RAH * 15.0;

        double theta0 = Clamp360(280.46061837 + 360.98564736629 * (JD - 2451545.0) + 0.000387933 * T * T - T * T * T / 38710000.0); // degrees

        double theta = theta0 + longitude; //Local sidereal time

        double τ = theta - RA; //Hour angle 

        double elevation = RAD_TO_DEG * Asin(Sin(δ * DEG_TO_RAD) * Sin(latitude * DEG_TO_RAD) + Cos(δ * DEG_TO_RAD) * Cos(latitude * DEG_TO_RAD) * Cos(τ * DEG_TO_RAD));
        double paralax = RAD_TO_DEG * Asin(6378.1 / 384400.0);
        elevation -= paralax;

        double azimuth = Clamp360(RAD_TO_DEG * Atan(-Sin(τ * DEG_TO_RAD) / (Cos(latitude * DEG_TO_RAD) * Tan(δ * DEG_TO_RAD) - Sin(latitude * DEG_TO_RAD) * Cos(τ * DEG_TO_RAD))));

        return (azimuth, elevation);
    }

    private static double JulianDay(DateTime dateTime)
    {
        double day = dateTime.Day, month = dateTime.Month, year = dateTime.Year;
        if (month <= 2) { month += 12; year -= 1; }
        return (int)(365.25 * year) + (int)(30.6001 * (month + 1)) - 15 + 1720996.5 + day + dateTime.Hour / 24.0 + dateTime.Minute / 1440 + dateTime.Second / 84600;
    }

    public static double Clamp360(double value)
    {
        return value - 360 * Floor(value / 360);
    }

    //[0] = D (Moon Mean Elongation)
    //[1] = M (Sun Mean Anomaly)
    //[2] = M' (Moon Mean Anomaly)
    //[3] = F (Moon Argument of latitude)
    //[4] = Coefficient
    private readonly static int[,] sumLArray = {
        {0, 0, 1, 0, 6288774}, //1
		{2, 0, -1, 0, 1274027}, //2
		{2, 0, 0, 0, 658314}, //3
		{0, 0, 2, 0, 213618}, //4
		{0, 1, 0, 0, -185116}, //5
		{0, 0, 0, 2, -114332}, //6
		{2, 0, -2, 0, 58793}, //7
		{2, -1, -1, 0, 57066}, //8
		{2, 0, 1, 0, 53322}, //9
		{2, -1, 0, 0, 45758}, //10
		{0, 1, -1, 0, -40923}, //11
		{1, 0, 0, 0, -34720}, //12
		{0, 1, 1, 0, -30383}, //13
		{2, 0, 0, -2, 15327}, //14
		{0, 0, 1, 2, -12528}, //15
		{0, 0, 1, -2, 10980}, //16
		{4, 0, -1, 0, 10675}, //17
		{0, 0, 3, 0, 10034}, //18
		{4, 0, -2, 0, 8548}, //19
		{2, 1, -1, 0, -7888}, //20
		{2, 1, 0, 0, -6766}, //21
		{1, 0, -1, 0, -5163}, //22
		{1, 1, 0, 0, 4987}, //23
		{2, -1, 1, 0, 4036}, //24
		{2, 0, 2, 0, 3994}, //25
		{4, 0, 0, 0, 3861}, //26
		{2, 0, -3, 0, 3665}, //27
		{0, 1, -2, 0, -2689}, //28
		{2, 0, -1, 2, -2602}, //29
		{2, -1, -2, 0, 2390}, //30
		{1, 0, 1, 0, -2348}, //31
		{2, -2, 0, 0, 2236}, //32
		{0, 1, 2, 0, -2120}, //33
		{0, 2, 0, 0, -2069}, //34
		{2, -2, -1, 0, 2048}, //35
		{2, 0, 1, -2, -1773}, //36
		{2, 0, 0, 2, -1595}, //37
		{4, -1, -1, 0, 1215}, //38
		{0, 0, 2, 2, -1110}, //39
		{3, 0, -1, 0, -892}, //40
		{2, 1, 1, 0, -810}, //41
		{4, -1, -2, 0, 759}, //42
		{0, 2, -1, 0, -713}, //43
		{2, 2, -1, 0, -700}, //44
		{2, 1, -2, 0, 691}, //45
		{2, -1, 0, -2, 596}, //46
		{4, 0, 1, 0, 549}, //47
		{0, 0, 4, 0, 537}, //48
		{4, -1, 0, 0, 520}, //49
		{1, 0, -2, 0, -487}, //50
		{2, 1, 0, -2, -399}, //51
		{0, 0, 2, -2, -381}, //52
		{1, 1, 1, 0, 351}, //53
		{3, 0, -2, 0, -340}, //54
		{4, 0, -3, 0, 330}, //55
		{2, -1, 2, 0, 327}, //56
		{0, 2, 1, 0, -323}, //57
		{1, 1, -1, 0, 299}, //58
		{2, 0, 3, 0, 294}, //59
		{2, 0, -1, -2, 0} //60
    };

    //[0] = D (Moon Mean Elongation)
    //[1] = M (Sun Mean Anomaly)
    //[2] = M' (Moon Mean Anomaly)
    //[3] = F (Moon Argument of latitude)
    //[4] = Coefficient
    private readonly static int[,] sumBArray = {
        {0, 0, 0, 1, 5128122}, //1
        {0, 0, 1, 1, 280602}, //2
        {0, 0, 1, -1, 277693}, //3
        {2, 0, 0, -1, 173237}, //4
        {2, 0, -1, 1, 55413}, //5
        {2, 0, -1, -1, 46271}, //6
        {2, 0, 0, 1, 32573}, //7
        {0, 0, 2, 1, 17198}, //8
        {2, 0, 1, -1, 9266}, //9
        {0, 0, 2, -1, 8822}, //10
        {2, -1, 0, -1, 8216}, //11
        {2, 0, -2, -1, 4324}, //12
        {2, 0, 1, 1, 4200}, //13
        {2, 1, 0, -1, -3359}, //14
        {2, -1, -1, 1, 2463}, //15
        {2, -1, 0, 1, 2211}, //16
        {2, -1, -1, -1, 2065}, //17
        {0, 1, -1, -1, -1870}, //18
        {4, 0, -1, -1, 1828}, //19
        {0, 1, 0, 1, -1794}, //20
        {0, 0, 0, 3, -1749}, //21
        {0, 1, -1, 1, -1565}, //22
        {1, 0, 0, 1, -1491}, //23
        {0, 1, 1, 1, -1475}, //24
        {0, 1, 1, -1, -1410}, //25
        {0, 1, 0, -1, -1344}, //26
        {1, 0, 0, -1, -1335}, //27
        {0, 0, 3, 1, 1107}, //28
        {4, 0, 0, -1, 1021}, //29
        {4, 0, -1, 1, 833}, //30
        {0, 0, 1, -3, 777}, //31
        {4, 0, -2, 1, 671}, //32
        {2, 0, 0, -3, 607}, //33
        {2, 0, 2, -1, 596}, //34
        {2, -1, 1, -1, 491}, //35
        {2, 0, -2, 1, -451}, //36
        {0, 0, 3, -1, 439}, //37
        {2, 0, 2, 1, 422}, //38
        {2, 0, -3, -1, 421}, //39
        {2, 1, -1, 1, -366}, //40
        {2, 1, 0, 1, -351}, //41
        {4, 0, 0, 1, 331}, //42
        {2, -1, 1, 1, 315}, //43
        {2, -2, 0, -1, 302}, //44
        {0, 0, 1, 3, -283}, //45
        {2, 1, 1, -1, -229}, //46
        {1, 1, 0, -1, 223}, //47
        {1, 1, 0, 1, 223}, //48
        {0, 1, -2, -1, -220}, //49
        {2, 1, -1, -1, -220}, //50
        {1, 0, 1, 1, -185}, //51
        {2, -1, -2, -1, 181}, //52
        {0, 1, 2, 1, -177}, //53
        {4, 0, -2, -1, 176}, //54
        {4, -1, -1, -1, 166}, //55
        {1, 0, 1, -1, -164}, //56
        {4, 0, 1, -1, 132}, //57
        {1, 0, -1, -1, -119}, //58
        {4, -1, 0, -1, 115}, //59
        {2, -2, 0, 1, 107} //60
	
    };
}

public static class ArrayExt
{
    public static T[] GetRow<T>(this T[,] array, int row)
    {
        if (!typeof(T).IsPrimitive)
            throw new InvalidOperationException("Not supported for managed types.");

        if (array == null)
            throw new ArgumentNullException("array");

        int cols = array.GetUpperBound(1) + 1;
        T[] result = new T[cols];

        int size;

        if (typeof(T) == typeof(bool))
            size = 1;
        else if (typeof(T) == typeof(char))
            size = 2;
        else
            size = Marshal.SizeOf<T>();

        Buffer.BlockCopy(array, row * cols * size, result, 0, cols * size);

        return result;
    }
}