using System;
using static System.Math;
using UnityEngine;
using System.Linq;

public static class AstroCalsulator
{
    private const double DEG_TO_RAD = PI / 180.0;
    private const double RAD_TO_DEG = 180.0 / PI;

    private const double JULIAN_CENTURY = 36525.0;
    private const double JULIAN_EPOCH = 2451545.0;

    public static (double Azimuth, double Elevation, double Distance) CalculateSunPosition(DateTime date, double longitude, double latitude)
    {
        //Julian Day
        double JD = calculateJulianDay(date.ToUniversalTime());

        // [Meeus] 24.1
        double T = (JD - JULIAN_EPOCH) / JULIAN_CENTURY; 

        //mean longitude of the Sun [Meeus] 24.2
        double L = 280.46645 + 36000.76983 * T + 0.0003032 * Pow(T,2);

        //The mean anomaly of the Sun [Meeus] 24.3
        double M = 357.52910 + 35999.05030 * T - 0.0001559 * Pow(T,2) - 0.00000048 * Pow(T,3);

        //Eccentricity of the Earth's orbit [Meeus] 24.4
        double e = 0.016708617 - 0.000042037 * T - 0.0000001236 * Pow(T,2);

        //Sun's equation of center C [Meeus] Page 152
        double C = (1.914600 - 0.004817 * T - 0.000014 * T * T) * Sin(M * DEG_TO_RAD)+ (0.019993 - 0.000101 * T) * Sin(2 * M * DEG_TO_RAD) + 0.000290 * Sin(3 *M * DEG_TO_RAD);

        //Sun's true longitude [Meeus] Page 152
        double lambda = L + C;

        //Sun's true anomaly [Meeus] Page 152
        double v = M + C;
        
        //Obliquity of ecliptic [Meeus] 21.2
        double epsilon = 23.0 + 26.0 / 60.0 + 21.448 / 3600.0 - (46.8150 * T + 0.00059 * Pow(T,2) - 0.001813 * Pow(T,3)) / 3600.0;

        //[Meeus] Page 9. This is derevived from the formula on the page
        double sinDelta = Sin(epsilon * DEG_TO_RAD) * Sin(lambda * DEG_TO_RAD);
        double delta = Asin(sinDelta) * RAD_TO_DEG;

        double y = Cos(epsilon * DEG_TO_RAD) * Sin(lambda * DEG_TO_RAD);
        double x = Cos(lambda * DEG_TO_RAD);

        double RA = Atan2(y, x) * RAD_TO_DEG;

        //sidereal time at Greenwich [Meeus] 11.4
        double ST = 280.46061837 + 360.98564736629 * (JD - JULIAN_EPOCH) + 0.000387933 * Pow(T,2) - Pow(T,3) / 38710000.0;

        //Local Hour angle [Meeus] Page 88. Formula Derivated from local hour angle formula
        double LHA = ST + longitude - RA; 

        Debug.ClearDeveloperConsole();

        //[Meeus] 12.5
        double elevation = Asin(Sin(delta * DEG_TO_RAD) * Sin(latitude * DEG_TO_RAD) + Cos(delta * DEG_TO_RAD) * Cos(latitude * DEG_TO_RAD) * Cos(LHA * DEG_TO_RAD)) * RAD_TO_DEG;
        Debug.Log("Elevation: " + elevation);
        //[Meeus] 12.6
        double azimuth = Clamp360(Atan2(-Sin(LHA * DEG_TO_RAD), Cos(latitude * DEG_TO_RAD) * Tan(delta * DEG_TO_RAD) - Sin(latitude * DEG_TO_RAD) * Cos(LHA * DEG_TO_RAD)) * RAD_TO_DEG);
        Debug.Log("Azimuth: " + azimuth);
        //[Meeus] Page 152. Value is converted from astronomical units to km by myltiplying by 149597870.7
        double distance = 1.000001018 * (1 - Pow(e, 2)) / (1 + e * Cos(v * DEG_TO_RAD)) * 149597870.7;
        
        return (azimuth,elevation,distance);
    }

