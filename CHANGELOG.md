# Changelog

## [1.4.0](https://github.com/TheQueenIsDead/calora/compare/v1.3.0...v1.4.0) (2026-06-12)


### Features

* add Android water home screen widget ([67266a6](https://github.com/TheQueenIsDead/calora/commit/67266a67e29cad7bfce792a9f672848b7dbc0097))
* migrate daily water tracking from SharedPreferences to SQLite ([9333d7e](https://github.com/TheQueenIsDead/calora/commit/9333d7e5c08821711f45b1e185b4570607fed804))
* **widget:** allow 1-cell height and 3-cell minimum width ([18e2cea](https://github.com/TheQueenIsDead/calora/commit/18e2cea95b3da39758fe161446288f6d487d2f61))


### Bug Fixes

* align left Y-axis labels with grid lines ([11a9a87](https://github.com/TheQueenIsDead/calora/commit/11a9a876464161d6b489e68a138f1c2f7b50feb0))
* floor calorie chart Y-axis to nearest 500 below min datapoint ([a068135](https://github.com/TheQueenIsDead/calora/commit/a068135b450fbda2ef4612932f9ac69b14d36a65))
* snap calorie chart Y-axis to 500-unit grid ([7f5ebda](https://github.com/TheQueenIsDead/calora/commit/7f5ebdaf6f22b07cd93e047d17ae642d82f2898f))

## [1.3.0](https://github.com/TheQueenIsDead/calora/compare/v1.2.0...v1.3.0) (2026-06-10)


### Features

* bump seed DB to v4 with 77,952 foods including full OFF APAC dataset ([7b62f44](https://github.com/TheQueenIsDead/calora/commit/7b62f440b06e0974379d969bd52c825125c24c43))
* **data:** include zero-calorie products (water, tea, diet drinks) ([0110412](https://github.com/TheQueenIsDead/calora/commit/01104126425e06e92009ba0a8b1988736f420e90))
* **data:** maintain seed DB incrementally with migrations ([86bc1e3](https://github.com/TheQueenIsDead/calora/commit/86bc1e33505f9a6e2e610d309f769f69a1183da2))
* **data:** show before/after record counts in build script ([c746805](https://github.com/TheQueenIsDead/calora/commit/c74680540f56827da0dc0e8a1c24fdd6db3d1814))
* **data:** use parquet as nutrition fallback before API in OFF import ([6ea4013](https://github.com/TheQueenIsDead/calora/commit/6ea401316b8fb90c6d644a7be0ba5fc3314da08f))
* expand seed DB to 19,305 foods, bump to version 3 ([6d2f4b9](https://github.com/TheQueenIsDead/calora/commit/6d2f4b9ff9499a1599412b27c994f3c64818a261))


### Bug Fixes

* **data:** commit every 500 rows with progress logging during OFF enrichment ([b4181c3](https://github.com/TheQueenIsDead/calora/commit/b4181c3b3c3875b9089142e4a21e8d87ebe5cc9c))
* **data:** convert energy-kj to kcal in parquet query, remove API fallback ([92abd27](https://github.com/TheQueenIsDead/calora/commit/92abd2792ba1aadf6bb6b7a82bfc16e036a9f464))
* **data:** exclude products tagged nutriscore-missing-nutrition-data-energy ([a1974fc](https://github.com/TheQueenIsDead/calora/commit/a1974fc81edd84458709790899c9591fbc1d33c8))
* **data:** extract usda files flat into usda/ not usda/foundation/ ([e275a0c](https://github.com/TheQueenIsDead/calora/commit/e275a0c9da32ea721b5bcc8f3462050b5f39152c))
* **data:** fail loudly if APAC CSV missing, add before/after diff to build ([1feed0a](https://github.com/TheQueenIsDead/calora/commit/1feed0ad87dddf76225bd0c4deaeb8e0a13d9f0f))
* **data:** hardcode generates paths and fix usda url and build errors ([3e90850](https://github.com/TheQueenIsDead/calora/commit/3e90850b38081077f10ee0fefa84eb4f4ca8678c))
* **data:** replace generates with status for reliable skip detection ([541a087](https://github.com/TheQueenIsDead/calora/commit/541a087d9490a818f54f91be33a8ab16faccbf76))
* initialize Flutter binding before providers access SharedPreferences ([c65b92c](https://github.com/TheQueenIsDead/calora/commit/c65b92c469e15917dbb19ecd797f71277d6a86db))
* reload trends chart when diary entries change ([37998e7](https://github.com/TheQueenIsDead/calora/commit/37998e7db45f933509edc068e804192466967cc8))
* resolve three architectural issues ([a3a13cc](https://github.com/TheQueenIsDead/calora/commit/a3a13cc2531668c83b0ac52d69f32830bcfacecf))
* sort FTS results by relevance rank, not source priority ([5c58202](https://github.com/TheQueenIsDead/calora/commit/5c582024cfe20de717d7dec0613e2c36cb7fa325))

## [1.2.0](https://github.com/TheQueenIsDead/calora/compare/v1.1.0...v1.2.0) (2026-06-09)


### Features

* add data export/import and fix Gradle KGP warning ([b3cf615](https://github.com/TheQueenIsDead/calora/commit/b3cf61565615310a208b18e73e7bae890b1c7449))


### Bug Fixes

* sign release APK with consistent keystore via GitHub secret ([fb0393e](https://github.com/TheQueenIsDead/calora/commit/fb0393e81aeb73b15cd13c18022d9f88267137b5))

## [1.1.0](https://github.com/TheQueenIsDead/calora/compare/v1.0.0...v1.1.0) (2026-06-09)


### Features

* unify ingredient search, fix cross-field search, add Taskfile ([ba77a8a](https://github.com/TheQueenIsDead/calora/commit/ba77a8aed97a8a85def0a2704d49b5afcaa799a3))

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
