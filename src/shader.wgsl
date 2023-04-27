@group(0) @binding(0) var texture0: texture_2d<f32>;
@group(0) @binding(1) var texture1: texture_2d<f32>;
@group(0) @binding(2) var texture2: texture_2d<f32>;
@group(0) @binding(3) var sampler1: sampler;
@group(1) @binding(0) var<uniform> uniforms: Uniforms;

//https://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader
fn random(p: vec2<f32>) -> f32 {
    let K1 = vec2(
        23.14069263277926, // e^pi (Gelfond's constant)
         2.665144142690225 // 2^sqrt(2) (Gelfondâ€“Schneider constant)
    );
    return fract( cos( dot(p,K1) ) * 12345.6789 );
}

struct Uniforms {
    mouse_pos: vec2<f32>,
    level: u32,
    time: f32,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
};

@vertex
fn vs(
    @builtin(vertex_index) in_vertex_index: u32,
) -> VertexOutput {
    var out: VertexOutput;
    let x = f32(1 - i32(in_vertex_index)) * 5.0;
    let y = f32(i32(in_vertex_index & 1u) * 2 - 1) * 2.0;
    out.clip_position = vec4<f32>(x, y, 0.0, 1.0);
    return out;
}

@fragment
fn fs_bloom_select(in: VertexOutput) -> @location(0) vec4<f32> {
    let x = i32(in.clip_position.x);
    let y = i32(in.clip_position.y);

    if x+i32(100.0*sin(0.5 * uniforms.time)*sin(f32(y)/100.0+0.25 * uniforms.time)) >= 512 - 25 && x+i32(100.0*sin(0.5 * uniforms.time)*sin(f32(y)/100.0+0.25 * uniforms.time)) <= 512+25 || y == 50 || y == 1024 - 50 {
        return vec4(10.0, 1.0, 1.0, 1.0);
    }

    return vec4(0.0, 0.0, 0.0, 1.0);
}

fn blur(tex: texture_2d<f32>, pos: vec2f, direction: vec2f, mip: i32) -> vec4f {
    let hstep = direction.x;
    let vstep = direction.y;

    var sum: vec4f;
    sum = textureSampleLevel(tex, sampler1, pos+vec2(-4.0*hstep, -4.0*vstep), f32(mip)) * 0.0162162162;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(-3.0*hstep, -3.0*vstep), f32(mip)) * 0.0540540541;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(-2.0*hstep, -2.0*vstep), f32(mip)) * 0.1216216216;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(-1.0*hstep, -1.0*vstep), f32(mip)) * 0.1945945946;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(0.0*hstep, 0.0*vstep), f32(mip)) * 0.2270270270;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(1.0*hstep, 1.0*vstep), f32(mip)) * 0.1945945946;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(2.0*hstep, 2.0*vstep), f32(mip)) * 0.1216216216;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(3.0*hstep, 3.0*vstep), f32(mip)) * 0.0540540541;
    sum += textureSampleLevel(tex, sampler1, pos+vec2(4.0*hstep, 4.0*vstep), f32(mip)) * 0.0162162162;

    return vec4(sum.rgb, 1.0);
}

@fragment
fn fs_bloom_blur1(in: VertexOutput) -> @location(0) vec4<f32> {
    let size = 1024.0 / pow(2.0, f32(uniforms.level)) * vec2(1.0, 1.0);
    let pos = in.clip_position.xy / size;

    return blur(texture2, pos, vec2(1.0, 0.0)/size, i32(uniforms.level - 1u));
}

@fragment
fn fs_bloom_blur2(in: VertexOutput) -> @location(0) vec4<f32> {
    let size = 1024.0 / pow(2.0, f32(uniforms.level)) * vec2(1.0, 1.0);
    let pos = in.clip_position.xy / size;

    return blur(texture2, pos, vec2(0.0, 1.0)/size, i32(uniforms.level));
    //return textureLoad(texture2, vec2(x, y), i32(uniforms.level));
}

fn powi(base: i32, exp: u32) -> i32 {
    return i32(pow(f32(base), f32(exp)));
}

@fragment
fn fs_bloom_add(in: VertexOutput) -> @location(0) vec4<f32> {
    let size = 1024.0 / pow(2.0, f32(uniforms.level - 1u)) * vec2(1.0, 1.0);
    //let size = vec2f(textureDimensions(texture2).xy);
    let pos = in.clip_position.xy / size;

    var color: vec4f;
    color = textureSampleLevel(texture2, sampler1, pos, f32(uniforms.level - 1u));
    color += textureSampleLevel(texture2, sampler1, pos, f32(uniforms.level));
    //color += blur(texture2, x/2, y/2, vec2(1, 0), i32(uniforms.level));
    //color = vec4(0.0, 0.0, 0.0, 0.0);
    //color += 0.05 * textureLoad(texture2, vec2(x, y), 0);
    //color += textureLoad(texture2, vec2(x, y), i32(uniforms.padding));
    //color += textureSampleLevel(texture2, sampler1, vec2(f32(x), f32(y))/1024.0, f32(uniforms.padding));
    //color += textureLoad(texture2, vec2(x/powi(2, uniforms.level), y/powi(2, uniforms.level)), i32(uniforms.level));

    return vec4(color.rgb, 1.0);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let size = 1024.0 * vec2(1.0, 1.0);
    let pos = in.clip_position.xy / size;

    return vec4(textureSampleLevel(texture2, sampler1, pos, 1.0).rgb, 1.0);
}
