#version 410 core
// sky_capture: written by ae3d.gpu from its quote.

uniform int kind;
uniform vec3 sky_sun;
uniform vec3 cloud_sun;
uniform vec3 cloud_sun_colour;
uniform float turbidity;
uniform vec3 flat_colour;
uniform float overcast;
uniform vec3 overcast_colour;
uniform float cloud_cover;
uniform float cloud_time;
uniform vec3 eye;
uniform sampler2D skybox;
uniform sampler2D cloud_weather;
uniform sampler3D cloud_shape;
uniform sampler3D cloud_detail;

struct CloudSample {
    float density;
    float height;
};

vec3 ae3d_shaders_skydome_texel_decode(vec2 p) {
    vec3 d = vec3(p.x, 1.0 - abs(p.x) - abs(p.y), p.y);
    if (d.y < 0.0) {
        vec2 folded = (vec2(1.0) - abs(d.zx)) * vec2(d.x >= 0.0 ? 1.0 : -1.0, d.z >= 0.0 ? 1.0 : -1.0);
        d = vec3(folded.x, d.y, folded.y);
    }
    return normalize(d);
}

vec3 ae3d_shaders_skydome_texel_direction(vec2 uv, float size) {
    vec2 p = (uv * size - vec2(1.0)) / (size - 2.0) * 2.0 - vec2(1.0);
    float px = p.x;
    float py = p.y;
    if (px > 1.0) {
        px = 2.0 - px;
        py = -py;
    }
    if (px < -1.0) {
        px = -2.0 - px;
        py = -py;
    }
    if (py > 1.0) {
        py = 2.0 - py;
        px = -px;
    }
    if (py < -1.0) {
        py = -2.0 - py;
        px = -px;
    }
    return ae3d_shaders_skydome_texel_decode(vec2(px, py));
}

vec3 ae3d_shaders_skydome_dusk_sky(vec3 dir, vec3 sun, vec3 sun_colour) {
    float elevation = sun.y;
    float day = smoothstep(-0.14, 0.06, elevation);
    float low = 1.0 - smoothstep(-0.05, 0.35, elevation);
    vec3 zenith_day = vec3(0.20, 0.42, 0.85);
    vec3 zenith_dusk = vec3(0.16, 0.20, 0.45);
    vec3 zenith_night = vec3(0.02, 0.03, 0.08);
    vec3 horizon_day = vec3(0.72, 0.82, 0.93);
    vec3 horizon_dusk = vec3(1.0, 0.52, 0.22);
    vec3 horizon_night = vec3(0.06, 0.07, 0.13);
    float toward = 0.5 + 0.5 * dot(normalize(vec2(dir.x, dir.z) + vec2(0.00001)), normalize(vec2(sun.x, sun.z) + vec2(0.00001)));
    vec3 horizon = mix(horizon_day, horizon_dusk, low * (0.25 + 0.75 * toward * toward));
    horizon = mix(horizon_night, horizon, day);
    vec3 zenith = mix(zenith_night, mix(zenith_day, zenith_dusk, low), day);
    float up = clamp(dir.y, 0.0, 1.0);
    vec3 sky_colour = mix(horizon, zenith, pow(up, 0.55));
    if (dir.y < 0.0) {
        sky_colour = mix(horizon, horizon * 0.6, clamp(-dir.y * 4.0, 0.0, 1.0));
    }
    float cos_angle = dot(dir, sun);
    float glow = pow(max(cos_angle, 0.0), 4.0) * 0.16 + pow(max(cos_angle, 0.0), 40.0) * 0.5;
    sky_colour = sky_colour + sun_colour * glow * (0.3 + 0.7 * day) * (1.0 + low * 1.6);
    return sky_colour;
}

