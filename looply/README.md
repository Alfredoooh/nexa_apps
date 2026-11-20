/* eslint-disable */
// Constellation Shell — Originkit

"use client"

import * as React from "react"
import { useEffect, useRef } from "react"

const MAX_DPR = 2
const R_SPHERE = 2.5
const BASE_N = 200
const BASE_LINK = 1.0954 // sqrt(1.2), the source's link distance at 200 points
const FOCAL = 1.303 // 1 / tan(75deg / 2)

const VERT_SRC = `
precision highp float;

attribute vec3 a_p0;
attribute vec3 a_p1;
attribute vec2 a_corner;   // x: which end (0|1), y: which side (-1|1)

uniform mat3  uRot;
uniform vec2  uRes;
uniform float uDist, uWidth;

varying float v_depth;

void main(){
  float ar = uRes.x / max(uRes.y, 1.0);

  vec3 r0 = uRot * a_p0;
  vec3 r1 = uRot * a_p1;

  float w0 = max(uDist - r0.z, 0.05);
  float w1 = max(uDist - r1.z, 0.05);
  vec4 c0 = vec4((FOCAL_/ar) * r0.x, FOCAL_ * r0.y, 0.0, w0);
  vec4 c1 = vec4((FOCAL_/ar) * r1.x, FOCAL_ * r1.y, 0.0, w1);

  vec2 n0 = c0.xy / c0.w;
  vec2 n1 = c1.xy / c1.w;
  vec2 dir = (n1 - n0) * vec2(ar, 1.0);
  dir = normalize(dir + vec2(1e-6));
  vec2 perp = vec2(-dir.y, dir.x) / vec2(ar, 1.0);

  vec4 sel = mix(c0, c1, a_corner.x);
  // multiplying by w keeps the stroke a constant SCREEN width after the divide
  sel.xy += perp * a_corner.y * uWidth * sel.w;

  v_depth = mix(r0.z, r1.z, a_corner.x) / ${R_SPHERE.toFixed(2)};
  gl_Position = sel;
}
`.replace(/FOCAL_/g, FOCAL.toFixed(4))

const FRAG_SRC = `
precision mediump float;

uniform vec3  uBase, uAccent;
uniform float uFade;

varying float v_depth;

void main(){
  float t = clamp(v_depth * 0.5 + 0.5, 0.0, 1.0);   // -1 far .. +1 near
  vec3 col = mix(uBase, uAccent, t);
  float a = mix(1.0 - uFade, 1.0, t);
  gl_FragColor = vec4(col * a, a);   // premultiplied
}
`

function compile(gl: WebGLRenderingContext, type: number, src: string): WebGLShader | null {
    const sh = gl.createShader(type)
    if (!sh) return null
    gl.shaderSource(sh, src)
    gl.compileShader(sh)
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
        console.error("ConstellationShell shader:", gl.getShaderInfoLog(sh))
        gl.deleteShader(sh)
        return null
    }
    return sh
}

function parseColor(input: string | undefined, fb: [number, number, number]): [number, number, number] {
    if (!input) return fb
    const str = String(input).trim()
    if (str.charAt(0) === "#") {
        let hex = str.slice(1)
        if (hex.length === 3 || hex.length === 4) {
            hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
        }
        if (hex.length >= 6) {
            const r = parseInt(hex.slice(0, 2), 16)
            const g = parseInt(hex.slice(2, 4), 16)
            const b = parseInt(hex.slice(4, 6), 16)
            if (!isNaN(r) && !isNaN(g) && !isNaN(b)) return [r / 255, g / 255, b / 255]
        }
        return fb
    }
    const m = str.match(/[\d.]+/g)
    if (m && m.length >= 3) {
        return [
            Math.min(255, parseFloat(m[0])) / 255,
            Math.min(255, parseFloat(m[1])) / 255,
            Math.min(255, parseFloat(m[2])) / 255,
        ]
    }
    return fb
}

function num(v: unknown, fb: number): number {
    return typeof v === "number" && isFinite(v) ? v : fb
}

function clampN(v: number, lo: number, hi: number): number {
    return v < lo ? lo : v > hi ? hi : v
}

