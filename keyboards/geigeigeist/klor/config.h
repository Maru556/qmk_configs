// Copyright 2024 QMK
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

// Use either side of the split as the master
#define MASTER_LEFT
#define MASTER_RIGHT
#define EE_HANDS

#ifdef OLED_ENABLE
#    define OLED_DISPLAY_128X64
#    define OLED_FONT_H "keyboards/geigeigeist/klor/glcdfont.c"
#endif

#define TAPPING_TERM 250
#define SPLIT_HAND_PIN B7

