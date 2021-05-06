Shader "Raymarching/RmInfinity"
{
    Properties
    {
        //_ColorA("Color A", Color) = (1,1,0,1)
        //_ColorB("Color B", Color) = (0,1,0,1)
        _ColorBg("Color Background", Color) = (0,0,0,1)

        _GridSize("GridSize", Range(0.2 , 10)) = 1

        _GridRatio("GridRatio", Vector) = (1,1,1,0)

        _DrawBlockRadius("DrawBlockRadius", float ) = 1

        [Enum(Off,0,On,1)] _RaycastCost("RaycastCost", Float) = 0
        _RaycastStart("Raycast Start", float ) = 0
        [IntRange] _RaycastSteps("Raycast Steps", Range(10 , 150)) = 50
        [IntRange] _RaycastDist("Raycast Distance", Range(10 , 150)) = 50
        [IntRange] _SurfPow("Surf Pow", Range(1,20)) = 1
    }

        SubShader
    {
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull front

        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float4 _ColorBg;
            //float4 _ColorA;
            //float4 _ColorB;

            float _GridSize;
            float4 _GridRatio;

            float _RaycastCost;
            float _DrawBlockRadius;
            float _SurfPow;
            float _RaycastStart;
            float _RaycastSteps;
            float _RaycastDist;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID //Insert
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;

                UNITY_VERTEX_OUTPUT_STEREO //Insert
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v); //Insert
                UNITY_INITIALIZE_OUTPUT(v2f, o); //Insert
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // https://youtu.be/S8AWd66hoCo?t=1229
                o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos , 1));
                o.hitPos = v.vertex;
                return o;
            }

            //float2 opI(float2 d1, float2 d2)
            //{
            //    return max(d1.)
            //}

            float2 opU(float2 d1, float2 d2)
            {
                return (d1.x < d2.x) ? d1 : d2;
            }

            float sdCappedCylinder(float3 p, float h, float r)
            {
                float2 d = abs(float2(length(p.xz), p.y)) - float2(h, r);
                return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
            }

            float sdCylinder(float3 p, float3 c)
            {
                return length(p.xz - c.xy) - c.z;
            }

            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            float sdSphere(float3 p, float s)
            {
                return length(p) - s;
            }

            float AA(float d)
            {
                // https://mortoray.com/2015/06/19/antialiasing-with-a-signed-distance-field/
                return clamp(1 - d , 0 , 1);
            }
            float2 sdtCappedCylinder(float2 value, float3 p, float h, float r, float color)
            {
                float d = sdCappedCylinder(p, h, r);

                return opU(value, float2(d, color));
            }

            float2 sdtCylinder(float2 value, float3 p, float3 c, float color)
            {
                float d = sdCylinder(p, c);

                return opU(value, float2(d, color));
            }

            float2 sdtBox(float2 value, float3 p, float3 b, float color)
            {
                float d = sdBox(p, b);

                return opU(value, float2(d, color));
            }

            float2 sdtSphere(float2 value, float3 p, float s, float color)
            {
                float d = sdSphere(p, s);

                return opU(value, float2(d, color));
            }

            float zigzag(float x) 
            {
                // https://www.desmos.com/calculator/yyxml9e7fa

                return abs(1 - (x % 2)) - 0.5;
            }

            float2 Map(float3 p)
            {
                float2 res = float2(1e10, 0);

                //float clip_d = sdSphere(p, 0.1);

                /*
                float sdPlane(float3 p, float4x4 _globalTransform)
                {
                    float plane = mul(_globalTransform, float4(p, 1)).x;
                    return plane;
                }
                */

                float3 c = normalize(_GridRatio.xyz) * _GridSize;

                res = opU( res , float2( p.y + c.y   , 1 ) );


                float r = length(p) < _DrawBlockRadius  ? 0 : 0.1;

                p += float3( 1e2, 1e2 , 1e2 );
                
                p += float3( 0 , 0 , _Time.y );

                float p1 = p;
                
                p = (p+.5*c) % (c) - 0.5 * c;

                float t1 = sin( _Time.y / 2 );
                
                float t2 = sin(_Time.y * 1.5);

                //float gx = p.x 

                float3 p2 = p + float3( 0 , t2 * sin( round( p1.x / c.x ) * 8 ) / 5  , 0 ) ;

                res = sdtBox(res, p2, 2 * r * t1 , 2.6 );
                res = sdtSphere(res, p2 , r * ( 1 - t1 ) , 6.6);

                // CLIP 
                //res = float2(max(res.x, clip_d * -1), res.y);

                return res;
            }

            float2 raycast(float3 ro, float3 rd)
            {
                float surf_dist = 1.0 / ( 2 << ( (int) _SurfPow ) );

                // start at the camera position and march along the camera array 
                // keep track of the [ dO ] distance from the Origin 
                float dO = _RaycastStart;// 0;

                // keep track of the distance of the scene / surface 
                float dS;

                for (int i = 0; i < _RaycastSteps; i++)
                {
                    // ray marching position 
                    float3 p = ro + dO * rd;

                    float2 res = Map(p);

                    dS = res.x;

                    //// move forward along the ray 
                    dO += dS;

                    //// check if we hit an object ( or reached max / infinity ) 
                    if (dS < surf_dist || dO > _RaycastDist) break;
                }

                // http://adrianb.io/2016/10/01/raymarching.html # Performance Testing
                float performance = ( (float) i ) / ( (float) _RaycastSteps );

                return float2( dO , performance );
            }

            float3 GetNormal(float3 p)
            {
                float2 e = float2(1e-2 , 0);

                float3 n = Map(p).x - float3(
                    Map(p - e.xyy).x,
                    Map(p - e.yxy).x,
                    Map(p - e.yyx).x
                );

                return normalize(n);
            }

            float calcAO(float3 pos, float3 nor)
            {
                float occ = 0.0;
                float sca = 1.0;

                for (int i = 0; i < 5; i++)
                {
                    float h = 0.01 + 0.12 * float(i) / 4.0;
                    float d = Map(pos + h * nor).x;
                    occ += (h - d) * sca;
                    sca *= 0.95;
                    if (occ > 0.35) break;
                }
                return clamp(1.0 - 3.0 * occ, 0.0, 1.0) * (0.5 + 0.5 * nor.y);
            }

            float3 render(float3 ro, float3 rd, float2 res)
            {
                // https://www.shadertoy.com/view/Xds3zN

                float t = res.x;
                float c = res.y;

                float3 col = 0.2 + 0.2 * sin(c * 2.0 + float3(0.0, 1.0, 2.0));

                float3 pos = ro + rd * t;
                float3 nor = GetNormal(pos);

                float ks = 1.0;

                // -------- lighting ---------

                float occ = 1;

                // AO
                //acc = calcAO(pos, nor);

                float3 lin = 0;

                // sun
                {
                    //float3  lig = normalize(float3(-0.5, 0.4, -0.6));
                    float3 lig = normalize(-rd);

                    float3  hal = normalize(lig - rd);
                    float dif = clamp(dot(nor, lig), 0.0, 1.0);
                    //if( dif>0.0001 )
                    //dif *= calcSoftshadow(pos, lig, 0.02, 2.5);
                    float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 16.0);
                    spe *= dif;
                    spe *= 0.04 + 0.96 * pow(clamp(1.0 - dot(hal, lig), 0.0, 1.0), 5.0);
                    lin += col * 2.20 * dif * float3(1.30, 1.00, 0.70);
                    lin += 5.00 * spe * float3(1.30, 1.00, 0.70) * ks;
                }


                // back
                //{
                //    float dif = clamp(dot(nor, normalize(float3(0.5, 0.0, 0.6))), 0.0, 1.0) * clamp(1.0 - pos.y, 0.0, 1.0);
                //    dif *= occ;
                //    lin += col * 0.55 * dif * float3(0.25, 0.25, 0.25);
                //}

                // sss
                {
                    //float dif = pow(clamp(1.0 + dot(nor, rd), 0.0, 1.0), 2.0);
                    //dif *= occ;
                    //lin += col * 0.25 * dif * float3(1.00, 1.00, 1.00);
                }

                col = lerp(lin, _ColorBg , 1.0 - exp(-0.0001 * t * t * t));
                col = clamp(col, 0.0, 1.0);

                return col;
            }

            fixed4 frag(v2f i) : SV_Target {

                float2 uv = i.uv - .5;

                // ray origin / camera 
                float3 ro = i.ro;

                // ray direction 
                float3 rd = normalize(i.hitPos - ro);

                float4 col = 0;

                float2 res1 = raycast(ro, rd);

                float d = res1.x;

                float perf = res1.y;

                if (d >= _RaycastDist && _RaycastCost < 1 )  discard;

                else
                {
                    // // Preview normals : 
                    // float3 p = ro + rd * d;
                    // float3 n = GetNormal(p);
                    // col.rgb = n;

                    float2 res2 = Map(ro + d * rd);

                    float c = res2.y;

                    if (c > -.5)
                    {
                        float3 render_color = render(ro, rd, float2(d, c));

                        if (_RaycastCost > 0)
                        {
                            col = float4(perf, 0, 0, 1);
                        }
                        else
                        {
                            col = float4(render_color, AA(res2.x));
                        }

                    }
                }

                return col;
            }

            ENDCG
        }
    }
}
