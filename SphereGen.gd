tool
extends Spatial


# Documentation at:
# http://blog.andreaskahler.com/2009/06/creating-icosphere-mesh-in-code.html
# https://en.wikipedia.org/wiki/Icosahedron


export var w: float = 10.0 setget set_w  # Icosahedron Internal Rect Width
export var h: float = 15.0 setget set_h  # Icosahedron Internal Rect Height


var mesh_instance: MeshInstance
var mesh_shape: CollisionShape


var material: Material = preload("res://SphereMaterial.tres")


func _ready() -> void:
    icosahedron_vertex()
    pass


func set_w(new_w: float) -> void:
    w = new_w
    icosahedron_vertex()


func set_h(new_h: float) -> void:
    h = new_h
    icosahedron_vertex()


func icosahedron_vertex() -> void:
    mesh_instance = $StaticBody/MeshInstance
    if not mesh_instance:
        return
    mesh_shape = $StaticBody/CollisionShape

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

    var verts = PoolVector3Array([
        #side 1

        x[0], x[1], x[4],
        x[1], x[0], x[7],

        x[0], x[4], x[9],
        x[1], x[8], x[4],

        x[1], x[7], x[11],
        x[0], x[10], x[7],

        x[0], x[9], x[10],
        x[8], x[1], x[11],

        # top

        x[4], x[5], x[9],
        x[8], x[5], x[4],

        # bottom

        x[7], x[10], x[6],
        x[11], x[7], x[6],

        #side 2

        x[3], x[5], x[2],
        x[3], x[2], x[6],

        x[9], x[5], x[3],
        x[5], x[8], x[2],

        x[2], x[11], x[6],
        x[3], x[6], x[10],

        x[9], x[3], x[10],
        x[2], x[8], x[11],
    ])

    var array = []
    array.resize(Mesh.ARRAY_MAX)
    array[Mesh.ARRAY_VERTEX] = verts
    array[Mesh.ARRAY_NORMAL] = verts

    var array_mesh: ArrayMesh = ArrayMesh.new()

    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)

    array_mesh.surface_set_material(0, material)

    mesh_instance.mesh = array_mesh

    mesh_shape.shape = array_mesh.create_trimesh_shape()
