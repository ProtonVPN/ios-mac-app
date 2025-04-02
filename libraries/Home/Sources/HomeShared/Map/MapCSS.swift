//
//  Created on 23/09/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

enum MapCSS {
    static let css: String =
    /*
     * Below are Cascading Style Sheet (CSS) definitions in use in this file,
     * which allow easily changing how countries are displayed.
     *
     * The styles are applied in the order in which they are defined (and re-defined) here in the preamble.
     */

    /*
     * Circles around small countries and territories
     *
     * Change opacity to 1 to display all circles
     */
"""
.circlexx
{
    opacity: 0;
    fill: #c0c0c0;
    stroke: #000000;
    stroke-width: 0.5;
}
"""
    /*
     * Smaller circles around subnational territories: Australian external territories, Chinese SARs, Dutch special municipalities, and French DOMs (overseas regions/departments) [but not French COMs (overseas collectivities)]
     *
     * Change opacity to 1 to display all circles
     */
    + """
.subxx
{
    opacity: 0;
    fill: #c0c0c0;
    stroke: #000000;
    stroke-width: 0.3;
}
"""

    /*
     * Land
     * (all land, as opposed to water, should belong to this class; in order to modify the coastline for land pieces with no borders on them a special class "coastxx" has been added below)
     */
    + """
.landxx
{
    fill: #292733;
    stroke: #7B768D;
    stroke-width: 0.1;
    fill-rule: evenodd;
}
"""
    /*
     * Styles for coastlines of islands and continents with no borders on them
     * (all of them should also belong to the class "landxx" - to allow for all land to be modified at once by refining "landxx" style's definition further down)
     */
    + """
.coastxx
{
    stroke-width: 0.2;
}
"""

    /*
     * Styles for territories without permanent population (the largest of which is Antarctica)
     *
     * Change opacity to 0 to hide all territories
     */
    + """
.antxx
{
    opacity: 1;
    fill: #c0c0c0;
}
"""
    /*
     * Circles around small countries without permanent population
     *
     * Change opacity to 1 to display all circles
     */
    + """
.noxx
{
    opacity: 0;
    fill: #c0c0c0;
    stroke: #000000;
    stroke-width: 0.5;
}
"""

    /*
     * Styles for territories with limited or no recognition
     * (all of them - including Taiwan - are overlays (i.e. duplicate layers) over their "host" countries, and so not showing them doesn't leave any gaps on the map)
     *
     * Change opacity to 1 to display all territories
     */
    + """
.limitxx
{
    opacity: 0;
    fill: #c0c0c0;
    stroke: #ffffff;
    stroke-width: 0.2;
    fill-rule: evenodd;
}
"""
    /*
     * Smaller circles around small territories with limited or no recognition
     *
     * Change opacity to 1 to display all circles
     */
    + """
.unxx
{
    opacity: 0;
    fill: #c0c0c0;
    stroke: #000000;
    stroke-width: 0.3;
}
"""

    /*
     * Oceans, seas, and large lakes
     */
    + """
.oceanxx
{
    opacity: 0;
    fill: #ffffff;
    stroke: #000000;
    stroke-width: 0.5;
}
"""

    /*
     * Reserved class names:
     *
     * .eu - for members of European Union
     * .eaeu - for members of Eurasian Economic Union
     */


    /*
     * Additional style rules
     *
     * The following are examples of colouring countries.
     * These can be substituted with custom styles to colour the countries on the map.
     *
     * Colour a few countries:
     *
     * .gb, .au, .nc
     * {
     *     fill: #ff0000;
     * }
     *
     * Colour a few small-country circles (along with the countries):
     *
     * .ms, .ky
     * {
     *     opacity: 1;
     *     fill: #ff0000;
     * }
     *
     */
}
