/* SPDX-License-Identifier: GPL-2.0-or-later */
/* ABI-compatible bridge for QEMU builds with CONFIG_OPENGL disabled. */
#include "husk-display-gl.h"

bool husk_display_gl_early(void) { return false; }
bool husk_display_gl_create(void *layer, int width, int height)
{
    (void)layer; (void)width; (void)height;
    return false;
}
bool husk_display_gl_probe(void) { return false; }
bool husk_display_gl_bind(void) { return false; }
uint64_t husk_display_gl_frames(void) { return 0; }
void husk_display_gl_set_metal_presenter(husk_metal_present_fn fn) { (void)fn; }
