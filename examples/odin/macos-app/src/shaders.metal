#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float2 position;
    float4 color;
};

struct Uniforms {
    float phase;
    float aspect_ratio;
};

struct RasterizerData {
    float4 position [[position]];
    float4 color;
};

vertex RasterizerData vertex_main(uint vertex_id [[vertex_id]],
                                  constant Vertex *vertices [[buffer(0)]],
                                  constant Uniforms &uniforms [[buffer(1)]]) {
    Vertex v = vertices[vertex_id];

    float angle = uniforms.phase * 0.9;
    float c = cos(angle);
    float s = sin(angle);
    float2 rotated = float2(
        v.position.x * c - v.position.y * s,
        v.position.x * s + v.position.y * c
    );

    float wobble = 0.08 * sin(uniforms.phase + float(vertex_id) * 1.4);
    rotated.x = rotated.x / max(uniforms.aspect_ratio, 0.001) + wobble;

    RasterizerData out;
    out.position = float4(rotated, 0.0, 1.0);
    out.color = v.color;
    return out;
}

fragment float4 fragment_main(RasterizerData in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    float pulse = 0.12 * (0.5 + 0.5 * sin(uniforms.phase * 1.7));
    return float4(saturate(in.color.rgb + float3(pulse, pulse, pulse)), 1.0);
}