float ae3d_shaders_skydome_shown_channel(float x) {
    float t = clamp(x * (2.51 * x + 0.03) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
    return t <= 0.0031308 ? t * 12.92 : 1.055 * pow(t, 1.0 / 2.4) - 0.055;
}

vec3 ae3d_shaders_skydome_shown_of(vec3 c) {
    return vec3(ae3d_shaders_skydome_shown_channel(c.x), ae3d_shaders_skydome_shown_channel(c.y), ae3d_shaders_skydome_shown_channel(c.z));
}

float ae3d_shaders_skydome_perez(float cos_theta, float gamma, float a, float b, float c, float d, float e) {
    return (1.0 + a * exp(b / max(cos_theta, 0.01))) * (1.0 + c * exp(d * gamma) + e * cos(gamma) * cos(gamma));
}

vec3 ae3d_shaders_skydome_daylight(vec3 dir_in, vec3 sun, float turbidity) {
    vec3 dir = dir_in;
    float tt = turbidity;
    float theta_s = acos(clamp(sun.y, 0.0, 1.0));
    float below = 1.0;
    if (dir.y < 0.0) {
        below = mix(1.0, 0.6, clamp(-dir.y * 4.0, 0.0, 1.0));
        dir = normalize(vec3(dir.x, 0.0, dir.z));
    }
    float cos_theta = dir.y;
    float gamma = acos(clamp(dot(dir, sun), -1.0, 1.0));
    float chi = (4.0 / 9.0 - tt / 120.0) * (3.14159265 - 2.0 * theta_s);
    float yz_lum = ((4.0453 * tt - 4.9710) * tan(chi) - 0.2155 * tt + 2.4192) * 1000.0;
    float t1 = theta_s;
    float t2 = theta_s * theta_s;
    float t3 = t2 * theta_s;
    float xz_c = tt * tt * (0.00166 * t3 - 0.00375 * t2 + 0.00209 * t1) + tt * (-0.02903 * t3 + 0.06377 * t2 - 0.03202 * t1 + 0.00394) + (0.11693 * t3 - 0.21196 * t2 + 0.06052 * t1 + 0.25886);
    float yz_c = tt * tt * (0.00275 * t3 - 0.00610 * t2 + 0.00317 * t1) + tt * (-0.04214 * t3 + 0.08970 * t2 - 0.04153 * t1 + 0.00516) + (0.15346 * t3 - 0.26756 * t2 + 0.06670 * t1 + 0.26688);
    float lum = yz_lum * ae3d_shaders_skydome_perez(cos_theta, gamma, 0.1787 * tt - 1.4630, -0.3554 * tt + 0.4275, -0.0227 * tt + 5.3251, 0.1206 * tt - 2.5771, -0.0670 * tt + 0.3703) / ae3d_shaders_skydome_perez(1.0, theta_s, 0.1787 * tt - 1.4630, -0.3554 * tt + 0.4275, -0.0227 * tt + 5.3251, 0.1206 * tt - 2.5771, -0.0670 * tt + 0.3703);
    float cx = xz_c * ae3d_shaders_skydome_perez(cos_theta, gamma, -0.0193 * tt - 0.2592, -0.0665 * tt + 0.0008, -0.0004 * tt + 0.2125, -0.0641 * tt - 0.8989, -0.0033 * tt + 0.0452) / ae3d_shaders_skydome_perez(1.0, theta_s, -0.0193 * tt - 0.2592, -0.0665 * tt + 0.0008, -0.0004 * tt + 0.2125, -0.0641 * tt - 0.8989, -0.0033 * tt + 0.0452);
    float cy = yz_c * ae3d_shaders_skydome_perez(cos_theta, gamma, -0.0167 * tt - 0.2608, -0.0950 * tt + 0.0092, -0.0079 * tt + 0.2102, -0.0441 * tt - 1.6537, -0.0109 * tt + 0.0529) / ae3d_shaders_skydome_perez(1.0, theta_s, -0.0167 * tt - 0.2608, -0.0950 * tt + 0.0092, -0.0079 * tt + 0.2102, -0.0441 * tt - 1.6537, -0.0109 * tt + 0.0529);
    vec3 xyz_c = vec3(cx / cy * lum, lum, (1.0 - cx - cy) / cy * lum);
    vec3 lin = vec3(3.2406 * xyz_c.x - 1.5372 * xyz_c.y - 0.4986 * xyz_c.z, -0.9689 * xyz_c.x + 1.8758 * xyz_c.y + 0.0415 * xyz_c.z, 0.0557 * xyz_c.x - 0.2040 * xyz_c.y + 1.0570 * xyz_c.z);
    return max(lin, vec3(0.0)) * (2.0e-5 * below);
}

vec3 ae3d_shaders_skydome_procedural_sky(vec3 dir, vec3 sun, vec3 sun_colour, float turbidity, bool discs) {
    vec3 dusk = ae3d_shaders_skydome_dusk_sky(dir, sun, sun_colour);
    float day_share = smoothstep(0.0, 0.25, sun.y);
    vec3 sky_colour = dusk;
    if (day_share > 0.0) {
        sky_colour = mix(dusk, ae3d_shaders_skydome_shown_of(ae3d_shaders_skydome_daylight(dir, sun, turbidity)), day_share);
    }
    if (discs) {
        float cos_angle = dot(dir, sun);
        float day = smoothstep(-0.14, 0.06, sun.y);
        float disc = smoothstep(0.9993, 0.9997, cos_angle);
        sky_colour = sky_colour + sun_colour * disc * (0.6 + 1.4 * day);
    }
    return sky_colour;
}

vec3 ae3d_shaders_skydome_night_sky(vec3 dir, vec3 moon, float night, bool discs) {
    if (night <= 0.0 || dir.y <= 0.0) {
        return vec3(0.0);
    }
    vec3 add = vec3(0.0);
    vec3 cell = floor(dir * 420.0);
    float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    if (h > 0.9935) {
        float bright = (h - 0.9935) / 0.0065;
        vec3 centre = (cell + vec3(0.5)) / 420.0;
        float near = 1.0 - smoothstep(0.0, 1.2 / 420.0, length(dir - centre));
        add = add + vec3(0.85, 0.9, 1.0) * near * (0.25 + 0.75 * bright) * smoothstep(0.0, 0.15, dir.y);
    }
    if (moon.y > 0.0) {
        float c = dot(dir, moon);
        if (discs) {
            add = add + vec3(0.82, 0.86, 0.95) * smoothstep(0.99955, 0.99975, c) * 1.4;
        }
        add = add + vec3(0.30, 0.34, 0.45) * pow(max(c, 0.0), 60.0) * 0.18;
    }
    return add * night;
}

vec3 ae3d_shaders_skydome_sky_at(vec3 dir, sampler2D skybox, int kind, vec3 sky_sun, vec3 cloud_sun, vec3 cloud_sun_colour, float turbidity, vec3 flat_colour, float overcast, vec3 overcast_colour, bool discs) {
    float theta = atan(dir.z, dir.x);
    float phi = asin(dir.y);
    float u = (theta + 3.14159265) / 6.28318531;
    float v = (phi + 1.57079633) / 3.14159265;
    vec3 sky_colour = textureLod(skybox, vec2(u, v), 0.0).rgb;
    if (kind == 1) {
        vec3 hour_sun = normalize(sky_sun);
        sky_colour = ae3d_shaders_skydome_procedural_sky(dir, hour_sun, cloud_sun_colour, turbidity, discs);
        float night = 1.0 - smoothstep(-0.14, -0.02, hour_sun.y);
        sky_colour = sky_colour + ae3d_shaders_skydome_night_sky(dir, normalize(cloud_sun), night, discs);
    }
    if (kind == 2) {
        sky_colour = flat_colour;
    }
    if (overcast > 0.0) {
        vec3 broad = sky_colour;
        if (kind != 1) {
            broad = textureLod(skybox, vec2(u, v), 4.0).rgb;
        }
        float luma = dot(broad, vec3(0.299, 0.587, 0.114));
        sky_colour = mix(sky_colour, overcast_colour * (0.35 + 0.65 * luma), clamp(overcast, 0.0, 1.0));
    }
    return sky_colour;
}

float ae3d_shaders_skydome_aces_inverse(float y_in) {
    float y = clamp(y_in, 0.0, 0.9999);
    float a = 2.51 - 2.43 * y;
    float b = 0.03 - 0.59 * y;
    return (-b + sqrt(b * b + 4.0 * a * 0.14 * y)) / (2.0 * a);
}

float ae3d_shaders_skydome_srgb_decode(float c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

vec3 ae3d_shaders_skydome_display_radiance(vec3 shown) {
    vec3 c = clamp(shown, vec3(0.0), vec3(1.0));
    return vec3(ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.x)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.y)), ae3d_shaders_skydome_aces_inverse(ae3d_shaders_skydome_srgb_decode(c.z)));
}

