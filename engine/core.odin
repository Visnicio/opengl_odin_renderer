package engine

import "core:math/linalg"

Mat4 :: linalg.Matrix4f32
Vec3 :: linalg.Vector3f32
Vec2 :: linalg.Vector2f32

Camera :: struct {
    position: Vec3, // where the camera iss
    direction: Vec3, // direciton is usually actually the opposite direction to where we are looking at necause the camera points to -z
   //in learnopengl you see that the target is the origin (vector 0,0,0) and the direction turns ou to point back to the camera

    target: Vec3, // where we wanna look at

    // pointing directions
    right: Vec3, // positive x of the camera space, to get it we first define the up vector in world space and cross it with the target, cross vector generates another vector perpendicular to those
    up: Vec3,
    forward: Vec3, // usually -Z, like godot

    // matrices
    view_mat: Mat4,
    projection_mat: Mat4,
    model: Mat4,

    pitch: f32, // cima baixo
    yaw: f32 // esquerda direta
}

camera_create_perspective :: proc(world_up: Vec3) -> ^Camera {
    new_cam: ^Camera = new(Camera)

    new_cam.position = {0, 0, 3}
    new_cam.target  = {0,0,0}
    new_cam.direction = linalg.normalize(new_cam.position - new_cam.target)
    new_cam.right  = linalg.normalize(linalg.cross(world_up, new_cam.direction))
    new_cam.up = linalg.cross(new_cam.direction, new_cam.right)
    new_cam.forward = {0,0,-1}

    return new_cam
}