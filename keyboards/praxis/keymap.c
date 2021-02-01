/* Copyright 2020 Harrison Chan (Xelus)
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

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_all(
    KC_ESC,   KC_TILD,        KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS,  KC_ESC,
    KC_PGUP,  KC_TAB,         KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,
    KC_PGDN,  LCTL_T(KC_ESC), KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_ENT,
              KC_LSFT,        KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_B,       KC_N,    KC_M,    KC_COMM,    KC_DOT,  KC_SLSH,       KC_RSFT, MO(4),
              KC_LCTL,                    KC_LALT,                KC_SPC,  KC_LGUI,             LT(2, KC_ENT),                MO(3),                  MO(4)
  ),

  [1] = LAYOUT_all(
    KC_ESC,   KC_TILD,        KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS,  KC_ESC,
    KC_PGUP,  KC_TAB,         KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,
    KC_PGDN,  KC_LCTL,        KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_ENT,
              KC_LSFT,        KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_B,       KC_N,    KC_M,    KC_COMM,    KC_DOT,  KC_SLSH,       KC_RSFT, MO(4),
              KC_LCTL,                    KC_LALT,                KC_SPC,  KC_LGUI,             LT(2, KC_ENT),    MO(3),                              MO(4)
  ),

  [2] = LAYOUT_all(
    KC_ESC,   XXXXXXX,        KC_F1,      KC_F2,   KC_F3,         KC_F4,   KC_F5,   KC_F6,      KC_F7,   KC_F8,   KC_F9,      KC_F10,  KC_F11,        KC_F12,  XXXXXXX,  XXXXXXX,
    KC_PGUP,  KC_TAB,         XXXXXXX,    KC_UP,   XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    KC_PSCR, XXXXXXX,       XXXXXXX, KC_DEL,
    KC_PGDN,  KC_LCTL,        KC_LEFT,    KC_DOWN, KC_RIGHT,      XXXXXXX, XXXXXXX, KC_LEFT,    KC_DOWN, KC_UP,   KC_RGHT,    XXXXXXX, XXXXXXX,       XXXXXXX,
              KC_LSFT,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, KC_MPRV,    KC_MNXT, KC_MPLY,       XXXXXXX, XXXXXXX,
              KC_LCTL,                    KC_LALT,                KC_SPC,  KC_LGUI,             _______,          XXXXXXX,                            XXXXXXX
  ),

  [3] = LAYOUT_all(
    KC_ESC,   RALT(KC_N),     XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, RALT(KC_I), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, LGUI(KC_MINS), XXXXXXX, XXXXXXX,  XXXXXXX,
    KC_PGUP,  KC_TAB,         XXXXXXX,    XXXXXXX, RALT(KC_QUOT), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, RALT(KC_O), XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
    KC_PGDN,  KC_LCTL,        RALT(KC_A), XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, RALT(KC_E),    XXXXXXX,
              KC_LSFT,        XXXXXXX,    XXXXXXX, RALT(KC_C),    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
              KC_LCTL,                    KC_LALT,                KC_SPC,  KC_LGUI,             XXXXXXX,          XXXXXXX,                            XXXXXXX
  ),

  [4] = LAYOUT_all(
    RESET,    XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,  TG(1),
    XXXXXXX,  XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
    XXXXXXX,  XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,
              XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, _______,
              XXXXXXX,                    XXXXXXX,                XXXXXXX, XXXXXXX,             XXXXXXX,          XXXXXXX,                            _______
  ),
};
