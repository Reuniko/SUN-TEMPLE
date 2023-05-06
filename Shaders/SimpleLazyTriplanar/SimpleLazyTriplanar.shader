Shader "Silent/Simple Lazy Triplanar" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[Normal]_BumpMap ("Normal Map", 2D) = "bump" {}
		_NormalScale ("Normal Scale", Range(0,1)) = 1.0
		[Space(25)]
		_Combined ("Combined Map (MOES)", 2D) = "white" {}
		_Metallic ("Metallic Scale", Range(0,1)) = 1.0
		_Occlusion ("Occlusion Scale", Range(0,1)) = 1.0
		[HDR]_EmissionColor ("Emission Colour", Color) = (0, 0, 0, 0)
		_Glossiness ("Smoothness Scale", Range(0,1)) = 1.0
		[Space(25)]
		[Enum(World Space, 0, Object Space, 1)]_TriplanarSpace ("Triplanar Mapping Space", Float) = 0.0
		_tiles0x ("X Axis Tiling", float) = 0.03
		_tiles0y ("Y Axis Tiling", float) = 0.03
		_tiles0z ("X Axis Tiling", float) = 0.03
		_offset0x ("X Axis Offset", float) = 0
		_offset0y ("Y Axis Offset", float) = 0
		_offset0z ("X Axis Offset", float) = 0
		[Space(25)]
		[Toggle(UNITY_UI_ALPHACLIP)] _StochasticSampling("Use Stochastic Sampling", Float) = 0
		[Toggle(_)] _FlipNormalY("Flip Normal Y", Float) = 0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
		#pragma exclude_renderers gles
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard vertex:vert

		#pragma shader_feature _ UNITY_UI_ALPHACLIP

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex; float4 _MainTex_ST;
		sampler2D _BumpMap; float4 _BumpMap_ST;
		//sampler2D _Roughness; float4 _Roughness_ST;
		//sampler2D _Occlusion; float4 _Occlusion_ST;
		sampler2D _Combined; float4 _Combined_ST;

		struct Input {
			float2 uv_MainTex;
            float3 worldNormal; INTERNAL_DATA
            float3 worldPos;
            float3 triplanarPos;
		};

		half _Glossiness;
		half _Metallic;
		half _Occlusion;
		half _NormalScale;
		fixed4 _Color;
		float4 _EmissionColor;

		float _TriplanarSpace;

		float _tiles0x;
		float _tiles0y;
		float _tiles0z;

		float _offset0x;
		float _offset0y;
		float _offset0z;

		float _FlipNormalY;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		//GeometricSpecularAA (Valve Method)
		float GeometricAASpecular(float3 normal, float smoothness){
		    float3 vNormalWsDdx = ddx(normal);
		    float3 vNormalWsDdy = ddy(normal);
		    float flGeometricRoughnessFactor = pow(saturate(max(dot(vNormalWsDdx, vNormalWsDdx), dot(vNormalWsDdy, vNormalWsDdy))), 0.333);
		    return min(smoothness, 1.0 - flGeometricRoughnessFactor);
		}

//hash for randomness
float2 hash2D2D (float2 s)
{
    //magic numbers
    return frac(sin(fmod(float2(dot(s, float2(127.1,311.7)), dot(s, float2(269.5,183.3))), 3.14159))*43758.5453);
}

//stochastic sampling
float4 tex2DStochastic(sampler2D tex, float2 UV)
{
    //triangle vertices and blend weights
    //BW_vx[0...2].xyz = triangle verts
    //BW_vx[3].xy = blend weights
    float4x3 BW_vx;

    //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
    float2 skewUV = mul(float2x2 (1.0 , 0.0 , -0.57735027 , 1.15470054), UV * 3.464);

    //vertex IDs and barycentric coords
    float2 vxID = float2 (floor(skewUV));
    float3 barry = float3 (frac(skewUV), 0);
    barry.z = 1.0-barry.x-barry.y;

    BW_vx = ((barry.z>0) ? 
        float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
        float4x3(float3(vxID + float2 (1, 1), 0), float3(vxID + float2 (1, 0), 0), float3(vxID + float2 (0, 1), 0), float3(-barry.z, 1.0-barry.y, 1.0-barry.x)));

    //calculate derivatives to avoid triangular grid artifacts
    float2 dx = ddx(UV);
    float2 dy = ddy(UV);

    //blend samples with calculated weights
    return  mul(tex2D(tex, UV + hash2D2D(BW_vx[0].xy), dx, dy), BW_vx[3].x) + 
            mul(tex2D(tex, UV + hash2D2D(BW_vx[1].xy), dx, dy), BW_vx[3].y) + 
            mul(tex2D(tex, UV + hash2D2D(BW_vx[2].xy), dx, dy), BW_vx[3].z);
}

