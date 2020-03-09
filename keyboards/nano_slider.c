/* Copyright 2020 Duckle
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include QMK_KEYBOARD_H
#include "analog.h"
#include "qmk_midi.h"

// Defines names for use in layer keycodes and the keymap
enum layer_names {
  _BASE,
  _FIRMWARE
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  /* Base */
  [_BASE] = LAYOUT(
      LT(_FIRMWARE, KC_ESC),
      KC_SLCK, KC_0,      KC_MPRV,
      KC_PAUS, KC_4,     KC_MNXT, KC_MPLY
      ),
  [_FIRMWARE] = LAYOUT(
      _______,
      RGB_TOG, RGB_MOD, RGB_VAI,
      XXXXXXX, XXXXXXX, XXXXXXX, RESET
      )
};

uint8_t divisor = 0;

void slider(void) {
  if (divisor++) { // only run the slider function 1/256 times it's called
    return;
  }

  midi_send_cc(&midi_device, 2, 0x3E, 0x7F - (analogReadPin(SLIDER_PIN) >> 3));
}

void matrix_scan_user(void) {
  slider();
}