    public static (double Azimuth, double Elevation, double Distance) CalculateMoonPosition(DateTime date, double longitude, double latitude)
    {
        //Julian Day
        double JD = calculateJulianDay(date.ToUniversalTime());
        // [Meeus] 24.1
        double T = (JD - JULIAN_EPOCH) / JULIAN_CENTURY;

        //MOON MEAN LONGITUDE [Meeus] 45.1
        double L = Clamp360(218.3164591 + 481267.88134236 * T - 0.0013268 * Pow(T, 2) + Pow(T, 3) / 538841 - Pow(T, 4) / 65194000);

        //MOON MEAN ELONGATION [Meeus] 45.2
        double D = Clamp360(297.8502042 + 445267.1115168 * T - 0.0016300 * Pow(T, 2) + Pow(T, 3) / 545868 - Pow(T, 4) / 113065000);

        //SUN MEAN ANOMALY [Meeus] 45.3
        double M = Clamp360(357.5291092 + 35999.0502909 * T - 0.0001536 * Pow(T, 2) + Pow(T, 3) / 24490000);

        //MOON MEAN ANOMALY [Meeus] 45.4
        double MA = Clamp360(134.9634114 + 477198.8676313 * T + 0.0089970 * Pow(T, 2) + Pow(T, 3) / 69699 - Pow(T, 4) / 14712000);

        //MOON ARGUMENT OF LATITUDE [Meeus] 45.5
        double F = Clamp360(93.2720993 + 483202.0175273 * T - 0.0034029 * Pow(T, 2) - Pow(T, 3) / 3526000 + Pow(T, 4) / 863310000);

        //Calculate "A1" (due to the action of Venus) [Meeus] Page 308
        double A1 = Clamp360(119.75 + (131.849 * T));

        //Calculate "A2" (due to the action of Jupiter) [Meeus] Page 308
        double A2 = Clamp360(53.09 + (479264.290 * T));

        //Calculate "A3" [Meeus] Page 308
        double A3 = Clamp360(313.45 + (481266.484 * T));

        //Earth's eccentricity of its orbit around the Sun [Meeus] 45.5
        double E = Clamp360(1.0 - 0.002516 * T - 0.0000074 * Pow(T, 2));

        double sumL = 0;
        double sumB = 0;
        double sumR = 0;

        //Calculate ∑l, ∑b and ∑r simultaneously
        for (int i = 0; i < 60; i++)
        {
            int[] terms = sumLArray.GetRow(i);

            double termD = terms[0] * D;
            double termMSun;
            double termMMoon = terms[2] * MA;
            double termF = terms[3] * F;

            if(terms[1] == 1 || terms[1] == -1){
                termMSun = terms[1] * M * E;
            }else if(terms[1] == 2 || terms[1] == -2){
                termMSun = terms[1] * M * Pow(E,2);
            }else{
                termMSun = terms[1] * M;
            }
            
            double sumLAddition = termD + termMSun + termMMoon + termF;
            sumLAddition = terms[4] * Sin(DEG_TO_RAD * sumLAddition);
            double sumRAddition = terms[5] * Cos(DEG_TO_RAD * sumLAddition);

            terms = sumBArray.GetRow(i);

            termD = terms[0] * D;
            termMMoon = terms[2] * MA;
            termF = terms[3] * F;

            if(terms[1] == 1 || terms[1] == -1){
                termMSun = terms[1] * M * E;
            }else if(terms[1] == 2 || terms[1] == -2){
                termMSun = terms[1] * M * Pow(E,2);
            }else{
                termMSun = terms[1] * M;
            }

            //Add up the four fundamental arguments D, M, M' and F.
            double sumBAddition = termD + termMSun + termMMoon + termF;
            sumBAddition = terms[4] * Sin(DEG_TO_RAD * sumBAddition);

            sumL += sumLAddition;
            sumB += sumBAddition;
            sumR += sumRAddition;
        }

        //Additives to ∑l [Meeus] Page 312
        sumL += 3958.0 * Sin(DEG_TO_RAD * A1);
        sumL += 1962.0 * Sin(DEG_TO_RAD * (L - F));
        sumL += 318.0 * Sin(DEG_TO_RAD * A2);

        //Additives to ∑b [Meeus] Page 312
        sumB -= 2235.0 * Sin(DEG_TO_RAD * L);
        sumB += 382.0 * Sin(DEG_TO_RAD * A3);
        sumB += 175.0 * Sin(DEG_TO_RAD * (A1 - F));
        sumB += 175.0 * Sin(DEG_TO_RAD * (A1 + F));
        sumB += 127.0 * Sin(DEG_TO_RAD * (L - MA));
        sumB -= 115.0 * Sin(DEG_TO_RAD * (L + MA));

        //Geocentric Longitude Moon [Meeus] Page 312
        double lamdba = L + sumL / 1000000.0 - 1.127527;

        //Geocentric Latitude Moon [Meeus] Page 312
        double beta = sumB / 1000000.0;

        //Distance to the moon [Meeus] Page 312
        double distance = 385000.56 - sumR / 1000.0;

        //Moon paralax [Meeus] Page 308
        double p = Asin(6378.14 / distance);

        //[Meeus] Page 9. This block is derevived from the formula on the page
        double eps = 23.0 + 26.0 / 60.0 + 21.448 / 3600.0 - (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600;
        double X = Cos(beta * DEG_TO_RAD) * Cos(lamdba * DEG_TO_RAD);
        double Y = Cos(eps * DEG_TO_RAD) * Cos(beta * DEG_TO_RAD) * Sin(lamdba * DEG_TO_RAD) - Sin(eps * DEG_TO_RAD) * Sin(beta * DEG_TO_RAD);
        double Z = Sin(eps * DEG_TO_RAD) * Cos(beta * DEG_TO_RAD) * Sin(lamdba * DEG_TO_RAD) + Cos(eps * DEG_TO_RAD) * Sin(beta * DEG_TO_RAD);
        double R = Sqrt(1.0 - Z * Z);
        double delta = RAD_TO_DEG * Atan(Z / R);
        double RAH = 24.0 / PI * Atan(Y / (X + R)); 

        //[Meeus] Page 8. one hour corresponds to 15 degrees.
        double RA = RAH * 15.0;

        //sidereal time at Greenwich [Meeus] 11.4
        double ST = 280.46061837 + 360.98564736629 * (JD - JULIAN_EPOCH) + 0.000387933 * Pow(T,2) - Pow(T,3) / 38710000.0;

        //Local Hour angle [Meeus] Page 88. Formula Derivated from local hour angle formula
        double LHA = ST + longitude - RA; 

        //[Meeus] 12.5
        double elevation = RAD_TO_DEG * Asin(Sin(delta * DEG_TO_RAD) * Sin(latitude * DEG_TO_RAD) + Cos(delta * DEG_TO_RAD) * Cos(latitude * DEG_TO_RAD) * Cos(LHA * DEG_TO_RAD));

        //[Meeus] 12.6
        double azimuth = RAD_TO_DEG * Atan2(-Sin(LHA * DEG_TO_RAD), Cos(latitude * DEG_TO_RAD) * Tan(delta * DEG_TO_RAD) - Sin(latitude * DEG_TO_RAD) * Cos(LHA * DEG_TO_RAD));

        return (azimuth, elevation, distance);
    }

    //[Meeus] 7.1
    public static double calculateJulianDay(DateTime date)
    {
        int year = date.Year;
        int month = date.Month;
        double day = date.Day + (date.Hour + (date.Minute + date.Second / 60.0) / 60.0) / 24.0;

        if (month <= 2)
        {
            year -= 1;
            month += 12;
        }

        double B = 0;
        int A = year / 100;

        if (date >= new DateTime(1582, 10, 15))
        {
            B = 2 - A + (A / 4);
        }

        double jd = (int)(365.25 * (year + 4716))
                  + (int)(30.6001 * (month + 1))
                  + day + B - 1524.5;

        return jd;
    }

    public static double Clamp360(double value)
    {
        return value - 360.0 * Floor(value / 360.0);
    }

    //[Meeus] 45.A
    //[0] = D (Moon Mean Elongation)
    //[1] = M (Sun Mean Anomaly)
    //[2] = M' (Moon Mean Anomaly)
    //[3] = F (Moon Argument of latitude)
    //[4] = Coefficient l
    //[5] = Coefficient r
    private readonly static int[,] sumLArray = {
        {0, 0, 1, 0, 6288774, -20905355}, //1
		{2, 0, -1, 0, 1274027, -3699111}, //2
		{2, 0, 0, 0, 658314, -2955968}, //3
		{0, 0, 2, 0, 213618, -569925}, //4
		{0, 1, 0, 0, -185116, 48888}, //5
		{0, 0, 0, 2, -114332, -3149}, //6
		{2, 0, -2, 0, 58793, 246158}, //7
		{2, -1, -1, 0, 57066, -152138}, //8
		{2, 0, 1, 0, 53322, -170733}, //9
		{2, -1, 0, 0, 45758, -204586}, //10
		{0, 1, -1, 0, -40923, -129620}, //11
		{1, 0, 0, 0, -34720, 108743}, //12
		{0, 1, 1, 0, -30383, 104755}, //13
		{2, 0, 0, -2, 15327, 10321}, //14
		{0, 0, 1, 2, -12528, 0}, //15
		{0, 0, 1, -2, 10980, 79661}, //16
		{4, 0, -1, 0, 10675, -34782}, //17
		{0, 0, 3, 0, 10034, -23210}, //18
		{4, 0, -2, 0, 8548, -21636}, //19
		{2, 1, -1, 0, -7888, 24208}, //20
		{2, 1, 0, 0, -6766, 30824}, //21
		{1, 0, -1, 0, -5163, -8379}, //22
		{1, 1, 0, 0, 4987, -16675}, //23
		{2, -1, 1, 0, 4036, -12831}, //24
		{2, 0, 2, 0, 3994, -10445}, //25
		{4, 0, 0, 0, 3861, -11650}, //26
		{2, 0, -3, 0, 3665, 14403}, //27
		{0, 1, -2, 0, -2689, -7003}, //28
		{2, 0, -1, 2, -2602, 0}, //29
		{2, -1, -2, 0, 2390, 10056}, //30
		{1, 0, 1, 0, -2348, 6322}, //31
		{2, -2, 0, 0, 2236, -9884}, //32
		{0, 1, 2, 0, -2120, 5751}, //33
		{0, 2, 0, 0, -2069, 0}, //34
		{2, -2, -1, 0, 2048, -4950}, //35
		{2, 0, 1, -2, -1773, 4130}, //36
		{2, 0, 0, 2, -1595, 0}, //37
		{4, -1, -1, 0, 1215, -3958}, //38
		{0, 0, 2, 2, -1110, 0}, //39
		{3, 0, -1, 0, -892, 3258}, //40
		{2, 1, 1, 0, -810, 2616}, //41
		{4, -1, -2, 0, 759, -1897}, //42
		{0, 2, -1, 0, -713, -2117}, //43
		{2, 2, -1, 0, -700, 2354}, //44
		{2, 1, -2, 0, 691, 0}, //45
		{2, -1, 0, -2, 596, 0}, //46
		{4, 0, 1, 0, 549, -1423}, //47
		{0, 0, 4, 0, 537, -1117}, //48
		{4, -1, 0, 0, 520, -1571}, //49
		{1, 0, -2, 0, -487, -1739}, //50
		{2, 1, 0, -2, -399, 0}, //51
		{0, 0, 2, -2, -381, -4421}, //52
		{1, 1, 1, 0, 351, 0}, //53
		{3, 0, -2, 0, -340, 0}, //54
		{4, 0, -3, 0, 330, 0}, //55
		{2, -1, 2, 0, 327, 0}, //56
		{0, 2, 1, 0, -323,1165}, //57
		{1, 1, -1, 0, 299,0}, //58
		{2, 0, 3, 0, 294, 0}, //59
		{2, 0, -1, -2, 0, 8752} //60
    };

    //[Meeus] 45.B
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

//https://stackoverflow.com/questions/27427527/how-to-get-a-complete-row-or-column-from-2d-array-in-c-sharp modified
public static class ArrayExt
{
    public static T[] GetRow<T>(this T[,] matrix, int rowNumber)
    {
        return Enumerable.Range(0, matrix.GetLength(1))
                .Select(x => matrix[rowNumber, x])
                .ToArray();
    }
}