function rng(seed: number): () => number {
    let a = seed >>> 0
    return function () {
        a += 0x6d2b79f5
        let t = a
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

const CORNERS = [
    [0, -1], [1, -1], [1, 1],
    [0, -1], [1, 1], [0, 1],
]

/**
 * Uniform sphere scatter + neighbour sweep. O(n^2), so it runs only when Density
 * changes. The link radius scales as 1/sqrt(n) to hold average degree constant.
 */
function net(n: number, linkScale: number): { p0: Float32Array; p1: Float32Array; corner: Float32Array; edges: number } {
    const R = rng(1337)
    const px = new Float32Array(n * 3)
    for (let i = 0; i < n; i++) {
        const theta = R() * Math.PI * 2
        const phi = Math.acos(R() * 2 - 1) // uniform on the sphere, not on phi
        const s = Math.sin(phi)
        px[i * 3] = R_SPHERE * s * Math.cos(theta)
        px[i * 3 + 1] = R_SPHERE * s * Math.sin(theta)
        px[i * 3 + 2] = R_SPHERE * Math.cos(phi)
    }
    const link = BASE_LINK * Math.sqrt(BASE_N / n) * linkScale
    const l2 = link * link
    const ea: number[] = []
    const eb: number[] = []
    for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
            const dx = px[i * 3] - px[j * 3]
            const dy = px[i * 3 + 1] - px[j * 3 + 1]
            const dz = px[i * 3 + 2] - px[j * 3 + 2]
            if (dx * dx + dy * dy + dz * dz < l2) {
                ea.push(i)
                eb.push(j)
            }
        }
    }
    const edges = ea.length
    const p0 = new Float32Array(edges * 6 * 3)
    const p1 = new Float32Array(edges * 6 * 3)
    const corner = new Float32Array(edges * 6 * 2)
    for (let e = 0; e < edges; e++) {
        const i = ea[e], j = eb[e]
        for (let c = 0; c < 6; c++) {
            const k = e * 6 + c
            p0[k * 3] = px[i * 3]; p0[k * 3 + 1] = px[i * 3 + 1]; p0[k * 3 + 2] = px[i * 3 + 2]
            p1[k * 3] = px[j * 3]; p1[k * 3 + 1] = px[j * 3 + 1]; p1[k * 3 + 2] = px[j * 3 + 2]
            corner[k * 2] = CORNERS[c][0]
            corner[k * 2 + 1] = CORNERS[c][1]
        }
    }
    return { p0, p1, corner, edges }
}

type ShellGroup = { link?: number; lineWidth?: number; fade?: number }
const SHELL_DEFAULTS: Required<ShellGroup> = { link: 100, lineWidth: 100, fade: 55 }

interface ConstellationShellProps {
    style?: React.CSSProperties
    width?: number
    height?: number
    background?: string
    baseColor?: string
    accentColor?: string
    density?: number
    speed?: number
    hover?: number
    distance?: number
    shell?: ShellGroup
}

