/*
  Simple TF-Luna LiDAR / rangefinder mount plate

  Official reference:
  - Benewake TF-Luna Datasheet A05, dimensions figure.
  - Official PDF: https://en.benewake.com/uploadfiles/2025/04/20250430174501874.pdf
  - Body: 35 x 21.25 x 12.5 mm.
  - Optical window diameter: 10.5 mm.
  - Mounting holes: 2 x dia 2.2 mm.

  Project measurement:
  - Mounting-hole center spacing measured on the part: 30 mm.
*/

$fn = 64;

plate_width = 42;
plate_height = 24;
plate_thickness = 3;
corner_radius = 2;

// TF-Luna screw holes.
hole_spacing = 30; // measured center-to-center distance
hole_diameter = 2.6; // M2 clearance, official sensor hole is dia 2.2 mm

// Velcro-friendly optical slits.
// Official optical window diameter is 10.5 mm. These narrow slits keep more
// rear surface area for hook-and-loop tape while leaving the optical centers open.
slit_spacing = 10.5;
slit_width = 5;
slit_height = 14;
slit_y = 1.6;
slit_radius = 2.5;

module rounded_rect(width, height, radius) {
    hull() {
        for (x = [-width / 2 + radius, width / 2 - radius]) {
            for (y = [-height / 2 + radius, height / 2 - radius]) {
                translate([x, y]) circle(r = radius);
            }
        }
    }
}

module plate() {
    linear_extrude(height = plate_thickness) {
        rounded_rect(plate_width, plate_height, corner_radius);
    }
}

module cut_hole(x, y, diameter) {
    translate([x, y, -0.1]) {
        cylinder(h = plate_thickness + 0.2, d = diameter);
    }
}

module cut_slit(x, y) {
    translate([x, y, -0.1]) {
        linear_extrude(height = plate_thickness + 0.2) {
            rounded_rect(slit_width, slit_height, slit_radius);
        }
    }
}

difference() {
    plate();

    for (x = [-slit_spacing / 2, slit_spacing / 2]) {
        cut_slit(x, slit_y);
    }

    for (x = [-hole_spacing / 2, hole_spacing / 2]) {
        cut_hole(x, 0, hole_diameter);
    }
}
