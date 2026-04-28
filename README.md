# Advanced Sky Simulation

This project renders a realistic sky based on date, time, and observer coordinates. It consists of two parts:

- **Sun & Moon Position Calculation** — implemented in [AstroCalculator.cs](Assets/Scripts/AstroCalculator.cs)
- **Sky Rendering** — renders the Sun, Moon, and sky color using the calculated data, implemented in [Skybox2.shader](Assets/Shader/Skybox2.shader)

Built with **Unity 2022**

## Progress

The algorithm for calculating the Sun's and Moon's positions is complete. A small margin of error remains, which could be reduced by adding more terms to the `sumLArray` and `sumBArray` coefficient tables.

Sky rendering currently uses the single-scattering algorithm from Tomoyuki Nishita's 2000 paper. The rendering is incomplete — moon rendering is missing and visual results are unsatisfactory. A rewrite using precomputed values and multiple scattering (as described in the *Efficient and Dynamic Atmospheric Scattering* paper) would likely yield significantly better results.

## Sources & Inspiration
- [Astronomical Algorithms – Jean Meeus (1991)](https://dn710207.ca.archive.org/0/items/astronomicalalgorithmsjeanmeeus1991/Astronomical%20Algorithms-%20Jean%20Meeus%20%281991%29_text.pdf)
- [Frostbite Sky & Clouds Rendering (EA)](https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf)
- [Simulating the Colors of the Sky](https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky.html)
- [Display of The Earth Taking into Account Atmospheric Scattering (1993)](http://nishitalab.org/user/nis/cdrom/sig93_nis.pdf)
- [Display Method of the Sky Color Taking into Account Multiple Scattering (2000)](https://www.researchgate.net/publication/242513955_Display_method_of_the_sky_color_taking_into_account_multiple_scattering)
- [Efficient and Dynamic Atmospheric Scattering (2014)](https://odr.chalmers.se/server/api/core/bitstreams/c188a150-4d52-4456-b257-2e95156dd8d3/content)
- [Sebastian Lague - Coding Adventure: Atmosphere](https://www.youtube.com/watch?v=DxfEbulyFcY)
- [SunCalc](https://www.suncalc.org)
- [GeoAstro](http://www.geoastro.de/astro/index.htm)