function __OriginkitBase_ConstellationShell(props: ConstellationShellProps) {
    const {
        style,
        background = "#000000",
        baseColor = "#00F5FF",
        accentColor = "#71FFF7",
        density = 700,
        speed = 50,
        hover = 200,
        distance = 55,
        shell,
        width,
        height,
    } = props

    // A group the designer never opened arrives undefined; spread-merging over a
    // typed literal beats a hand-written ?? chain, where one missed key silently
    // pins a control forever.
    const shell_ = { ...SHELL_DEFAULTS, ...(shell || {}) }

    const canvasRef = useRef<HTMLCanvasElement>(null)
    const ptrRef = useRef({ tx: 0, ty: 0, x: 0, y: 0 })
    const sizeRef = useRef({ w: 0, h: 0 })
    sizeRef.current = { w: num(width, 0), h: num(height, 0) }

    // Every live input is read from a ref inside the loop. Putting any of them in
    // the effect deps would rebuild the GL context on every colour tweak.
    const vRef = useRef<Record<string, number | string>>({})
    vRef.current = {
        base: baseColor,
        accent: accentColor,
        density: Math.round(clampN(num(density, 220), 60, 700)),
        speed: clampN(num(speed, 50), 0, 100) / 50,
        hover: clampN(num(hover, 100), 0, 200) / 100,
        distance: clampN(num(distance, 45), 20, 120) / 10,
        link: clampN(num(shell_.link, 100), 40, 200) / 100,
        lineWidth: (clampN(num(shell_.lineWidth, 100), 20, 400) / 100) * 0.0016,
        fade: clampN(num(shell_.fade, 55), 0, 100) / 100,
    }

    useEffect(() => {
        const canvas = canvasRef.current
        if (!canvas) return
        const gl = canvas.getContext("webgl", {
            alpha: true,
            antialias: true,
            depth: false,
            premultipliedAlpha: true,
        })
        if (!gl) {
            console.error("ConstellationShell: WebGL unavailable")
            return
        }

        const vs = compile(gl, gl.VERTEX_SHADER, VERT_SRC)
        const fs = compile(gl, gl.FRAGMENT_SHADER, FRAG_SRC)
        if (!vs || !fs) return
        const prog = gl.createProgram()
        if (!prog) return
        gl.attachShader(prog, vs)
        gl.attachShader(prog, fs)
        gl.linkProgram(prog)
        if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
            console.error("ConstellationShell link:", gl.getProgramInfoLog(prog))
            return
        }
        gl.useProgram(prog)

        const aP0 = gl.getAttribLocation(prog, "a_p0")
        const aP1 = gl.getAttribLocation(prog, "a_p1")
        const aCorner = gl.getAttribLocation(prog, "a_corner")
        gl.enableVertexAttribArray(aP0)
        gl.enableVertexAttribArray(aP1)
        gl.enableVertexAttribArray(aCorner)

        const locs: Record<string, WebGLUniformLocation | null> = {}
        const u = (name: string) => {
            if (!(name in locs)) locs[name] = gl.getUniformLocation(prog, name)
            return locs[name]
        }

        const b0 = gl.createBuffer()
        const b1 = gl.createBuffer()
        const bc = gl.createBuffer()
        let builtN = 0
        let builtLink = 0
        let verts = 0
        const build = (n: number, linkScale: number) => {
            const g = net(n, linkScale)
            gl.bindBuffer(gl.ARRAY_BUFFER, b0)
            gl.bufferData(gl.ARRAY_BUFFER, g.p0, gl.STATIC_DRAW)
            gl.bindBuffer(gl.ARRAY_BUFFER, b1)
            gl.bufferData(gl.ARRAY_BUFFER, g.p1, gl.STATIC_DRAW)
            gl.bindBuffer(gl.ARRAY_BUFFER, bc)
            gl.bufferData(gl.ARRAY_BUFFER, g.corner, gl.STATIC_DRAW)
            builtN = n
            builtLink = linkScale
            verts = g.edges * 6
        }

        let raf = 0
        let last = performance.now()
        let clock = 0

        const render = (now: number) => {
            const dt = Math.min(0.05, (now - last) / 1000)
            last = now
            const v = vRef.current
            clock = (clock + dt * (v.speed as number)) % 3600

            const dpr = Math.min(window.devicePixelRatio || 1, MAX_DPR)
            const cw = sizeRef.current.w || canvas.clientWidth || 1200
            const ch = sizeRef.current.h || canvas.clientHeight || 800
            const bw = Math.max(1, Math.round(cw * dpr))
            const bh = Math.max(1, Math.round(ch * dpr))
            if (canvas.width !== bw || canvas.height !== bh) {
                canvas.width = bw
                canvas.height = bh
            }
            gl.viewport(0, 0, bw, bh)

            const wantN = v.density as number
            const wantLink = v.link as number
            if (wantN !== builtN || wantLink !== builtLink) build(wantN, wantLink)

            const ptr = ptrRef.current
            const pk = 1 - Math.exp(-dt * 3.5)
            ptr.x += (ptr.tx - ptr.x) * pk
            ptr.y += (ptr.ty - ptr.y) * pk

            // Slow tumble, the source's two rates, plus the pointer's ORBIT: the
            // cursor adds yaw and pitch to the same rotation the tumble drives, so
            // the shell is turned rather than lit — the one gesture a rigid lattice
            // with no per-node state can honestly offer.
            const hv = v.hover as number
            const ay = clock * 0.12 + ptr.x * 2.2 * hv
            const ax = clock * 0.06 - ptr.y * 1.2 * hv
            const cy = Math.cos(ay), sy = Math.sin(ay)
            const cx = Math.cos(ax), sx = Math.sin(ax)
            // Ry * Rx, column-major
            const rot = new Float32Array([
                cy, 0, -sy,
                sy * sx, cx, cy * sx,
                sy * cx, -sx, cy * cx,
            ])

            gl.clearColor(0, 0, 0, 0)
            gl.clear(gl.COLOR_BUFFER_BIT)
            gl.disable(gl.DEPTH_TEST)
            gl.enable(gl.BLEND)
            gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)

            gl.bindBuffer(gl.ARRAY_BUFFER, b0)
            gl.vertexAttribPointer(aP0, 3, gl.FLOAT, false, 0, 0)
            gl.bindBuffer(gl.ARRAY_BUFFER, b1)
            gl.vertexAttribPointer(aP1, 3, gl.FLOAT, false, 0, 0)
            gl.bindBuffer(gl.ARRAY_BUFFER, bc)
            gl.vertexAttribPointer(aCorner, 2, gl.FLOAT, false, 0, 0)

            gl.uniformMatrix3fv(u("uRot"), false, rot)
            gl.uniform2f(u("uRes"), bw, bh)
            gl.uniform1f(u("uDist"), v.distance as number)
            gl.uniform1f(u("uWidth"), v.lineWidth as number)
            gl.uniform1f(u("uFade"), v.fade as number)
            const cb = parseColor(v.base as string, [0.725, 0.741, 0.769])
            const ca = parseColor(v.accent as string, [0.078, 0.086, 0.102])
            gl.uniform3f(u("uBase"), cb[0], cb[1], cb[2])
            gl.uniform3f(u("uAccent"), ca[0], ca[1], ca[2])

            gl.drawArrays(gl.TRIANGLES, 0, verts)
            raf = requestAnimationFrame(render)
        }

        build(vRef.current.density as number, vRef.current.link as number)
        // The rect RATIO is zoom-invariant — offset and size scale together — so
        // this is safe on a zoomed Framer canvas where absolute px are not.
        const track = (e: PointerEvent) => {
            const r = canvas.getBoundingClientRect()
            if (r.width <= 0 || r.height <= 0) return
            ptrRef.current.tx = clampN((e.clientX - r.left) / r.width, 0, 1) - 0.5
            ptrRef.current.ty = clampN((e.clientY - r.top) / r.height, 0, 1) - 0.5
        }
        const onLeave = () => {
            ptrRef.current.tx = 0
            ptrRef.current.ty = 0
        }
        canvas.addEventListener("pointermove", track)
        canvas.addEventListener("pointerenter", track)
        canvas.addEventListener("pointerleave", onLeave)

        raf = requestAnimationFrame(render)

        // Never loseContext(): getContext returns the same context per canvas, so
        // StrictMode's mount -> cleanup -> mount would reuse a force-lost one.
        return () => {
            cancelAnimationFrame(raf)
            canvas.removeEventListener("pointermove", track)
            canvas.removeEventListener("pointerenter", track)
            canvas.removeEventListener("pointerleave", onLeave)
        }
    }, [])

    return (
        <div
            style={{
                position: "relative",
                overflow: "hidden",
                background,
                minWidth: 1200,
                minHeight: 800,
                width: typeof width === "number" && width > 0 ? width : "100%",
                height: typeof height === "number" && height > 0 ? height : "100%",
                ...style,
            }}
        >
            <canvas
                ref={canvasRef}
                style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }}
            />
        </div>
    )
}

const __originkitPresetProps = {
  "shell": {
    "fade": 56,
    "link": 168,
    "lineWidth": 20
  }
};

export default function ConstellationShell(props: Record<string, unknown>) {
  return <__OriginkitBase_ConstellationShell {...(__originkitPresetProps as Record<string, unknown>)} {...props} />;
}
