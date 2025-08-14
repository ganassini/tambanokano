use std::f64::consts::PI;
use rayon::prelude::*;
use num_complex::Complex64;

#[repr(C)]
pub struct Color {
    r: u8,
    g: u8, 
    b: u8,
}

#[no_mangle]
pub extern "C" fn generate_fractal(
    buffer: *mut u8,
    width: i32,
    height: i32,
    center_x: f64,
    center_y: f64,
    zoom: f64,
    max_iterations: i32,
) {
    let buffer_slice = unsafe {
        std::slice::from_raw_parts_mut(buffer, (width * height * 4) as usize)
    };
    
    buffer_slice
        .par_chunks_exact_mut(4)
        .enumerate()
        .for_each(|(i, pixel)| {
            let x = i as i32 % width;
            let y = i as i32 / width;
            
            let color = calculate_mandelbrot(x, y, width, height, center_x, center_y, zoom, max_iterations);
            
            pixel[0] = color.r;
            pixel[1] = color.g; 
            pixel[2] = color.b;
            pixel[3] = 255;
        });
}

fn calculate_mandelbrot(
    px: i32, py: i32, width: i32, height: i32,
    center_x: f64, center_y: f64, zoom: f64, max_iter: i32
) -> Color {
    let scale = 4.0 / zoom;
    let x = (px as f64 - width as f64 / 2.0) * scale / width as f64 + center_x;
    let y = (py as f64 - height as f64 / 2.0) * scale / height as f64 + center_y;
    
    let c = Complex64::new(x, y);
    let mut z = Complex64::new(0.0, 0.0);
    let mut iteration = 0;
    
    while z.norm_sqr() <= 4.0 && iteration < max_iter {
        z = z * z + c;
        iteration += 1;
    }
    
    if iteration == max_iter {
        Color { r: 0, g: 0, b: 0 }
    } else {
        let smooth_iter = iteration as f64 + 1.0 - z.norm_sqr().ln().ln() / 2.0_f64.ln();
        psychedelic_color(smooth_iter / max_iter as f64)
    }
}

fn psychedelic_color(t: f64) -> Color {
    let r = ((t * PI * 3.0).sin() * 0.5 + 0.5) * 255.0;
    let g = ((t * PI * 5.0 + PI / 3.0).sin() * 0.5 + 0.5) * 255.0;
    let b = ((t * PI * 7.0 + 2.0 * PI / 3.0).sin() * 0.5 + 0.5) * 255.0;
    
    Color {
        r: r as u8,
        g: g as u8,
        b: b as u8,
    }
}