float4x3 tex2DStochastic_calc(float2 UV)
{
    //triangle vertices and blend weights
    //BW_vx[0...2].xyz = triangle verts
    //BW_vx[3].xy = blend weights (z is unused)
    float4x3 BW_vx;

    //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
    float2 skewUV = mul(float2x2 (1.0 , 0.0 , -0.57735027 , 1.15470054), UV * 3.464);

    //vertex IDs and barycentric coords
    float2 vxID = float2 (floor(skewUV));
    float3 barry = float3 (frac(skewUV), 0);
    barry.z = 1.0-barry.x-barry.y;

    BW_vx = ((barry.z>0) ? 
        float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
        float4x3(float3(vxID + float2 (1, 1), 0), float3(vxID + float2 (1, 0), 0), float3(vxID + float2 (0, 1), 0), float3(-barry.z, 1.0-barry.y, 1.0-barry.x)));

	return BW_vx;
}

float4 tex2DStochastic_sample(sampler2D tex, float2 UV, float4x3 BW_vx)
{
    //calculate derivatives to avoid triangular grid artifacts
    float2 dx = ddx(UV);
    float2 dy = ddy(UV);

    return  mul(tex2D(tex, UV + hash2D2D(BW_vx[0].xy), dx, dy), BW_vx[3].x) + 
            mul(tex2D(tex, UV + hash2D2D(BW_vx[1].xy), dx, dy), BW_vx[3].y) + 
            mul(tex2D(tex, UV + hash2D2D(BW_vx[2].xy), dx, dy), BW_vx[3].z);
}

#if defined(UNITY_UI_ALPHACLIP)
#define TEXTURE_SAMPLE(a, b) tex2DStochastic_sample(a, b, BW_vx)
#else
#define TEXTURE_SAMPLE tex2D
#endif

void vert (inout appdata_full v, out Input o) {
    UNITY_INITIALIZE_OUTPUT(Input,o);
    float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.triplanarPos = (_TriplanarSpace)
    ? v.vertex
    : worldPos;
}

void surf (Input IN, inout SurfaceOutputStandard o) {
    float3 normal = WorldNormalVector ( IN, float3( 0, 0, 1 ) );

	//const float3 tighten = 0.576;
	const float3 tighten = 0.2;
	float3 absVertexNormal = abs(normalize(normal));
	float3 weights = absVertexNormal - tighten;

	weights *= 3;

	float2 y0 = IN.triplanarPos.zy * _tiles0x + _offset0x;
	float2 x0 = IN.triplanarPos.xz * _tiles0z + _offset0z;
	float2 z0 = IN.triplanarPos.xy * _tiles0y + _offset0y;

	#if defined(UNITY_UI_ALPHACLIP)
	// Only calculate for one dimension, it should be enough.
	float2 w0 = (weights.x * x0) + (weights.y * y0);
	float4x3 BW_vx = tex2DStochastic_calc(w0);
	#endif
	
    weights = max(weights, 0);
    weights /= dot(weights, 1.0);

	float4 mixedDiffuse = 0;
	fixed3 nrm = 0.0f;
	fixed4 combi = 0.0f;
	
	if(weights.x > 0) {
		mixedDiffuse += weights.x * TEXTURE_SAMPLE(_MainTex, y0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
		nrm += weights.x * UnpackScaleNormal(TEXTURE_SAMPLE(_BumpMap, y0 * _BumpMap_ST.xy + _BumpMap_ST.zw), _NormalScale);
		combi += weights.x * TEXTURE_SAMPLE(_Combined, y0 * _Combined_ST.xy + _Combined_ST.zw);
	}
	if(weights.y > 0) {
		mixedDiffuse += weights.y * TEXTURE_SAMPLE(_MainTex, x0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
		nrm += weights.y * UnpackScaleNormal(TEXTURE_SAMPLE(_BumpMap, x0 * _BumpMap_ST.xy + _BumpMap_ST.zw), _NormalScale);
		combi += weights.y * TEXTURE_SAMPLE(_Combined, x0 * _Combined_ST.xy + _Combined_ST.zw);
	}
	if(weights.z > 0) {
		mixedDiffuse += weights.z * TEXTURE_SAMPLE(_MainTex, z0 * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
		nrm += weights.z * UnpackScaleNormal(TEXTURE_SAMPLE(_BumpMap, z0 * _BumpMap_ST.xy + _BumpMap_ST.zw), _NormalScale);
		combi += weights.z * TEXTURE_SAMPLE(_Combined, z0 * _Combined_ST.xy + _Combined_ST.zw);
	}

	nrm.y *= -sign(_FlipNormalY-0.5);

	// Albedo comes from a texture tinted by color
	o.Albedo = mixedDiffuse.xyz;
	o.Normal = normalize(nrm);
	// Metallic and smoothness come from slider variables
	o.Metallic = _Metallic * combi.r;
	o.Smoothness = _Glossiness * combi.a;
	o.Occlusion = LerpOneTo(combi.g, _Occlusion);
	o.Emission = o.Albedo * combi.b * _EmissionColor;
	o.Alpha = mixedDiffuse.a;
}
ENDCG
	}
	Fallback "Standard"
}
