# Changelog

## [1.6.0](https://github.com/TheQueenIsDead/calora/compare/calora-v1.5.0...calora-v1.6.0) (2026-06-20)


### Features

* 5-second undo for diary deletes ([6b7196e](https://github.com/TheQueenIsDead/calora/commit/6b7196ef1976bc3badc48d780fee559fcf52fc25))
* add 'Previous [Meal]' section to food search idle state ([59f4d93](https://github.com/TheQueenIsDead/calora/commit/59f4d933c12a0fd8e30e18d3cd748afc6116a420))
* add 2x2 calorie ring home screen widget ([62bf9ab](https://github.com/TheQueenIsDead/calora/commit/62bf9ab85bdba1f7ef2bc8ea014d7c138d7770c1))
* add 2x2 calorie ring home screen widget ([282a7c6](https://github.com/TheQueenIsDead/calora/commit/282a7c61b64f41372612846f8bbf6550d0bced85))
* add add/subtract mode toggle to water card for correcting misclicks ([ef23eff](https://github.com/TheQueenIsDead/calora/commit/ef23effa55636413b89088996041f7e7536359e1))
* add Android water home screen widget ([d1f5370](https://github.com/TheQueenIsDead/calora/commit/d1f5370306c3281400014cc9ae5614aef1579462))
* add data export/import and fix Gradle KGP warning ([ed48446](https://github.com/TheQueenIsDead/calora/commit/ed48446c746039b1ed0344b89ae404ad0a4b7d5c))
* add Material Symbols water_bottle icon to water card header ([a183841](https://github.com/TheQueenIsDead/calora/commit/a1838410196e326535a9b5fbd3406952c0ed769f))
* add per-day lock toggle; past days locked by default ([b29bd8f](https://github.com/TheQueenIsDead/calora/commit/b29bd8f518d476014a1991d35f6ce18c4e03f4d1))
* add servings to recipes; macro card shows per-serving values ([6056541](https://github.com/TheQueenIsDead/calora/commit/6056541123404e3f1206bd7ba5a129b7634e7fd6))
* allow save-as-recipe regardless of day lock state ([1d23880](https://github.com/TheQueenIsDead/calora/commit/1d238804bd42bf414a84dc0a971438a43818ce37))
* apple logo, vivid green palette ([#42](https://github.com/TheQueenIsDead/calora/issues/42)C750 seed) ([2b29f77](https://github.com/TheQueenIsDead/calora/commit/2b29f775b7e63ead1ececfb6af73e2ed61eaca6e))
* bump seed DB to v4 with 77,952 foods including full OFF APAC dataset ([df4e022](https://github.com/TheQueenIsDead/calora/commit/df4e022c0112ed408f22bef7ae4f47991f5650de))
* custom water vessels, TDEE deficit display, and trend goal line ([9db1ba4](https://github.com/TheQueenIsDead/calora/commit/9db1ba4d3773ddf21c5932fedac96c4021b5870c))
* **data:** include zero-calorie products (water, tea, diet drinks) ([e85720d](https://github.com/TheQueenIsDead/calora/commit/e85720d065382526f6c1a6437af05200ff9aabe2))
* **data:** maintain seed DB incrementally with migrations ([bc4b9da](https://github.com/TheQueenIsDead/calora/commit/bc4b9daa2fe32521ef8b514d172f42feceb4c1ca))
* **data:** show before/after record counts in build script ([6e50ffb](https://github.com/TheQueenIsDead/calora/commit/6e50ffbf5bec12db52d3fc226219fdc6b8adc55f))
* **data:** use parquet as nutrition fallback before API in OFF import ([38b7f2c](https://github.com/TheQueenIsDead/calora/commit/38b7f2ce0f8a25203e63d857fa230584da804e59))
* db error handling, atomic recipes, weight log schema, recent foods query ([4c22c31](https://github.com/TheQueenIsDead/calora/commit/4c22c318022ec19e673d7469890fd1628c5c03b8))
* edit entries in-place, last-used grams memory, WeekStrip reactivity, TDEE trend line ([0d2cd9c](https://github.com/TheQueenIsDead/calora/commit/0d2cd9ceb8770a3de55eeb58f7f187c39408effd))
* expand seed DB to 19,305 foods, bump to version 3 ([7b8f972](https://github.com/TheQueenIsDead/calora/commit/7b8f9722ea3d6be2c0a34a85ab9febea8c35bc83))
* expand water vessel icon picker with tumbler and bottle options ([6f8dc7d](https://github.com/TheQueenIsDead/calora/commit/6f8dc7dbac97aafe182d4b96f82a630dda07dfbd))
* gauge logo with vivid green gradient, regenerate all app icons ([64475f1](https://github.com/TheQueenIsDead/calora/commit/64475f1077d3f70bb71b68dd8cf6c06e28b7954a))
* health connect ([7c150ea](https://github.com/TheQueenIsDead/calora/commit/7c150eab76d9d3cbe7c266a90bc4b92a7e3b8c8c))
* **health-connect:** refine expenditure model, drop local weight, redesign trends ([66e84df](https://github.com/TheQueenIsDead/calora/commit/66e84df4fdffb4a48e22a7fc8b9d082051963614))
* **health:** attribute active calories to workouts directly ([610d6f0](https://github.com/TheQueenIsDead/calora/commit/610d6f04d100749909732caefc67098b9a35b328))
* **home:** redesign calorie summary card for scanability ([ee60301](https://github.com/TheQueenIsDead/calora/commit/ee603016da8f9d94e10713781966a656cb3a2c67))
* initial Calora application ([6a66f74](https://github.com/TheQueenIsDead/calora/commit/6a66f74ba24379219d01cbc7a4c2e0d5b034b8f7))
* inline recipes list into settings screen, rename section to Recipes ([bd1801e](https://github.com/TheQueenIsDead/calora/commit/bd1801eee335116e1a8c8f66f2f789657ffa0e50))
* integrate Health Connect for active calories, weight, and height ([d47d89f](https://github.com/TheQueenIsDead/calora/commit/d47d89f93fa6d9880e20062b6afca95aef5992f7))
* migrate daily water tracking from SharedPreferences to SQLite ([cd6c61b](https://github.com/TheQueenIsDead/calora/commit/cd6c61b4a36fa74a8d941fd109015a0016842c43))
* replace water card icon with doughnut progress ring ([1329d73](https://github.com/TheQueenIsDead/calora/commit/1329d731842ed2e5fa42ea137ff1ee16b928b7c7))
* show recent foods inline in search bar ([7e8402d](https://github.com/TheQueenIsDead/calora/commit/7e8402d241ae8531ac471cb052910cf66515ee7d))
* three-state calorie warning — amber over goal, red over TDEE ([13c277c](https://github.com/TheQueenIsDead/calora/commit/13c277cc225bc56fbf5bc415fcdbf16dd13c66ae))
* unify ingredient search, fix cross-field search, add Taskfile ([1731df3](https://github.com/TheQueenIsDead/calora/commit/1731df3fb853531b20b95e4d25c2160f42816fe7))
* water_bottle SVG as selectable vessel icon; tidy icon list; dedup search ([eea2874](https://github.com/TheQueenIsDead/calora/commit/eea28740673d0ed62b683d3299abc3b372ec1b13))
* weight tracking screen and trends chart ([d4ed673](https://github.com/TheQueenIsDead/calora/commit/d4ed67312532edd3ab03236a2bbbca02cb0701bc))
* **widget:** allow 1-cell height and 3-cell minimum width ([8dab0e6](https://github.com/TheQueenIsDead/calora/commit/8dab0e61cc793d64839078a340f31386040bcc9a))
* **widget:** show live layout preview in widget picker ([7e8bebf](https://github.com/TheQueenIsDead/calora/commit/7e8bebf4f8ea1f749efed8ea86e0579f8a341450))


### Bug Fixes

* add onOpen idempotent guard for servings column; add servings button to recipe app bar ([6ea248c](https://github.com/TheQueenIsDead/calora/commit/6ea248c0fb28381aa7904466163994f164e6bf69))
* align left Y-axis labels with grid lines ([1728bf2](https://github.com/TheQueenIsDead/calora/commit/1728bf27fb286710836e7984de436b55e04efa5c))
* BMR _loadPrefs stripped zeros from saved values (height 170 loaded as "17") ([9db1ba4](https://github.com/TheQueenIsDead/calora/commit/9db1ba4d3773ddf21c5932fedac96c4021b5870c))
* cancel pending delete timers on DiaryProvider dispose ([5f8d911](https://github.com/TheQueenIsDead/calora/commit/5f8d911eb5e85c0a6614bb2c6cae9c2838bf9f15))
* capitalise Android app launcher label to Calora ([a290aa0](https://github.com/TheQueenIsDead/calora/commit/a290aa0810a95aae3017abc90ebe0dcd46dc3195))
* dart analyze clean — unused variable, unnecessary underscores, RadioListTile ([9db1ba4](https://github.com/TheQueenIsDead/calora/commit/9db1ba4d3773ddf21c5932fedac96c4021b5870c))
* **data:** commit every 500 rows with progress logging during OFF enrichment ([c673899](https://github.com/TheQueenIsDead/calora/commit/c673899a3a4afa96a3321ab90ef7033b38ae417d))
* **data:** convert energy-kj to kcal in parquet query, remove API fallback ([4cd4bea](https://github.com/TheQueenIsDead/calora/commit/4cd4beacc63578a9a74fe1b21c8e40a496caa1d5))
* **data:** exclude products tagged nutriscore-missing-nutrition-data-energy ([fe7dc58](https://github.com/TheQueenIsDead/calora/commit/fe7dc58c0b1f19f25df4f11b99de82b949109a25))
* **data:** extract usda files flat into usda/ not usda/foundation/ ([bc0c308](https://github.com/TheQueenIsDead/calora/commit/bc0c3086c9d3eea00487304ca88dfeeb0e4ce731))
* **data:** fail loudly if APAC CSV missing, add before/after diff to build ([e050864](https://github.com/TheQueenIsDead/calora/commit/e0508647f615c288614cbb53b2ebaad3b33b502a))
* **data:** hardcode generates paths and fix usda url and build errors ([85ef08f](https://github.com/TheQueenIsDead/calora/commit/85ef08f9623393a3703a3ace6840390590c3f472))
* **data:** replace generates with status for reliable skip detection ([9304d6e](https://github.com/TheQueenIsDead/calora/commit/9304d6e0b9dccaa7b9ef861f22a74971691c6a6d))
* **diary:** drop in-flight HC reads if the toggle was disabled mid-refresh ([2006318](https://github.com/TheQueenIsDead/calora/commit/2006318dc7f2c22e244e1a549cd93252cb5a0d03))
* floor calorie chart Y-axis to nearest 500 below min datapoint ([3a310f1](https://github.com/TheQueenIsDead/calora/commit/3a310f1e3ca8b92c31cdde6812b36dfd9dfc95a6))
* **health:** assign midnight-crossing workouts to a single day ([256b78d](https://github.com/TheQueenIsDead/calora/commit/256b78da622143298ce8899c53087aa478151a5a))
* **home:** include HC activity in expenditure even when BMR is unset ([ede1238](https://github.com/TheQueenIsDead/calora/commit/ede1238534e9d3cc291019d6841a4981b6832b6f))
* initialize Flutter binding before providers access SharedPreferences ([8f0a483](https://github.com/TheQueenIsDead/calora/commit/8f0a483729f4eb23bbfcc9a13ccfd37e0684bc9b))
* Previous [Meal] strip shows last logged instance of same meal type ([fc812e4](https://github.com/TheQueenIsDead/calora/commit/fc812e486b6dcb53f2c31dfc6f2510435c1ac1d2))
* **release-please:** use dart release type, not flutter ([745d63d](https://github.com/TheQueenIsDead/calora/commit/745d63dbeea9fae4139b823d453d43492ad523c8))
* reload trends chart when diary entries change ([dad8822](https://github.com/TheQueenIsDead/calora/commit/dad8822428f961f17419d460472031315a7aade6))
* replace water mode button with sliding -/+ pill toggle ([684bfeb](https://github.com/TheQueenIsDead/calora/commit/684bfebcdc78490ecc809a08d69d2e726f27e600))
* reset widget water count when day rolls over ([f4b8c72](https://github.com/TheQueenIsDead/calora/commit/f4b8c7287f79ebc83a159fd524ad30771f97ab4c))
* resolve three architectural issues ([b391eca](https://github.com/TheQueenIsDead/calora/commit/b391eca7060da8029f2662e58c53ec2ac574f8d9))
* resolve use_build_context_synchronously and underscore lint warnings ([16c7a47](https://github.com/TheQueenIsDead/calora/commit/16c7a47469c9bcec4279e3842c5fd494c3671f77))
* run servings schema guard after openDatabase returns; add recipe delete ([4577e52](https://github.com/TheQueenIsDead/calora/commit/4577e52f6de2815cc8f18e2ca5654072bffc7387))
* sign release APK with consistent keystore via GitHub secret ([b282090](https://github.com/TheQueenIsDead/calora/commit/b28209084da94d38f728492a58684e2f44ed6498))
* snackbar auto-dismiss and duplicate previous-meal suggestions ([a10fca7](https://github.com/TheQueenIsDead/calora/commit/a10fca7e75bf84b4731e8973e0dd04fcd8577ca6))
* snap calorie chart Y-axis to 500-unit grid ([d580a21](https://github.com/TheQueenIsDead/calora/commit/d580a21e87e78233f97218e65bf7a146a7050fd4))
* sort FTS results by relevance rank, not source priority ([4d7566c](https://github.com/TheQueenIsDead/calora/commit/4d7566c4b8a0454a0390930fe688c2a78fc6f2ef))
* switch to googleapis release-please action with dart type; fix analyzer warnings ([3701144](https://github.com/TheQueenIsDead/calora/commit/3701144c3ae7ded570dcb9faa60d19e280b179c4))
* TDEE line on calorie chart now appears correctly ([5337103](https://github.com/TheQueenIsDead/calora/commit/53371039d8d201abea75de394e32f1a92fad1691))
* **trends:** keep streak alive on mornings before first meal ([c731ab7](https://github.com/TheQueenIsDead/calora/commit/c731ab74903cbeda4243edb760d1105eba000caa))
* **weight:** reload from HC when the toggle flips ([1e53ad5](https://github.com/TheQueenIsDead/calora/commit/1e53ad5ffea373f6941a3d5a300be761f23e0605))
* **widget:** align calorie ring preview, enable resize, allow 1x1 minimum ([9af103f](https://github.com/TheQueenIsDead/calora/commit/9af103f804ad19fb9244ef13fa07f2131888d249))


### Performance Improvements

* **diary:** parallelize the three HC reads in refreshActiveCalories ([df59e75](https://github.com/TheQueenIsDead/calora/commit/df59e754bd984963d7d69e2276bf76f3bb4225d0))
* **health:** bound BMR record scan to last 30 days ([29f1bde](https://github.com/TheQueenIsDead/calora/commit/29f1bdea5da4d574d0b343d9786d41f642feddc7))
* **main:** skip the 5-min HC refresh when viewing a past day ([5b2ed45](https://github.com/TheQueenIsDead/calora/commit/5b2ed45d337d4f733ff7824bf9161a7b25247d50))

## [1.5.0](https://github.com/TheQueenIsDead/calora/compare/v1.4.0...v1.5.0) (2026-06-12)


### Features

* add 2x2 calorie ring home screen widget ([c4cbb41](https://github.com/TheQueenIsDead/calora/commit/c4cbb418aa095aa98150536dc429553b0b515b62))
* add 2x2 calorie ring home screen widget ([cbcda56](https://github.com/TheQueenIsDead/calora/commit/cbcda565aa27ec63b5ee6c2fcb3257cc75a695df))
* **widget:** show live layout preview in widget picker ([542515d](https://github.com/TheQueenIsDead/calora/commit/542515dae228b9ed3c3aa5b29475c5b160f42e62))


### Bug Fixes

* reset widget water count when day rolls over ([f4743cf](https://github.com/TheQueenIsDead/calora/commit/f4743cf2cc6c71b3d87e0f6b0a75f0247f3b29b3))
* **widget:** align calorie ring preview, enable resize, allow 1x1 minimum ([613d198](https://github.com/TheQueenIsDead/calora/commit/613d198bec597bb291891f5a199d95a5333ccfa8))

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
