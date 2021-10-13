tool
extends Spatial


# Documentation at:
# http://blog.andreaskahler.com/2009/06/creating-icosphere-mesh-in-code.html
# https://en.wikipedia.org/wiki/Icosahedron


export var radius: float = 10.0 setget set_radius
export var refine_recursion: int = 1 setget set_refine_recursion
export(float, 0, 999999, 1) var noise_modifier: float = 3 setget set_noise_modifier


var static_body: StaticBody
var mesh_instance: MeshInstance
var mesh_shape: CollisionShape


var noise: OpenSimplexNoise

var material: Material = preload("res://SphereMaterial.tres")


func _ready() -> void:
    build_sphere()
    pass


func _process(delta: float) -> void:
    $StaticBody.rotation_degrees += Vector3(1, 1, 1) * 30 * delta


func set_radius(_radius: float) -> void:
    radius = max(_radius, 1)
    build_sphere()


func set_refine_recursion(_refine_recursion: int) -> void:
    refine_recursion = max(min(_refine_recursion, 5), 0)
    build_sphere()


func set_noise_modifier(_noise_modifier: float) -> void:
    noise_modifier = max(_noise_modifier, 0)
    build_sphere()


func get_noise_value(vertex: Vector3) -> float:
    var value = noise.get_noise_3d(vertex.x, vertex.y, vertex.z)
    return value * noise_modifier


func normalize_vertex(vertex: Vector3) -> Vector3:
    # we normalize the vertices of the triangles so they lie on the sphere that surrounds the icosahedron
    var length: float = sqrt(vertex.x * vertex.x + vertex.y * vertex.y + vertex.z * vertex.z)
    var vertex_radius = radius + get_noise_value(vertex)
    var new_vertex = (vertex / length) * vertex_radius
    return new_vertex


func add_triangle(p1: Vector3, p2: Vector3, p3: Vector3, depth: int = 0) -> Array:
    # split triangles until we reach the specified depth
    if depth == max(refine_recursion, 0):
        return [normalize_vertex(p1), normalize_vertex(p2), normalize_vertex(p3)]

    # to split the triangle we find the middle points between each vertex
    var m1_2 = (p1 + p2) / 2
    var m2_3 = (p2 + p3) / 2
    var m3_1 = (p3 + p1) / 2

    # we then create 4 inner triangles that will build the outer most triangle
    var triangles = (
        add_triangle(p1, m1_2, m3_1, depth + 1) +
        add_triangle(p2, m2_3, m1_2, depth + 1) +
        add_triangle(p3, m3_1, m2_3, depth + 1) +
        add_triangle(m1_2, m2_3, m3_1, depth + 1)
    )

    return triangles


func build_sphere() -> void:
    mesh_instance = $StaticBody/MeshInstance
    if not mesh_instance:
        return
    mesh_shape = $StaticBody/CollisionShape

    # we initialize the noise for the terrain
    randomize()
    noise = OpenSimplexNoise.new()
    noise.seed = randi()
    noise.octaves = 1
    noise.persistence = .5
    noise.period = 1

    var w = 1
    var h = (1.0 + sqrt(5.0)) / 2.0

    # Icosahedron internal rectangles
    var x = PoolVector3Array([
        Vector3(w, 0, h),
        Vector3(-w, 0, h),
        Vector3(-w, 0, -h),
        Vector3(w, 0, -h),

        Vector3(0, h, w),
        Vector3(0, h, -w),
        Vector3(0, -h, -w),
        Vector3(0, -h, w),

        Vector3(-h, w, 0),
        Vector3(h, w, 0),
        Vector3(h, -w, 0),
        Vector3(-h, -w, 0),
    ])

    var verts = PoolVector3Array([])

    # side 1

    verts.append_array(add_triangle(x[0], x[1], x[4]))
    verts.append_array(add_triangle(x[1], x[0], x[7]))

    verts.append_array(add_triangle(x[0], x[4], x[9]))
    verts.append_array(add_triangle(x[1], x[8], x[4]))

    verts.append_array(add_triangle(x[1], x[7], x[11]))
    verts.append_array(add_triangle(x[0], x[10], x[7]))

    verts.append_array(add_triangle(x[0], x[9], x[10]))
    verts.append_array(add_triangle(x[8], x[1], x[11]))

    # top

    verts.append_array(add_triangle(x[4], x[5], x[9]))
    verts.append_array(add_triangle(x[8], x[5], x[4]))

    # bottom

    verts.append_array(add_triangle(x[7], x[10], x[6]))
    verts.append_array(add_triangle(x[11], x[7], x[6]))

    # side 2

    verts.append_array(add_triangle(x[3], x[5], x[2]))
    verts.append_array(add_triangle(x[3], x[2], x[6]))

    verts.append_array(add_triangle(x[9], x[5], x[3]))
    verts.append_array(add_triangle(x[5], x[8], x[2]))

    verts.append_array(add_triangle(x[2], x[11], x[6]))
    verts.append_array(add_triangle(x[3], x[6], x[10]))

    verts.append_array(add_triangle(x[9], x[3], x[10]))
    verts.append_array(add_triangle(x[2], x[8], x[11]))

    var array = []
    array.resize(Mesh.ARRAY_MAX)
    array[Mesh.ARRAY_VERTEX] = verts
    array[Mesh.ARRAY_NORMAL] = verts

    var array_mesh: ArrayMesh = ArrayMesh.new()

    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)

    array_mesh.surface_set_material(0, material)

    mesh_instance.mesh = array_mesh

    mesh_shape.shape = array_mesh.create_trimesh_shape()