float ae3d_shaders_skydome_cloud_phase(float cos_angle, float g) {
    float gg = g * g;
    return (1.0 - gg) / (4.0 * 3.14159265 * pow(1.0 + gg - 2.0 * g * cos_angle, 1.5));
}

vec2 ae3d_shaders_skydome_cloud_weather_uv(vec2 p, float t) {
    return p / 24000.0 + vec2(t * 0.00012, t * 0.00004);
}

float ae3d_shaders_skydome_cloud_coverage_from(vec2 weather, float cover) {
    float threshold = 1.0 - cover * (0.45 + 1.1 * weather.y);
    return smoothstep(threshold, threshold + 0.5, weather.x) * 0.9;
}

float ae3d_shaders_skydome_remap(float v, float lo, float hi, float new_lo, float new_hi) {
    return new_lo + (clamp(v, lo, hi) - lo) / max(hi - lo, 0.00001) * (new_hi - new_lo);
}

CloudSample ae3d_shaders_skydome_cloud_density(vec3 p, float cover, float t, bool detailed, sampler2D cloud_weather, sampler3D cloud_shape, sampler3D cloud_detail) {
    vec3 weather = texture(cloud_weather, ae3d_shaders_skydome_cloud_weather_uv(p.xz, t)).rgb;
    float cov = ae3d_shaders_skydome_cloud_coverage_from(vec2(weather.x, weather.z), cover);
    float height = clamp((p.y - 1400.0) / (2600.0 - 1400.0), 0.0, 1.0);
    if (cov <= 0.0) {
        return CloudSample(0.0, height);
    }
    float kind = smoothstep(0.25, 0.75, weather.y);
    float top = mix(0.30, 1.0, kind) * (0.75 + 0.25 * cov);
    float profile = smoothstep(0.0, 0.04, height) * (1.0 - smoothstep(top * 0.4, top, height));
    if (profile <= 0.0) {
        return CloudSample(0.0, height);
    }
    vec3 sp = p * (1.0 / 1500.0) + vec3(t * 0.004, 0.0, t * 0.0015);
    vec4 shape = texture(cloud_shape, sp);
    float fbm = shape.y * 0.625 + shape.z * 0.25 + shape.w * 0.125;
    float base = ae3d_shaders_skydome_remap(shape.x, fbm - 1.0, 1.0, 0.0, 1.0) * profile;
    float d = ae3d_shaders_skydome_remap(base, 1.0 - cov, 1.0, 0.0, 1.0) * cov;
    if (d <= 0.0) {
        return CloudSample(0.0, height);
    }
    vec4 fine = texture(cloud_shape, sp * 6.0 + vec3(0.37, 0.21, 0.63) + vec3(t * 0.01, 0.0, 0.0));
    float puffs = fine.y * 0.625 + fine.z * 0.25 + fine.w * 0.125;
    float detail = puffs;
    if (detailed) {
        vec3 dp = p * (1.0 / 240.0) + vec3(t * 0.012, 0.0, t * 0.005);
        vec3 curl = texture(cloud_detail, dp * 0.25).rgb * 2.0 - vec3(1.0);
        dp = dp + curl * (0.25 * (1.0 - height));
        detail = mix(puffs, texture(cloud_detail, dp).w, 0.6);
    }
    float erosion = mix(detail, 1.0 - detail, clamp(height * 6.0, 0.0, 1.0));
    d = ae3d_shaders_skydome_remap(d, erosion * 0.45, 1.0, 0.0, 1.0);
    return CloudSample(clamp(d, 0.0, 1.0), height);
}

