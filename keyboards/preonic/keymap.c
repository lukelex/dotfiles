/* Copyright 2015-2017 Jack Humbert
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
#include "muse.h"

enum preonic_layers {
  _QWERTY,
  _LOWER,
  _RAISE,
  _GAME,
  _FIRMWARE
};

enum preonic_keycodes {
  QWERTY = SAFE_RANGE,
  LAW_SEC
};

/* /1* #define LAW_SEC UC(0x00A7) // § *1/ */
/* #define DK_AE UC(0x00A7) // Æ */
/* #define DK_O UC(0x00A7) // Ø */
/* #define DK_A UC(0x00A7) // Å */

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

  /* Qwerty
   * ,---------------------------------------------------------------------------------------.
   * |    `     |   1  |   2  |   3  |   4  |   5  |   6  |   7  |   8  |   9  |   0  |  \   |
   * |----------+------+------+------+------+------+------+------+------+------+------+------|
   * |   Tab    |   Q  |   W  |   E  |   R  |   T  |   Y  |   U  |   I  |   O  |   P  | Bksp |
   * |----------+------+------+------+------+------+------+------+------+------+------+------|
   * | Ctrl/Esc |   A  |   S  |   D  |   F  |   G  |   H  |   J  |   K  |   L  |   ;  |  "   |
   * |----------+------+------+------+------+------+------+------+------+------+------+------|
   * |   Shift  |   Z  |   X  |   C  |   V  |   B  |   N  |   M  |   ,  |   .  |   /  |Enter |
   * |----------+------+------+------+------+------+------+------+------+------+------+------|
   * |   Lower  | Ctrl |AltGR | GUI  |    Space    | Enter\Raise |Raise | Prev | Next | Game |
   * `---------------------------------------------------------------------------------------'
   */
  [_QWERTY] = LAYOUT_preonic_grid( \
      KC_GRV,               KC_1,    KC_2,    KC_3,    KC_4,    KC_5,   KC_6,    KC_7,               KC_8,       KC_9,          KC_0,    KC_BSLS,  \
      KC_TAB,               KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,   KC_Y,    KC_U,               KC_I,       KC_O,          KC_P,    KC_BSPC,  \
      MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,    KC_D,    KC_F,    KC_G,   KC_H,    KC_J,               KC_K,       KC_L,          KC_SCLN, KC_QUOT,  \
      KC_LSFT,              KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,   KC_N,    KC_M,               KC_COMM,    KC_DOT,        KC_SLSH, KC_RSFT,  \
      MO(_LOWER),           XXXXXXX, KC_ALGR, KC_LGUI, XXXXXXX, KC_SPC, XXXXXXX, LT(_RAISE, KC_ENT), MO(_RAISE), MO(_FIRMWARE), XXXXXXX, XXXXXXX \
  ),

  /* Lower
   * ,---------------------------------------------------------------------------------------.
   * |          |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+-------------+------+------+------+------+------|
   * |   Tab    |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+-------------+------+------+------+------+------|
   * | Ctrl/Esc |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+------|------+------+------+------+------+------|
   * |   Shift  |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+------+------+------+------+------+------+------|
   * |          |      |      |      |             |             |      |      |      |      |
   * `---------------------------------------------------------------------------------------'
   */
  [_LOWER] = LAYOUT_preonic_grid( \
      XXXXXXX, KC_F1,   KC_F2,   KC_F3,    KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,   KC_F10,  KC_F11,  \
      XXXXXXX, XXXXXXX, KC_UP,   XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_F12,  \
      XXXXXXX, KC_LEFT, KC_DOWN, KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, \
      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, \
      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX  \
  ),

  /* Raise
   * ,---------------------------------------------------------------------------------------.
   * |    `     |  F1  |  F2  |  F3  |  F4  |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+------+------+------+------+------+------+------|
   * |   Tab    | Prev | Play | Next |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+-------------+------+------+------+------+------|
   * | Ctrl/Esc |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+------|------+------+------+------+------+------|
   * |   Shift  |      |      |      |      |      |      |      |      |      |      |      |
   * |------+---+------+------+------+------+------+------+------+------+------+------+------|
   * |   Brite  |      |      |      |      |             |      |      |      |      |      |
   * `---------------------------------------------------------------------------------------'
   */
  [_RAISE] = LAYOUT_preonic_grid( \
      KC_GRV,     XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_LBRC, KC_RBRC, KC_MINUS, KC_EQL,  XXXXXXX, \
      KC_TAB,     XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_LBRC, KC_RBRC, KC_LCBR, KC_RCBR,  XXXXXXX, XXXXXXX, \
      KC_LCTL,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, \
      KC_LSFT,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_PGDN, KC_PGUP, KC_NUBS, KC_MPRV,  KC_MNXT, KC_MPLY, \
      MO(_LOWER), XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX  \
  ),

  /* Game
   * ,----------------------------------------------------------------------------------------.
   * |    `     |   1  |   2  |   3  |   4  |   5  |   6  |   7  |   8  |   9  |   0  |  \    |
   * |----------+------+------+------+------+------+------+------+------+------+------+-------|
   * |   Tab    |   Q  |   W  |   E  |   R  |   T  |   Y  |   U  |   I  |   O  |   P  | Bksp  |
   * |----------+------+------+------+------+------+------+------+------+------+------+-------|
   * | Ctrl/Esc |   A  |   S  |   D  |   F  |   G  |   H  |   J  |   K  |   L  |   ;  |  "    |
   * |----------+------+------+------+------+------+------+------+------+------+------+-------|
   * |   Shift  |   Z  |   X  |   C  |   V  |   B  |   N  |   M  |   ,  |   .  |   /  |Enter  |
   * |----------+------+------+------+------+------+------+------+------+------+------+-------|
   * |   Lower  | Ctrl |AltGR | GUI  |    Space    | Enter\Raise |Raise | Prev | Next |Qwerty |
   * `----------------------------------------------------------------------------------------'
   */
  [_GAME] = LAYOUT_preonic_grid( \
      KC_GRV,     KC_1,    KC_2,    KC_3,    KC_4,    KC_5,   KC_6,    KC_7,               KC_8,       KC_9,          KC_0,    KC_BSLS, \
      KC_TAB,     KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,   KC_Y,    KC_U,               KC_I,       KC_O,          KC_P,    KC_BSPC, \
      KC_LCTL,    KC_A,    KC_S,    KC_D,    KC_F,    KC_G,   KC_H,    KC_J,               KC_K,       KC_L,          KC_SCLN, KC_QUOT, \
      KC_LSFT,    KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,   KC_N,    KC_M,               KC_COMM,    KC_DOT,        KC_SLSH, KC_RSFT,  \
      MO(_LOWER), XXXXXXX, KC_ALGR, KC_LGUI, XXXXXXX, KC_SPC, XXXXXXX, LT(_RAISE, KC_ENT), MO(_RAISE), MO(_FIRMWARE), XXXXXXX, XXXXXXX \
  ),

  /* Firmware
   * ,-----------------------------------------------------------------------------------.
   * |      |      |      |      |      |      |      |      |      |      |      |      |
   * |------+------+------+------+------+------+------+------+------+------+------+------|
   * |      | Reset|      |      |      |      |      |      |      |      |      |      |
   * |------+------+------+------+------+-------------+------+------+------+------+------|
   * |      |      |      |Aud on|AudOff|AGnorm|AGswap|Qwerty|      |      |      |      |
   * |------+------+------+------+------+------|------+------+------+------+------+------|
   * |      |Voice-|Voice+|Mus on|MusOff|MidiOn|MidOff|      |      |      |      |      |
   * |------+------+------+------+------+------+------+------+------+------+------+------|
   * |      |      |      |      |      |             |      |      |      |      |      |
   * `-----------------------------------------------------------------------------------'
   */
  [_FIRMWARE] = LAYOUT_preonic_grid( \
      RESET,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, TG(_GAME),  \
      XXXXXXX, DEBUG,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, TERM_ON, TERM_OFF, XXXXXXX, XXXXXXX, KC_DEL,  \
      XXXXXXX, XXXXXXX, MU_MOD,  AU_ON,   AU_OFF,  AG_NORM, AG_SWAP, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, \
      XXXXXXX, MUV_DE,  MUV_IN,  MU_ON,   MU_OFF,  MI_ON,   MI_OFF,  XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, \
      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX  \
  )
};
