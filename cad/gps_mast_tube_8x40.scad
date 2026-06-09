/*
  GPS mast tube

  Project requirement:
  - Outside diameter: 8 mm
  - Tube length: 40 mm
  - Shape: cylindrical tube

  The 1.5 mm wall leaves a 5 mm inside diameter.
*/

$fn = 96;

outer_diameter = 8;
length = 40;
wall_thickness = 1.5;

inner_diameter = outer_diameter - (wall_thickness * 2);

module gps_mast_tube() {
    difference() {
        cylinder(h = length, d = outer_diameter);

        translate([0, 0, -0.1]) {
            cylinder(h = length + 0.2, d = inner_diameter);
        }
    }
}

gps_mast_tube();
