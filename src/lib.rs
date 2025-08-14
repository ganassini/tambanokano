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

#[no_mangle]
pub extern "C" fn raytrace_scene(
    buffer: *mut u8,
    width: i32,
    height: i32,
    cam_x: f64,
    cam_y: f64,
    cam_z: f64,
    look_x: f64,
    look_y: f64, 
    look_z: f64,
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
            
            let color = raytrace_pixel(x, y, width, height, cam_x, cam_y, cam_z);
            
            pixel[0] = (color[0] * 255.0) as u8;
            pixel[1] = (color[1] * 255.0) as u8; 
            pixel[2] = (color[2] * 255.0) as u8;
            pixel[3] = 255;
        });
}

#[no_mangle]
pub extern "C" fn apply_water_forces(
    heights: *mut f32,
    velocities: *mut f32,
    size: i32,
    dt: f32,
) {
    let size = size as usize;
    let heights_slice = unsafe { std::slice::from_raw_parts_mut(heights, size * size) };
    let velocities_slice = unsafe { std::slice::from_raw_parts_mut(velocities, size * size) };
    
    let wave_speed = 1.5;
    let damping = 0.98;
    
    for y in 1..size-1 {
        for x in 1..size-1 {
            let idx = y * size + x;
            
            let h_center = heights_slice[idx];
            let h_left = heights_slice[idx - 1];
            let h_right = heights_slice[idx + 1]; 
            let h_up = heights_slice[idx - size];
            let h_down = heights_slice[idx + size];
            
            let laplacian = h_left + h_right + h_up + h_down - 4.0 * h_center;
            let acceleration = wave_speed * wave_speed * laplacian;
            
            velocities_slice[idx] = (velocities_slice[idx] + acceleration * dt) * damping;
        }
    }
    
    for i in 0..heights_slice.len() {
        heights_slice[i] += velocities_slice[i] * dt;
    }
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

fn raytrace_pixel(px: i32, py: i32, width: i32, height: i32, cam_x: f64, cam_y: f64, cam_z: f64) -> [f64; 3] {
    let x = (px as f64 / width as f64) * 2.0 - 1.0;
    let y = 1.0 - (py as f64 / height as f64) * 2.0;
    
    let ray_dir_x = x;
    let ray_dir_y = y;
    let ray_dir_z = -1.0;
    
    let ray_len = (ray_dir_x * ray_dir_x + ray_dir_y * ray_dir_y + ray_dir_z * ray_dir_z).sqrt();
    let ray_x = ray_dir_x / ray_len;
    let ray_y = ray_dir_y / ray_len;
    let ray_z = ray_dir_z / ray_len;
    
    let sphere_center = [0.0, 0.0, -10.0];
    let sphere_radius = 3.0;
    
    let oc_x = cam_x - sphere_center[0];
    let oc_y = cam_y - sphere_center[1];
    let oc_z = cam_z - sphere_center[2];
    
    let a = ray_x * ray_x + ray_y * ray_y + ray_z * ray_z;
    let b = 2.0 * (oc_x * ray_x + oc_y * ray_y + oc_z * ray_z);
    let c = oc_x * oc_x + oc_y * oc_y + oc_z * oc_z - sphere_radius * sphere_radius;
    
    let discriminant = b * b - 4.0 * a * c;
    
    if discriminant < 0.0 {
        let t = (y + 1.0) * 0.5;
        [0.5 * (1.0 - t) + 0.1 * t, 0.7 * (1.0 - t) + 0.3 * t, 1.0 * (1.0 - t) + 0.6 * t]
    } else {
        let t = (-b - discriminant.sqrt()) / (2.0 * a);
        
        if t > 0.0 {
            let hit_x = cam_x + t * ray_x;
            let hit_y = cam_y + t * ray_y;
            let hit_z = cam_z + t * ray_z;
            
            let u = (hit_x + sphere_radius) / (2.0 * sphere_radius);
            let v = (hit_y + sphere_radius) / (2.0 * sphere_radius);
            
            let fractal_color = calculate_mandelbrot(
                (u * 256.0) as i32, (v * 256.0) as i32, 
                256, 256, 
                -0.5, 0.0, 1.0, 100
            );
            
            [fractal_color.r as f64 / 255.0, fractal_color.g as f64 / 255.0, fractal_color.b as f64 / 255.0]
        } else {
            [0.2, 0.3, 0.8]
        }
    }
}