float ae3d_shaders_skydome_cloud_sun_shade(vec3 p, vec3 sun, float cover, float t, sampler2D cloud_weather, sampler3D cloud_shape, sampler3D cloud_detail) {
    float shade = 0.0;
    float stride = (2600.0 - 1400.0) * 0.02;
    vec3 at = p;
    for (int k = 0; k < 6; k += 1) {
        at = at + sun * stride;
        shade = shade + ae3d_shaders_skydome_cloud_density(at, cover, t, k < 2, cloud_weather, cloud_shape, cloud_detail).density * stride;
        stride = stride * 1.6;
    }
    return shade;
}

vec4 ae3d_shaders_skydome_clouds_along(vec3 dir, vec3 sky_colour, float cover, float t, float dither, float near_steps, float far_steps, vec3 eye, vec3 cloud_sun, vec3 cloud_sun_colour, sampler2D cloud_weather, sampler3D cloud_shape, sampler3D cloud_detail) {
    if (cover <= 0.0 || dir.y <= 0.03) {
        return vec4(0.0);
    }
    float t0 = 1400.0 / dir.y;
    float t1 = min(2600.0 / dir.y, t0 + 12000.0);
    float slant = 1.0 - clamp(dir.y, 0.0, 1.0);
    float fine = (t1 - t0) / (near_steps + far_steps * slant * slant);
    float coarse = fine * 3.0;
    vec3 sun = normalize(cloud_sun);
    vec3 sun_light = cloud_sun_colour * (0.9 / 3.14159265);
    vec3 sky_radiance = ae3d_shaders_skydome_display_radiance(sky_colour);
    float sky_shown = dot(sky_colour, vec3(0.299, 0.587, 0.114));
    float sky_bright = dot(sky_radiance, vec3(0.299, 0.587, 0.114));
    vec3 sky_light = mix(sky_radiance, vec3(sky_bright * 1.6), 0.35 * clamp(sky_shown * 2.5, 0.0, 1.0));
    float cos_angle = dot(dir, sun);
    float phase0 = mix(ae3d_shaders_skydome_cloud_phase(cos_angle, 0.5), ae3d_shaders_skydome_cloud_phase(cos_angle, -0.25), 0.30) * 12.566;
    float phase1 = mix(ae3d_shaders_skydome_cloud_phase(cos_angle, 0.25), ae3d_shaders_skydome_cloud_phase(cos_angle, -0.125), 0.30) * 12.566;
    float phase2 = mix(ae3d_shaders_skydome_cloud_phase(cos_angle, 0.125), ae3d_shaders_skydome_cloud_phase(cos_angle, -0.0625), 0.30) * 12.566;
    vec3 colour = vec3(0.0);
    float alpha = 0.0;
    float ray = t0 + fine * dither;
    float dt = coarse;
    int empties = 0;
    for (int i = 0; i < 160; i += 1) {
        if (ray > t1) {
            break;
        }
        vec3 p = vec3(eye.x, 0.0, eye.z) + dir * ray;
        CloudSample s = ae3d_shaders_skydome_cloud_density(p, cover, t, true, cloud_weather, cloud_shape, cloud_detail);
        float d = s.density;
        if (d > 0.002) {
            if (dt > fine) {
                ray = ray - (dt - fine);
                dt = fine;
                empties = 0;
                continue;
            }
            empties = 0;
            float shade = ae3d_shaders_skydome_cloud_sun_shade(p, sun, cover, t, cloud_weather, cloud_shape, cloud_detail);
            float tau = shade * 0.12;
            float scattered = exp(-tau) * phase0 + 0.5 * exp(-tau * 0.25) * phase1 + 0.25 * exp(-tau * 0.0625) * phase2;
            float powder = 1.0 - 0.5 * exp(-d * 12.0);
            vec3 ambient = sky_light * mix(0.62, 1.0, s.height) * (0.7 + 0.3 * exp(-tau * 0.25));
            vec3 c = sun_light * scattered * powder + ambient;
            float haze = 1.0 - exp(-ray * 0.00005);
            c = mix(c, sky_radiance, haze);
            float a = (1.0 - exp(-d * dt * 0.12)) * (1.0 - 0.8 * haze);
            colour = colour + c * a * (1.0 - alpha);
            alpha = alpha + a * (1.0 - alpha);
            if (alpha > 0.98) {
                break;
            }
        } else {
            empties = empties + 1;
            if (empties > 3) {
                dt = coarse;
            }
        }
        ray = ray + dt;
    }
    float horizon = smoothstep(0.04, 0.32, dir.y);
    return vec4(colour * horizon, alpha * horizon);
}

float ae3d_shaders_skydome_cloud_dither(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

out vec4 FragColor;

void main() {
    vec3 dir = ae3d_shaders_skydome_texel_direction(gl_FragCoord.xy / 256.0, 256.0);
    vec3 sky_colour = ae3d_shaders_skydome_sky_at(dir, skybox, kind, sky_sun, cloud_sun, cloud_sun_colour, turbidity, flat_colour, overcast, overcast_colour, false);
    vec4 clouds = ae3d_shaders_skydome_clouds_along(dir, sky_colour, cloud_cover, cloud_time, ae3d_shaders_skydome_cloud_dither(gl_FragCoord.xy), 32.0, 64.0, eye, cloud_sun, cloud_sun_colour, cloud_weather, cloud_shape, cloud_detail);
    FragColor = vec4(ae3d_shaders_skydome_display_radiance(sky_colour) * (1.0 - clouds.w) + clouds.rgb, 1.0);
}
