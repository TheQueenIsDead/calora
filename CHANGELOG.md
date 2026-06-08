# Changelog

## 1.0.0 (2026-06-08)


### Features

* 5-second undo for diary deletes ([177374f](https://github.com/TheQueenIsDead/calora/commit/177374f33fcc511e208fe0291cd701afe6419745))
* add 'Previous [Meal]' section to food search idle state ([e71a920](https://github.com/TheQueenIsDead/calora/commit/e71a920664d4ecc31f4a3753189922bad3954990))
* add add/subtract mode toggle to water card for correcting misclicks ([6ea50bc](https://github.com/TheQueenIsDead/calora/commit/6ea50bc051e5b786511534831a5f8bb757c85835))
* add Material Symbols water_bottle icon to water card header ([9d9e38e](https://github.com/TheQueenIsDead/calora/commit/9d9e38ee07b64c5d5eeaae1e32b837a80710ae00))
* add per-day lock toggle; past days locked by default ([de02f6c](https://github.com/TheQueenIsDead/calora/commit/de02f6cb05e349c64f70740bf376c36f7ebf9671))
* add servings to recipes; macro card shows per-serving values ([6b0d279](https://github.com/TheQueenIsDead/calora/commit/6b0d279a7efa8bfacfc54aed4a381dd6bed38ec6))
* allow save-as-recipe regardless of day lock state ([95f11a0](https://github.com/TheQueenIsDead/calora/commit/95f11a08f9a4360bf61e023fe05ab285cfc96391))
* apple logo, vivid green palette ([#42](https://github.com/TheQueenIsDead/calora/issues/42)C750 seed) ([67128af](https://github.com/TheQueenIsDead/calora/commit/67128af4ae212e36cc61caeefb80b29afb1e1bd4))
* custom water vessels, TDEE deficit display, and trend goal line ([ab802d2](https://github.com/TheQueenIsDead/calora/commit/ab802d2a992af107ce8e8b9d816616932de949f1))
* db error handling, atomic recipes, weight log schema, recent foods query ([9e1821c](https://github.com/TheQueenIsDead/calora/commit/9e1821c4eb19855f71344129343e013a7b6aa1f4))
* edit entries in-place, last-used grams memory, WeekStrip reactivity, TDEE trend line ([8b78d0b](https://github.com/TheQueenIsDead/calora/commit/8b78d0b5efc7399eed7f37abc63cbb6da86be32a))
* expand water vessel icon picker with tumbler and bottle options ([5d24f3d](https://github.com/TheQueenIsDead/calora/commit/5d24f3dd39c9f5f3daea3eb9eb6b64401b37c02a))
* gauge logo with vivid green gradient, regenerate all app icons ([a0d1b6d](https://github.com/TheQueenIsDead/calora/commit/a0d1b6d9e1e0cd1270fc94bfa7737b8481b88def))
* initial Calora application ([41583e1](https://github.com/TheQueenIsDead/calora/commit/41583e1e520dc560166aec77d18b059f4b7e69c6))
* inline recipes list into settings screen, rename section to Recipes ([e153101](https://github.com/TheQueenIsDead/calora/commit/e153101bee93f7d376870967f52db86f41528f6c))
* replace water card icon with doughnut progress ring ([5477ab1](https://github.com/TheQueenIsDead/calora/commit/5477ab118170ad4cb6bfad881f451ef53962f16a))
* show recent foods inline in search bar ([a4e6a95](https://github.com/TheQueenIsDead/calora/commit/a4e6a9554da1a79a8389e0ae6fa11e9f26e61efe))
* three-state calorie warning — amber over goal, red over TDEE ([2705571](https://github.com/TheQueenIsDead/calora/commit/27055719d659228eebfb597b0adbf767986f7fba))
* water_bottle SVG as selectable vessel icon; tidy icon list; dedup search ([94c063c](https://github.com/TheQueenIsDead/calora/commit/94c063c5be705d7e0399bde8b807a7bf9ad594b5))
* weight tracking screen and trends chart ([da2197e](https://github.com/TheQueenIsDead/calora/commit/da2197ecee5668d928dbf9316679a6940d26509f))


### Bug Fixes

* add onOpen idempotent guard for servings column; add servings button to recipe app bar ([2a187f6](https://github.com/TheQueenIsDead/calora/commit/2a187f64d68cd5a254791aa9cc5f10e81b4d3c3a))
* BMR _loadPrefs stripped zeros from saved values (height 170 loaded as "17") ([ab802d2](https://github.com/TheQueenIsDead/calora/commit/ab802d2a992af107ce8e8b9d816616932de949f1))
* cancel pending delete timers on DiaryProvider dispose ([fad0d6d](https://github.com/TheQueenIsDead/calora/commit/fad0d6dbc79baf2b2f78bd9cb1eb26ec9c9cdde9))
* capitalise Android app launcher label to Calora ([6e151cf](https://github.com/TheQueenIsDead/calora/commit/6e151cf96c416fcbdc9aba0ea09f379a4aef9e79))
* dart analyze clean — unused variable, unnecessary underscores, RadioListTile ([ab802d2](https://github.com/TheQueenIsDead/calora/commit/ab802d2a992af107ce8e8b9d816616932de949f1))
* Previous [Meal] strip shows last logged instance of same meal type ([8f45f0f](https://github.com/TheQueenIsDead/calora/commit/8f45f0f21240930860b4d197d2a4f57c626db42c))
* replace water mode button with sliding -/+ pill toggle ([f3df6e1](https://github.com/TheQueenIsDead/calora/commit/f3df6e1286f559f459ff427f276edb9c7fcf62d3))
* resolve use_build_context_synchronously and underscore lint warnings ([4170fd2](https://github.com/TheQueenIsDead/calora/commit/4170fd28106a71f0d8aede791e93d4b147f3acfe))
* run servings schema guard after openDatabase returns; add recipe delete ([08b812f](https://github.com/TheQueenIsDead/calora/commit/08b812ff13190ad0f659704045e8fac4aea06e0f))
* snackbar auto-dismiss and duplicate previous-meal suggestions ([380430c](https://github.com/TheQueenIsDead/calora/commit/380430cdaeab5eaa8ab4e2d83cfe39d3d7eda6b7))
* switch to googleapis release-please action with dart type; fix analyzer warnings ([e4acc5b](https://github.com/TheQueenIsDead/calora/commit/e4acc5be476076ac6703a0830a280f7165516295))
* TDEE line on calorie chart now appears correctly ([ff2c72a](https://github.com/TheQueenIsDead/calora/commit/ff2c72ad501062726a10ca5718fe43b664c44197))
