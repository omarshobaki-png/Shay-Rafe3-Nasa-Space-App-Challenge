"""Shared Blender helpers for 3D-to-pixel renders (run inside Blender).

Two passes per frame, both with the Workbench engine and no anti-aliasing:
  ID pass      flat material colors -> which part each pixel belongs to
  normal pass  a matcap that encodes the view-space normal as RGB
A separate Python step (tools/art/compose3d.py) turns them into palette
pixel art with toon lighting and outlines.
"""
import math
import os

import bpy



def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = True
    scene.render.dither_intensity = 0.0
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.display.render_aa = "OFF"
    sh = scene.display.shading
    sh.show_cavity = False
    sh.show_shadows = False
    sh.show_object_outline = False
    sh.show_specular_highlight = False
    sh.show_backface_culling = False
    return scene


def normal_matcap():
    """Blender's built-in matcap that encodes the view-space normal as RGB
    (color = normal * 0.5 + 0.5), so lighting can be computed afterwards."""
    return "check_normal+y.exr"


def ortho_camera(center_x, center_z, ortho_scale, res_x, res_y):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (center_x, -20.0, center_z)
    cam.rotation_euler = (math.radians(90), 0, 0)  # look along +Y; X right, Z up
    scene.camera = cam
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    return cam


def material(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0)
    return m


def render_passes(path_prefix, matcap):
    """Renders <prefix>_id.png and <prefix>_n.png for the current pose."""
    scene = bpy.context.scene
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "MATERIAL"
    scene.render.filepath = path_prefix + "_id.png"
    bpy.ops.render.render(write_still=True)
    sh.light = "MATCAP"
    sh.studio_light = matcap
    sh.color_type = "SINGLE"
    sh.single_color = (1.0, 1.0, 1.0)
    scene.render.filepath = path_prefix + "_n.png"
    bpy.ops.render.render(write_still=True)
