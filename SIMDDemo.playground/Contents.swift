import Cocoa

// ----------
// Basic SIMD

// Create things
let a = SIMD4<Float>(x: 1.0, y: 2.0, z: 3.0, w: 4.0)
let b = SIMD4<Float>(x: 2.0, y: 3.0, z: 4.0, w: 5.0)

// Simple operations with other vectors or scalars
let c = a + b

let d = a * 2

// Per-lane booleans
let greater = b .>= d
let allGreater = all(greater)
let anyGreater = any(greater)

let replaced = b.replacing(with: SIMD4<Float>.zero, where: greater)

// Do a complex computation and note how explicit SIMD isn't even faster here
let numbers = (0 ..< (1 << 10)).map { _ in Float.random(in: 0 ..< 100.0 )}

let start1 = Date.timeIntervalSinceReferenceDate
let slowResult = numbers.map { $0 < 50.0 ? $0 + 2 : $0 }
print("Time scalar: \(Date.timeIntervalSinceReferenceDate - start1)")

let start2 = Date.timeIntervalSinceReferenceDate
var fastResult = Array(repeating: Float(0.0), count: numbers.count)
fastResult.withUnsafeMutableBytes { output in
    numbers.withUnsafeBytes { input in
        let outputVec = output.bindMemory(to: SIMD4<Float>.self)
        let inputVec = input.bindMemory(to: SIMD4<Float>.self)
        
        for i in 0 ..< (numbers.count/4) {
            let inputVector = inputVec[i];
            
            outputVec[i] = inputVector.replacing(with: inputVector + 2, where: inputVector .< 50.0)
        }
        let outputFloat = output.bindMemory(to: Float.self)
        let inputFloat = output.bindMemory(to: Float.self)
        let alignedCount = (numbers.count / 4) * 4
        for i in alignedCount ..< numbers.count {
            outputFloat[i] = inputFloat[i] < 50.0 ? inputFloat[i] + 2 : inputFloat[i]
        }
    }
}
print("Time vector: \(Date.timeIntervalSinceReferenceDate - start2)")
for i in 0 ..< numbers.count {
    if (slowResult[i] != fastResult[i]) {
        print("Mismatch \(i): \(slowResult[i]) != \(fastResult[i])")
        break
    }
}

// --------------
// simd framework
import simd

// Normalize, cross
let eye = simd_make_float3(10.0, 10.0, 10.0)
let center = simd_make_float3(-5, 9.0, 23.0)
let direction = simd_normalize(center - eye)
let right = simd_cross(direction, SIMD3<Float>(x: 0.0, y: 1.0, z: 0.0))

// Matrix
let angle = Float(30.0) * Float.pi / Float(180.0)
let rotation = simd_matrix(simd_float2(x: cos(angle), y: sin(angle)), simd_float2(x: -sin(angle), y: cos(angle)))
let original = SIMD2<Float>(x: 1.0, y: 0.0)
let rotated = rotation * original

// ------
// vForce
import Accelerate
let length = 4096
var x: [Float] = (0 ..< length).map { i in Float(i) * 2 * Float.pi / Float(length) }

// Classic mode
var y = [Float](repeating: 0, count: x.count)
var n = Int32(x.count)
vvcosf(&y, &x, &n)
print(y[2048])

// Simple mode
var y2 = vForce.cos(x)
print(y[2048])

// ------
// vImage
var buffer = try! vImage_Buffer(width: 64, height: 64, bitsPerPixel: 32)
var pixelData = buffer.data.bindMemory(to: UInt32.self, capacity: 64*64)
for y in 0 ..< 64 {
    for x in 0 ..< 64 {
        pixelData[x + y*64] = UInt32((x*4) << 24 | (y*4) << 16 | 0xFF);
    }
}

var outputBuffer = try! vImage_Buffer(width: 64, height: 64, bitsPerPixel: 32)
vImageHorizontalReflect_ARGB8888(&buffer, &outputBuffer, vImage_Flags(kvImageNoFlags))

var reflection = outputBuffer.data.bindMemory(to: UInt32.self, capacity: 64*64)
print(pixelData[0], pixelData[1])
print(reflection[62], reflection[63])
